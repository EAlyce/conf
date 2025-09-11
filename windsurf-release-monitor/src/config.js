const dotenv = require('dotenv');
dotenv.config();

const config = {
  // Telegram Bot Configuration
  telegram: {
    botToken: process.env.TELEGRAM_BOT_TOKEN,
    channelId: process.env.TELEGRAM_CHANNEL_ID,
    // Optional: Admin user IDs for error notifications
    adminIds: process.env.TELEGRAM_ADMIN_IDS ? process.env.TELEGRAM_ADMIN_IDS.split(',') : []
  },

  // Windsurf Release URLs
  windsurf: {
    stableReleasesUrl: 'https://windsurf.com/editor/releases',
    nextReleasesUrl: 'https://windsurf.com/changelog/windsurf-next',
    nextDownloadUrl: 'https://windsurf.com/editor/download-next',
    changelogBaseUrl: 'https://windsurf.com/changelog'
  },

  // Monitoring Configuration
  monitoring: {
    // Check interval in minutes (default: every 30 minutes)
    checkInterval: parseInt(process.env.CHECK_INTERVAL_MINUTES) || 30,
    // Maximum retries for failed requests
    maxRetries: parseInt(process.env.MAX_RETRIES) || 3,
    // Request timeout in milliseconds
    requestTimeout: parseInt(process.env.REQUEST_TIMEOUT_MS) || 30000,
    // Rate limiting: delay between requests in milliseconds
    requestDelay: parseInt(process.env.REQUEST_DELAY_MS) || 1000
  },

  // Storage Configuration
  storage: {
    // File to store last known versions
    versionsFile: process.env.VERSIONS_FILE || './data/versions.json',
    // File to store logs
    logFile: process.env.LOG_FILE || './logs/app.log'
  },

  // GitHub Actions Configuration
  github: {
    runId: process.env.GITHUB_RUN_ID,
    repository: process.env.GITHUB_REPOSITORY,
    actor: process.env.GITHUB_ACTOR
  },

  // Application Configuration
  app: {
    // Environment: development, production
    environment: process.env.NODE_ENV || 'development',
    // Log level: error, warn, info, debug
    logLevel: process.env.LOG_LEVEL || 'info',
    // Timezone for logging
    timezone: process.env.TZ || 'UTC'
  }
};

// Validation function
function validateConfig() {
  const errors = [];

  if (!config.telegram.botToken) {
    errors.push('TELEGRAM_BOT_TOKEN is required');
  }

  if (!config.telegram.channelId) {
    errors.push('TELEGRAM_CHANNEL_ID is required');
  }

  if (errors.length > 0) {
    throw new Error(`Configuration validation failed:\n${errors.join('\n')}`);
  }

  return true;
}

module.exports = {
  config,
  validateConfig
};
