const fs = require('fs').promises;
const path = require('path');
const { logger } = require('./logger');
const { config } = require('./config');

class StorageManager {
  constructor() {
    this.versionsFile = config.storage.versionsFile;
    this.dataDir = path.dirname(this.versionsFile);
  }

  /**
   * Initialize storage directory and files
   */
  async initialize() {
    try {
      // Ensure data directory exists
      await fs.mkdir(this.dataDir, { recursive: true });
      
      // Initialize versions file if it doesn't exist
      const exists = await this.fileExists(this.versionsFile);
      if (!exists) {
        await this.saveVersions({
          stable: {},
          next: {},
          lastCheck: null,
          metadata: {
            created: new Date().toISOString(),
            version: '1.0.0'
          }
        });
        logger.info('Initialized versions storage file', { file: this.versionsFile });
      }
    } catch (error) {
      logger.error('Failed to initialize storage', { error: error.message });
      throw error;
    }
  }

  /**
   * Check if file exists
   */
  async fileExists(filePath) {
    try {
      await fs.access(filePath);
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Load stored versions data
   */
  async loadVersions() {
    try {
      const data = await fs.readFile(this.versionsFile, 'utf8');
      const parsed = JSON.parse(data);
      
      // Validate structure
      if (!parsed.stable || !parsed.next) {
        throw new Error('Invalid versions file structure');
      }
      
      return parsed;
    } catch (error) {
      logger.error('Failed to load versions', { error: error.message });
      
      // Return default structure on error
      return {
        stable: {},
        next: {},
        lastCheck: null,
        metadata: {
          created: new Date().toISOString(),
          version: '1.0.0'
        }
      };
    }
  }

  /**
   * Save versions data
   */
  async saveVersions(data) {
    try {
      // Add metadata
      data.lastUpdated = new Date().toISOString();
      data.lastCheck = new Date().toISOString();
      
      const jsonData = JSON.stringify(data, null, 2);
      await fs.writeFile(this.versionsFile, jsonData, 'utf8');
      
      logger.debug('Versions data saved', { 
        file: this.versionsFile,
        stableCount: Object.keys(data.stable).length,
        nextCount: Object.keys(data.next).length
      });
    } catch (error) {
      logger.error('Failed to save versions', { error: error.message });
      throw error;
    }
  }

  /**
   * Get latest known version for a release type
   */
  async getLatestVersion(type) {
    try {
      const data = await this.loadVersions();
      const versions = data[type] || {};
      
      if (Object.keys(versions).length === 0) {
        return null;
      }
      
      // Get the most recent version by timestamp
      const sortedVersions = Object.entries(versions)
        .sort(([,a], [,b]) => new Date(b.detectedAt) - new Date(a.detectedAt));
      
      return sortedVersions[0] ? {
        version: sortedVersions[0][0],
        ...sortedVersions[0][1]
      } : null;
    } catch (error) {
      logger.error('Failed to get latest version', { type, error: error.message });
      return null;
    }
  }

  /**
   * Check if version is new
   */
  async isNewVersion(type, version) {
    try {
      const data = await this.loadVersions();
      const versions = data[type] || {};
      return !versions.hasOwnProperty(version);
    } catch (error) {
      logger.error('Failed to check if version is new', { type, version, error: error.message });
      return true; // Assume new on error to avoid missing releases
    }
  }

  /**
   * Add new version
   */
  async addVersion(type, version, releaseData) {
    try {
      const data = await this.loadVersions();
      
      if (!data[type]) {
        data[type] = {};
      }
      
      data[type][version] = {
        ...releaseData,
        detectedAt: new Date().toISOString(),
        notified: false
      };
      
      await this.saveVersions(data);
      
      logger.info('New version added to storage', { type, version });
      return true;
    } catch (error) {
      logger.error('Failed to add version', { type, version, error: error.message });
      throw error;
    }
  }

  /**
   * Mark version as notified
   */
  async markAsNotified(type, version) {
    try {
      const data = await this.loadVersions();
      
      if (data[type] && data[type][version]) {
        data[type][version].notified = true;
        data[type][version].notifiedAt = new Date().toISOString();
        await this.saveVersions(data);
        
        logger.debug('Version marked as notified', { type, version });
        return true;
      }
      
      return false;
    } catch (error) {
      logger.error('Failed to mark version as notified', { type, version, error: error.message });
      return false;
    }
  }

  /**
   * Get all unnotified versions
   */
  async getUnnotifiedVersions() {
    try {
      const data = await this.loadVersions();
      const unnotified = {
        stable: [],
        next: []
      };
      
      for (const [type, versions] of Object.entries(data)) {
        if (type === 'stable' || type === 'next') {
          for (const [version, versionData] of Object.entries(versions)) {
            if (!versionData.notified) {
              unnotified[type].push({
                version,
                ...versionData
              });
            }
          }
        }
      }
      
      // Sort by detection time (oldest first)
      unnotified.stable.sort((a, b) => new Date(a.detectedAt) - new Date(b.detectedAt));
      unnotified.next.sort((a, b) => new Date(a.detectedAt) - new Date(b.detectedAt));
      
      return unnotified;
    } catch (error) {
      logger.error('Failed to get unnotified versions', { error: error.message });
      return { stable: [], next: [] };
    }
  }

  /**
   * Clean up old versions (keep last 50 of each type)
   */
  async cleanup() {
    try {
      const data = await this.loadVersions();
      let cleaned = false;
      
      for (const type of ['stable', 'next']) {
        if (data[type]) {
          const versions = Object.entries(data[type])
            .sort(([,a], [,b]) => new Date(b.detectedAt) - new Date(a.detectedAt));
          
          if (versions.length > 50) {
            const toKeep = versions.slice(0, 50);
            data[type] = Object.fromEntries(toKeep);
            cleaned = true;
            
            logger.info('Cleaned up old versions', { 
              type, 
              removed: versions.length - 50,
              kept: 50
            });
          }
        }
      }
      
      if (cleaned) {
        await this.saveVersions(data);
      }
      
      return cleaned;
    } catch (error) {
      logger.error('Failed to cleanup versions', { error: error.message });
      return false;
    }
  }

  /**
   * Get storage statistics
   */
  async getStats() {
    try {
      const data = await this.loadVersions();
      
      return {
        stable: {
          total: Object.keys(data.stable || {}).length,
          unnotified: Object.values(data.stable || {}).filter(v => !v.notified).length
        },
        next: {
          total: Object.keys(data.next || {}).length,
          unnotified: Object.values(data.next || {}).filter(v => !v.notified).length
        },
        lastCheck: data.lastCheck,
        lastUpdated: data.lastUpdated
      };
    } catch (error) {
      logger.error('Failed to get storage stats', { error: error.message });
      return null;
    }
  }
}

module.exports = new StorageManager();
