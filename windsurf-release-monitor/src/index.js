#!/usr/bin/env node

const { logger } = require('./logger');
const { config, validateConfig } = require('./config');
const monitor = require('./monitor');

// Handle process signals gracefully
process.on('SIGINT', () => {
  logger.info('Received SIGINT, shutting down gracefully');
  monitor.stopScheduled();
  process.exit(0);
});

process.on('SIGTERM', () => {
  logger.info('Received SIGTERM, shutting down gracefully');
  monitor.stopScheduled();
  process.exit(0);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught exception', { error: error.message, stack: error.stack });
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled rejection', { reason, promise });
  process.exit(1);
});

/**
 * Main application entry point
 */
async function main() {
  try {
    // Validate configuration
    validateConfig();
    
    logger.info('Starting Windsurf Release Monitor', {
      version: '1.0.0',
      environment: config.app.environment,
      logLevel: config.app.logLevel,
      checkInterval: config.monitoring.checkInterval
    });

    // Parse command line arguments
    const args = process.argv.slice(2);
    const command = args[0] || 'run';

    switch (command) {
      case 'run':
      case 'start':
        // Run continuous monitoring (for local development)
        await monitor.initialize();
        monitor.startScheduled();
        
        logger.info('Monitor started in continuous mode');
        logger.info('Press Ctrl+C to stop');
        
        // Keep the process alive
        process.stdin.resume();
        break;

      case 'once':
        // Run once and exit (for GitHub Actions)
        await monitor.runOnce();
        process.exit(0);
        break;

      case 'latest':
        // Push latest version info to channel
        await monitor.pushLatestVersions();
        process.exit(0);
        break;

      case 'test':
        // Test mode - check configuration and connections
        const testResults = await monitor.test();
        
        console.log('\n=== Test Results ===');
        console.log(`Scraping: ${testResults.scraping.stable} stable, ${testResults.scraping.next} next releases`);
        console.log(`Storage: ${testResults.storage.stable.total} stable, ${testResults.storage.next.total} next stored`);
        console.log(`Telegram: ${testResults.telegram}`);
        console.log('===================\n');
        
        process.exit(0);
        break;

      case 'status':
        // Show current status
        const status = monitor.getStatus();
        
        console.log('\n=== Monitor Status ===');
        console.log(`Running: ${status.isRunning}`);
        console.log(`Scheduled: ${status.isScheduled}`);
        console.log(`Cycles completed: ${status.cycleCounter}`);
        console.log(`Check interval: ${status.config.checkInterval} minutes`);
        console.log(`Environment: ${status.config.environment}`);
        console.log('=====================\n');
        
        process.exit(0);
        break;

      case 'help':
      case '--help':
      case '-h':
        console.log(`
Windsurf Release Monitor v1.0.0

Usage: node src/index.js [command]

Commands:
  run, start    Start continuous monitoring (default)
  once          Run once and exit (for GitHub Actions)
  latest        Push latest version info to channel
  test          Test configuration and connections
  status        Show current monitor status
  help          Show this help message

Environment Variables:
  TELEGRAM_BOT_TOKEN      Telegram bot token (required)
  TELEGRAM_CHANNEL_ID     Telegram channel ID (required)
  TELEGRAM_ADMIN_IDS      Comma-separated admin user IDs (optional)
  CHECK_INTERVAL_MINUTES  Check interval in minutes (default: 30)
  LOG_LEVEL              Log level: error, warn, info, debug (default: info)
  NODE_ENV               Environment: development, production (default: development)

Examples:
  node src/index.js run     # Start continuous monitoring
  node src/index.js once    # Run once (for GitHub Actions)
  node src/index.js test    # Test configuration
        `);
        process.exit(0);
        break;

      default:
        logger.error('Unknown command', { command });
        console.error(`Unknown command: ${command}`);
        console.error('Use "node src/index.js help" for usage information');
        process.exit(1);
    }

  } catch (error) {
    logger.error('Application startup failed', { 
      error: error.message, 
      stack: error.stack 
    });
    
    console.error('Failed to start application:', error.message);
    
    if (config.app.environment === 'development') {
      console.error(error.stack);
    }
    
    process.exit(1);
  }
}

// Start the application
if (require.main === module) {
  main();
}

module.exports = { main };
