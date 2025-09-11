const winston = require('winston');
const path = require('path');
const fs = require('fs');
const { config } = require('./config');

// Ensure logs directory exists
const logsDir = path.dirname(config.storage.logFile);
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

// Custom format for logs
const logFormat = winston.format.combine(
  winston.format.timestamp({
    format: 'YYYY-MM-DD HH:mm:ss'
  }),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.prettyPrint()
);

// Console format for development
const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp({
    format: 'HH:mm:ss'
  }),
  winston.format.printf(({ timestamp, level, message, stack }) => {
    return `${timestamp} [${level}]: ${stack || message}`;
  })
);

// Create logger instance
const logger = winston.createLogger({
  level: config.app.logLevel,
  format: logFormat,
  defaultMeta: {
    service: 'windsurf-release-monitor',
    environment: config.app.environment,
    githubRunId: config.github.runId
  },
  transports: [
    // File transport for all logs
    new winston.transports.File({
      filename: config.storage.logFile,
      maxsize: 10 * 1024 * 1024, // 10MB
      maxFiles: 5,
      tailable: true
    }),
    
    // Separate file for errors
    new winston.transports.File({
      filename: path.join(logsDir, 'error.log'),
      level: 'error',
      maxsize: 5 * 1024 * 1024, // 5MB
      maxFiles: 3,
      tailable: true
    })
  ],
  
  // Handle uncaught exceptions
  exceptionHandlers: [
    new winston.transports.File({
      filename: path.join(logsDir, 'exceptions.log')
    })
  ],
  
  // Handle unhandled promise rejections
  rejectionHandlers: [
    new winston.transports.File({
      filename: path.join(logsDir, 'rejections.log')
    })
  ]
});

// Add console transport for development
if (config.app.environment === 'development') {
  logger.add(new winston.transports.Console({
    format: consoleFormat
  }));
}

// Add console transport for GitHub Actions
if (config.github.runId) {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.timestamp(),
      winston.format.printf(({ timestamp, level, message }) => {
        return `::${level === 'error' ? 'error' : 'notice'}::${timestamp} [${level.toUpperCase()}] ${message}`;
      })
    )
  }));
}

// Helper functions for structured logging
const logHelpers = {
  // Log release detection
  releaseDetected: (type, version, isNew = false) => {
    logger.info('Release detected', {
      type,
      version,
      isNew,
      action: isNew ? 'new_release' : 'existing_release'
    });
  },

  // Log API requests
  apiRequest: (url, method = 'GET', status = null, duration = null) => {
    logger.debug('API request', {
      url,
      method,
      status,
      duration: duration ? `${duration}ms` : null
    });
  },

  // Log Telegram operations
  telegramMessage: (channelId, messageType, success = true, error = null) => {
    const level = success ? 'info' : 'error';
    logger[level]('Telegram message', {
      channelId,
      messageType,
      success,
      error: error ? error.message : null
    });
  },

  // Log monitoring cycle
  monitoringCycle: (cycleId, status, duration = null, releasesFound = 0) => {
    logger.info('Monitoring cycle', {
      cycleId,
      status,
      duration: duration ? `${duration}ms` : null,
      releasesFound
    });
  },

  // Log errors with context
  errorWithContext: (message, error, context = {}) => {
    logger.error(message, {
      error: {
        message: error.message,
        stack: error.stack,
        name: error.name
      },
      context
    });
  }
};

module.exports = {
  logger,
  ...logHelpers
};
