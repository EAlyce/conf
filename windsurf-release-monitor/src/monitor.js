const cron = require('node-cron');
const logger = require('./logger');
const { monitoringCycle, errorWithContext } = require('./logger');
// 使用简化的scraper避免Node.js兼容性问题
const SimpleScraper = require('./scraper-simple');
const scraper = new SimpleScraper();
const storage = require('./storage');
const telegram = require('./telegram');

class ReleaseMonitor {
  constructor() {
    this.isRunning = false;
    this.cronJob = null;
    this.cycleCounter = 0;
  }

  /**
   * Initialize the monitor
   */
  async initialize() {
    try {
      logger.info('Initializing Windsurf Release Monitor');
      
      // Initialize storage
      await storage.initialize();
      
      // Initialize Telegram bot
      await telegram.initialize();
      
      logger.info('Monitor initialization completed');
      return true;
    } catch (error) {
      errorWithContext('Failed to initialize monitor', error);
      throw error;
    }
  }

  /**
   * Run a single monitoring cycle
   */
  async runCycle() {
    if (this.isRunning) {
      logger.warn('Monitoring cycle already running, skipping');
      return;
    }

    const cycleId = ++this.cycleCounter;
    const startTime = Date.now();
    
    this.isRunning = true;
    
    try {
      logger.info('Starting monitoring cycle', { cycleId });
      
      // Scrape all releases
      const scrapedReleases = await scraper.getAllReleases();
      
      if (scrapedReleases.errors.length > 0) {
        logger.warn('Scraping completed with errors', { 
          errors: scrapedReleases.errors.length 
        });
        
        // Send error notifications for critical failures
        for (const error of scrapedReleases.errors) {
          await telegram.sendErrorNotification(new Error(error.error), {
            operation: `Scraping ${error.type} releases`,
            cycleId
          });
        }
      }
      
      const newReleases = [];
      let totalProcessed = 0;
      
      // Process stable releases
      for (const release of scrapedReleases.stable) {
        totalProcessed++;
        const isNew = await storage.isNewVersion('stable', release.version);
        
        if (isNew) {
          await storage.addVersion('stable', release.version, release);
          newReleases.push(release);
          logger.info('New stable release detected', { version: release.version });
        }
      }
      
      // Process Next releases
      for (const release of scrapedReleases.next) {
        totalProcessed++;
        const isNew = await storage.isNewVersion('next', release.version);
        
        if (isNew) {
          await storage.addVersion('next', release.version, release);
          newReleases.push(release);
          logger.info('New Next release detected', { version: release.version });
        }
      }
      
      // Send notifications for new releases
      if (newReleases.length > 0) {
        logger.info('Sending notifications for new releases', { count: newReleases.length });
        
        // Sort releases: stable first, then by version
        const sortedReleases = newReleases.sort((a, b) => {
          if (a.type !== b.type) {
            return a.type === 'stable' ? -1 : 1;
          }
          return b.version.localeCompare(a.version);
        });
        
        const notificationResults = await telegram.sendMultipleNotifications(sortedReleases);
        
        // Mark successfully notified releases
        for (const result of notificationResults.results) {
          if (result.success) {
            await storage.markAsNotified(result.release.type, result.release.version);
          }
        }
        
        if (notificationResults.errors.length > 0) {
          logger.error('Some notifications failed', { 
            failed: notificationResults.errors.length,
            total: newReleases.length 
          });
        }
      }
      
      // Check for any previously unnotified releases
      const unnotified = await storage.getUnnotifiedVersions();
      const totalUnnotified = unnotified.stable.length + unnotified.next.length;
      
      if (totalUnnotified > 0) {
        logger.info('Found unnotified releases from previous cycles', { count: totalUnnotified });
        
        const allUnnotified = [...unnotified.stable, ...unnotified.next];
        const retryResults = await telegram.sendMultipleNotifications(allUnnotified);
        
        // Mark successfully notified releases
        for (const result of retryResults.results) {
          if (result.success) {
            await storage.markAsNotified(result.release.type, result.release.version);
          }
        }
      }
      
      // Cleanup old data periodically
      if (cycleId % 10 === 0) {
        await storage.cleanup();
      }
      
      const duration = Date.now() - startTime;
      monitoringCycle(cycleId, 'completed', duration, newReleases.length);
      
      logger.info('Monitoring cycle completed', {
        cycleId,
        duration: `${duration}ms`,
        processed: totalProcessed,
        newReleases: newReleases.length,
        notifications: newReleases.length + totalUnnotified
      });
      
    } catch (error) {
      const duration = Date.now() - startTime;
      monitoringCycle(cycleId, 'failed', duration, 0);
      
      errorWithContext('Monitoring cycle failed', error, { cycleId });
      
      // Send error notification
      await telegram.sendErrorNotification(error, {
        operation: 'Monitoring cycle',
        cycleId
      });
      
      throw error;
    } finally {
      this.isRunning = false;
    }
  }

