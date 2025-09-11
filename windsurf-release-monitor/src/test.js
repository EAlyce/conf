#!/usr/bin/env node

const { logger } = require('./logger');
const { config, validateConfig } = require('./config');
const storage = require('./storage');
const scraper = require('./scraper');
const telegram = require('./telegram');

/**
 * Test suite for the Windsurf Release Monitor
 */
class TestSuite {
  constructor() {
    this.results = {
      config: false,
      storage: false,
      scraper: false,
      telegram: false,
      integration: false
    };
    this.errors = [];
  }

  /**
   * Run all tests
   */
  async runAll() {
    console.log('🧪 Running Windsurf Release Monitor Test Suite\n');
    
    try {
      await this.testConfig();
      await this.testStorage();
      await this.testScraper();
      await this.testTelegram();
      await this.testIntegration();
      
      this.printResults();
      
      const allPassed = Object.values(this.results).every(result => result === true);
      process.exit(allPassed ? 0 : 1);
      
    } catch (error) {
      console.error('❌ Test suite failed:', error.message);
      process.exit(1);
    }
  }

  /**
   * Test configuration
   */
  async testConfig() {
    console.log('📋 Testing Configuration...');
    
    try {
      validateConfig();
      
      // Check required environment variables
      const required = ['TELEGRAM_BOT_TOKEN', 'TELEGRAM_CHANNEL_ID'];
      const missing = required.filter(key => !process.env[key]);
      
      if (missing.length > 0) {
        throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
      }
      
      console.log('✅ Configuration valid');
      console.log(`   - Environment: ${config.app.environment}`);
      console.log(`   - Log Level: ${config.app.logLevel}`);
      console.log(`   - Check Interval: ${config.monitoring.checkInterval} minutes`);
      
      this.results.config = true;
    } catch (error) {
      console.error('❌ Configuration test failed:', error.message);
      this.errors.push({ test: 'config', error: error.message });
    }
    
    console.log('');
  }

  /**
   * Test storage functionality
   */
  async testStorage() {
    console.log('💾 Testing Storage...');
    
    try {
      await storage.initialize();
      
      // Test version operations
      const testVersion = {
        version: 'test-1.0.0',
        type: 'stable',
        detectedAt: new Date().toISOString(),
        downloads: { test: 'data' }
      };
      
      // Add test version
      await storage.addVersion('stable', testVersion.version, testVersion);
      
      // Check if it's marked as new (should be false now)
      const isNew = await storage.isNewVersion('stable', testVersion.version);
      if (isNew) {
        throw new Error('Version should not be marked as new after adding');
      }
      
      // Mark as notified
      await storage.markAsNotified('stable', testVersion.version);
      
      // Get stats
      const stats = await storage.getStats();
      if (!stats || typeof stats.stable.total !== 'number') {
        throw new Error('Invalid stats format');
      }
      
      console.log('✅ Storage tests passed');
      console.log(`   - Stable versions: ${stats.stable.total}`);
      console.log(`   - Next versions: ${stats.next.total}`);
      
      this.results.storage = true;
    } catch (error) {
      console.error('❌ Storage test failed:', error.message);
      this.errors.push({ test: 'storage', error: error.message });
    }
    
    console.log('');
  }

  /**
   * Test scraper functionality
   */
  async testScraper() {
    console.log('🕷️ Testing Scraper...');
    
    try {
      // Test stable releases scraping
      console.log('   Testing stable releases...');
      const stableReleases = await scraper.parseStableReleases();
      
      if (!Array.isArray(stableReleases)) {
        throw new Error('Stable releases should return an array');
      }
      
      console.log(`   ✅ Found ${stableReleases.length} stable releases`);
      
      if (stableReleases.length > 0) {
        const latest = stableReleases[0];
        console.log(`   - Latest: ${latest.version}`);
        console.log(`   - Downloads: ${Object.keys(latest.downloads || {}).length} platforms`);
      }
      
      // Test Next releases scraping
      console.log('   Testing Next releases...');
      const nextReleases = await scraper.parseNextReleases();
      
      if (!Array.isArray(nextReleases)) {
        throw new Error('Next releases should return an array');
      }
      
      console.log(`   ✅ Found ${nextReleases.length} Next releases`);
      
      // Test complete scraping
      console.log('   Testing complete scraping...');
      const allReleases = await scraper.getAllReleases();
      
      if (!allReleases.stable || !allReleases.next) {
        throw new Error('Complete scraping should return stable and next arrays');
      }
      
      console.log('✅ Scraper tests passed');
      console.log(`   - Total stable: ${allReleases.stable.length}`);
      console.log(`   - Total next: ${allReleases.next.length}`);
      console.log(`   - Errors: ${allReleases.errors.length}`);
      
      this.results.scraper = true;
    } catch (error) {
      console.error('❌ Scraper test failed:', error.message);
      this.errors.push({ test: 'scraper', error: error.message });
    }
    
    console.log('');
  }

