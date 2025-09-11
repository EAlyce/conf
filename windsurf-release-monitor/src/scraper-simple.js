const https = require('https');
const logger = require('./logger');

/**
 * 简化的Windsurf版本抓取器 - 直接检测已知的下载链接
 */
class SimpleScraper {
  constructor() {
    // 已知的版本模式
    this.knownVersions = {
      stable: [
        { version: '1.12.5', hash: '64804081c3f9a1652d6d325c28c01c3f5882f6fb' },
        { version: '1.12.4', hash: 'f1e16e1e6214d7c44d078b1f0607b2388f29d729' },
        { version: '1.12.3', hash: '89c3fc3d3887c996e3f06eb2dd3c4850b2c9897c' },
        { version: '1.12.2', hash: 'e170252f0983275de9bd2b16b7c046e9e9b7fa0d' },
        { version: '1.12.1', hash: 'f1e16e1e6214d7c44d078b1f0607b2388f29d729' }
      ],
      next: [
        { version: '1.12.110', hash: '64804081c3f9a1652d6d325c28c01c3f5882f6fb' }
      ]
    };
  }

  /**
   * 构建下载URL
   */
  buildDownloadUrl(type, version, hash, platform = 'win32-x64-user') {
    const baseUrl = 'https://windsurf-stable.codeiumdata.com';
    if (type === 'stable') {
      return `${baseUrl}/${platform}/stable/${hash}/WindsurfUserSetup-x64-${version}.exe`;
    } else {
      return `${baseUrl}/${platform}/next/${hash}/WindsurfUserSetup-x64-${version}+next.${hash.substring(0, 10)}.exe`;
    }
  }

  /**
   * 检查URL是否可访问
   */
  async checkUrl(url) {
    return new Promise((resolve) => {
      https.get(url, { method: 'HEAD', timeout: 5000 }, (res) => {
        resolve(res.statusCode === 200 || res.statusCode === 302);
      }).on('error', () => {
        resolve(false);
      });
    });
  }

  /**
   * 获取所有可用的版本
   */
  async getAllReleases() {
    const results = {
      stable: [],
      next: [],
      errors: []
    };

    try {
      // 检查稳定版本
      logger.info('Checking stable versions...');
      for (const versionInfo of this.knownVersions.stable) {
        const url = this.buildDownloadUrl('stable', versionInfo.version, versionInfo.hash);
        const isAvailable = await this.checkUrl(url);
        
        if (isAvailable) {
          const release = {
            version: versionInfo.version,
            type: 'stable',
            date: new Date().toISOString(),
            downloads: {
              windows: {
                x64: url,
                arm64: this.buildDownloadUrl('stable', versionInfo.version, versionInfo.hash, 'win32-arm64-user')
              },
              mac: {
                universal: this.buildDownloadUrl('stable', versionInfo.version, versionInfo.hash, 'darwin-universal'),
                intel: this.buildDownloadUrl('stable', versionInfo.version, versionInfo.hash, 'darwin-x64'),
                arm: this.buildDownloadUrl('stable', versionInfo.version, versionInfo.hash, 'darwin-arm64')
              },
              linux: {
                x64: this.buildDownloadUrl('stable', versionInfo.version, versionInfo.hash, 'linux-x64').replace('.exe', '.tar.gz'),
                deb: this.buildDownloadUrl('stable', versionInfo.version, versionInfo.hash, 'linux-x64').replace('.exe', '.deb')
              }
            },
            changelog: `https://windsurf.com/changelog/${versionInfo.version}`
          };
          results.stable.push(release);
          logger.info(`Found stable version: ${versionInfo.version}`);
          break; // 只需要最新的版本
        }
      }

      // 检查Next版本
      logger.info('Checking next versions...');
      for (const versionInfo of this.knownVersions.next) {
        const url = this.buildDownloadUrl('next', versionInfo.version, versionInfo.hash);
        const isAvailable = await this.checkUrl(url);
        
        if (isAvailable) {
          const release = {
            version: `${versionInfo.version}+next`,
            type: 'next',
            date: new Date().toISOString(),
            downloads: {
              windows: {
                x64: url,
                arm64: this.buildDownloadUrl('next', versionInfo.version, versionInfo.hash, 'win32-arm64-user')
              },
              mac: {
                universal: this.buildDownloadUrl('next', versionInfo.version, versionInfo.hash, 'darwin-universal'),
                intel: this.buildDownloadUrl('next', versionInfo.version, versionInfo.hash, 'darwin-x64'),
                arm: this.buildDownloadUrl('next', versionInfo.version, versionInfo.hash, 'darwin-arm64')
              },
              linux: {
                x64: this.buildDownloadUrl('next', versionInfo.version, versionInfo.hash, 'linux-x64').replace('.exe', '.tar.gz'),
                deb: this.buildDownloadUrl('next', versionInfo.version, versionInfo.hash, 'linux-x64').replace('.deb', '.deb')
              }
            },
            changelog: 'https://windsurf.com/changelog/windsurf-next'
          };
          results.next.push(release);
          logger.info(`Found next version: ${versionInfo.version}`);
          break; // 只需要最新的版本
        }
      }

    } catch (error) {
      logger.error('Error checking versions:', error);
      results.errors.push(error.message);
    }

    return results;
  }

  /**
   * 获取稳定版本
   */
  async scrapeStableReleases() {
    const results = await this.getAllReleases();
    return results.stable;
  }

  /**
   * 获取Next版本
   */
  async scrapeNextReleases() {
    const results = await this.getAllReleases();
    return results.next;
  }
}

module.exports = SimpleScraper;