  /**
   * Start scheduled monitoring
   */
  startScheduled() {
    try {
      const intervalMinutes = config.monitoring.checkInterval;
      const cronExpression = `*/${intervalMinutes} * * * *`;
      
      logger.info('Starting scheduled monitoring', { 
        interval: `${intervalMinutes} minutes`,
        cronExpression 
      });
      
      this.cronJob = cron.schedule(cronExpression, async () => {
        try {
          await this.runCycle();
        } catch (error) {
          logger.error('Scheduled monitoring cycle failed', { error: error.message });
        }
      }, {
        scheduled: false,
        timezone: config.app.timezone
      });
      
      this.cronJob.start();
      
      logger.info('Scheduled monitoring started');
      return true;
    } catch (error) {
      errorWithContext('Failed to start scheduled monitoring', error);
      throw error;
    }
  }

  /**
   * Stop scheduled monitoring
   */
  stopScheduled() {
    if (this.cronJob) {
      this.cronJob.stop();
      this.cronJob = null;
      logger.info('Scheduled monitoring stopped');
    }
  }

  /**
   * Run once and exit (for GitHub Actions)
   */
  async runOnce() {
    try {
      logger.info('Running single monitoring cycle');
      
      await this.initialize();
      await this.runCycle();
      
      // Send status update to admins
      const stats = await storage.getStats();
      if (stats) {
        await telegram.sendStatusUpdate(stats);
      }
      
      logger.info('Single monitoring cycle completed successfully');
      return true;
    } catch (error) {
      errorWithContext('Single monitoring cycle failed', error);
      throw error;
    }
  }

  /**
   * Push latest version info to channel (for manual runs)
   */
  async pushLatestVersions() {
    try {
      logger.info('Pushing latest version info to channel');
      console.log('Starting pushLatestVersions...');
      
      await this.initialize();
      console.log('Initialization complete');
      
      // Scrape current releases
      console.log('Scraping releases from Windsurf...');
      const scrapedReleases = await scraper.getAllReleases();
      console.log(`Scraped ${scrapedReleases.stable.length} stable and ${scrapedReleases.next.length} next releases`);
      
      if (scrapedReleases.errors.length > 0) {
        logger.warn('Scraping completed with errors', { 
          errors: scrapedReleases.errors.length 
        });
      }
      
      // Get the latest stable and next releases
      const latestStable = scrapedReleases.stable.length > 0 ? scrapedReleases.stable[0] : null;
      const latestNext = scrapedReleases.next.length > 0 ? scrapedReleases.next[0] : null;
      
      const releasesToSend = [];
      
      if (latestStable) {
        // Add manual push indicator
        latestStable.manualPush = true;
        latestStable.pushType = '手动推送最新版本';
        releasesToSend.push(latestStable);
        logger.info('Latest stable release found', { version: latestStable.version });
      }
      
      if (latestNext) {
        // Add manual push indicator
        latestNext.manualPush = true;
        latestNext.pushType = '手动推送最新版本';
        releasesToSend.push(latestNext);
        logger.info('Latest Next release found', { version: latestNext.version });
      }
      
      if (releasesToSend.length === 0) {
        logger.warn('No releases found to push');
        return;
      }
      
      // Send notifications for new releases
      if (releasesToSend.length > 0) {
        logger.info('Sending manual push notifications', { count: releasesToSend.length });
        console.log(`Sending ${releasesToSend.length} release notifications...`);
        
        for (const release of releasesToSend) {
          console.log(`Sending notification for ${release.type} version ${release.version}...`);
          const result = await telegram.sendReleaseNotification(release);
          if (result.success) {
            logger.info('Manual push notification sent', { 
              version: release.version,
              type: release.type 
            });
            console.log(`✅ Successfully sent ${release.type} version ${release.version}`);
          } else {
            logger.error('Failed to send manual push notification', { 
              version: release.version,
              error: result.error 
            });
            console.error(`❌ Failed to send ${release.type} version ${release.version}: ${result.error}`);
          }
        }
        
        logger.info('Manual push completed successfully');
        console.log('✅ Manual push completed successfully');
      }
      
      return true;
    } catch (error) {
      errorWithContext('Failed to push latest versions', error);
      
      // Send error notification
      await telegram.sendErrorNotification(error, {
        operation: 'Push latest versions'
      });
      
      throw error;
    }
  }

  /**
   * Test the monitor without sending notifications
   */
  async test() {
    try {
      logger.info('Running monitor test');
      
      await this.initialize();
      
      // Test scraping
      const releases = await scraper.getAllReleases();
      logger.info('Test scraping completed', {
        stable: releases.stable.length,
        next: releases.next.length,
        errors: releases.errors.length
      });
      
      // Test Telegram (send test message)
      await telegram.sendTestNotification();
      
      // Get storage stats
      const stats = await storage.getStats();
      logger.info('Storage stats', stats);
      
      logger.info('Monitor test completed successfully');
      return {
        scraping: {
          stable: releases.stable.length,
          next: releases.next.length,
          errors: releases.errors.length
        },
        storage: stats,
        telegram: 'OK'
      };
    } catch (error) {
      errorWithContext('Monitor test failed', error);
      throw error;
    }
  }

  /**
   * Get monitor status
   */
  getStatus() {
    return {
      isRunning: this.isRunning,
      isScheduled: this.cronJob !== null,
      cycleCounter: this.cycleCounter,
      config: {
        checkInterval: config.monitoring.checkInterval,
        environment: config.app.environment,
        logLevel: config.app.logLevel
      }
    };
  }
}

module.exports = new ReleaseMonitor();