  /**
   * Test Telegram functionality
   */
  async testTelegram() {
    console.log('📱 Testing Telegram...');
    
    try {
      await telegram.initialize();
      
      // Create test release
      const testRelease = {
        version: 'test-1.0.0',
        type: 'stable',
        downloads: {
          'Windows': [
            { name: 'Windows x64 (.exe)', url: 'https://example.com/test.exe' }
          ],
          'macOS': [
            { name: 'macOS (.dmg)', url: 'https://example.com/test.dmg' }
          ]
        },
        changelog: 'https://example.com/changelog',
        detectedAt: new Date().toISOString()
      };
      
      // Test message formatting
      const message = telegram.formatReleaseMessage(testRelease);
      if (!message || message.length < 10) {
        throw new Error('Message formatting failed');
      }
      
      console.log('✅ Message formatting works');
      console.log(`   - Message length: ${message.length} characters`);
      
      // Test bot connection (don't send actual message in test)
      console.log('✅ Telegram bot connection verified');
      
      this.results.telegram = true;
    } catch (error) {
      console.error('❌ Telegram test failed:', error.message);
      this.errors.push({ test: 'telegram', error: error.message });
    }
    
    console.log('');
  }

  /**
   * Test integration workflow
   */
  async testIntegration() {
    console.log('🔄 Testing Integration...');
    
    try {
      // Test the complete workflow without sending notifications
      console.log('   Testing complete workflow...');
      
      // 1. Scrape releases
      const releases = await scraper.getAllReleases();
      
      // 2. Check storage for each release
      let newCount = 0;
      for (const release of [...releases.stable, ...releases.next]) {
        const isNew = await storage.isNewVersion(release.type, release.version);
        if (isNew) {
          newCount++;
        }
      }
      
      // 3. Test notification formatting for a sample
      if (releases.stable.length > 0) {
        const sampleRelease = releases.stable[0];
        const message = telegram.formatReleaseMessage(sampleRelease);
        
        if (!message.includes(sampleRelease.version)) {
          throw new Error('Message should contain version number');
        }
      }
      
      console.log('✅ Integration workflow works');
      console.log(`   - Total releases found: ${releases.stable.length + releases.next.length}`);
      console.log(`   - Potentially new: ${newCount}`);
      
      this.results.integration = true;
    } catch (error) {
      console.error('❌ Integration test failed:', error.message);
      this.errors.push({ test: 'integration', error: error.message });
    }
    
    console.log('');
  }

  /**
   * Print test results summary
   */
  printResults() {
    console.log('📊 Test Results Summary');
    console.log('========================');
    
    for (const [test, passed] of Object.entries(this.results)) {
      const status = passed ? '✅ PASS' : '❌ FAIL';
      console.log(`${status} ${test.charAt(0).toUpperCase() + test.slice(1)}`);
    }
    
    console.log('');
    
    const totalTests = Object.keys(this.results).length;
    const passedTests = Object.values(this.results).filter(r => r).length;
    
    console.log(`Total: ${totalTests}, Passed: ${passedTests}, Failed: ${totalTests - passedTests}`);
    
    if (this.errors.length > 0) {
      console.log('\n❌ Errors:');
      this.errors.forEach((error, index) => {
        console.log(`${index + 1}. ${error.test}: ${error.error}`);
      });
    }
    
    console.log('');
    
    if (passedTests === totalTests) {
      console.log('🎉 All tests passed! The monitor is ready to run.');
    } else {
      console.log('⚠️ Some tests failed. Please fix the issues before deploying.');
    }
  }
}

// Run tests if this file is executed directly
if (require.main === module) {
  const testSuite = new TestSuite();
  testSuite.runAll();
}

module.exports = TestSuite;
