#!/usr/bin/env node

const fs = require('fs').promises;
const path = require('path');
const readline = require('readline');

/**
 * Interactive setup script for Windsurf Release Monitor
 */
class SetupWizard {
  constructor() {
    this.rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
    this.config = {};
  }

  /**
   * Ask a question and return the answer
   */
  async ask(question, defaultValue = '') {
    return new Promise((resolve) => {
      const prompt = defaultValue ? `${question} (${defaultValue}): ` : `${question}: `;
      this.rl.question(prompt, (answer) => {
        resolve(answer.trim() || defaultValue);
      });
    });
  }

  /**
   * Ask a yes/no question
   */
  async askYesNo(question, defaultValue = false) {
    const defaultText = defaultValue ? 'Y/n' : 'y/N';
    const answer = await this.ask(`${question} (${defaultText})`);
    
    if (!answer) return defaultValue;
    return answer.toLowerCase().startsWith('y');
  }

  /**
   * Validate Telegram bot token format
   */
  validateBotToken(token) {
    return /^\d+:[A-Za-z0-9_-]{35}$/.test(token);
  }

  /**
   * Validate channel ID format
   */
  validateChannelId(channelId) {
    return channelId.startsWith('@') || channelId.startsWith('-');
  }

  /**
   * Main setup flow
   */
  async run() {
    console.log('🚀 Windsurf Release Monitor Setup Wizard');
    console.log('=========================================\n');

    try {
      // Welcome and prerequisites
      console.log('This wizard will help you configure the Windsurf Release Monitor.');
      console.log('Make sure you have:');
      console.log('1. Created a Telegram bot via @BotFather');
      console.log('2. Added the bot to your channel as an administrator');
      console.log('3. Obtained your channel ID\n');

      const proceed = await this.askYesNo('Do you want to continue?', true);
      if (!proceed) {
        console.log('Setup cancelled.');
        process.exit(0);
      }

      console.log('');

      // Telegram Bot Configuration
      console.log('📱 Telegram Bot Configuration');
      console.log('-----------------------------');

      let botToken;
      do {
        botToken = await this.ask('Enter your Telegram bot token');
        if (!this.validateBotToken(botToken)) {
          console.log('❌ Invalid bot token format. Should be like: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz');
        }
      } while (!this.validateBotToken(botToken));

      let channelId;
      do {
        channelId = await this.ask('Enter your Telegram channel ID (e.g., @mychannel or -1001234567890)');
        if (!this.validateChannelId(channelId)) {
          console.log('❌ Invalid channel ID format. Should start with @ or -');
        }
      } while (!this.validateChannelId(channelId));

      const adminIds = await this.ask('Enter admin user IDs for error notifications (comma-separated, optional)');

      // Monitoring Configuration
      console.log('\n⚙️ Monitoring Configuration');
      console.log('---------------------------');

      const checkInterval = await this.ask('Check interval in minutes', '30');
      const logLevel = await this.ask('Log level (error, warn, info, debug)', 'info');
      const environment = await this.ask('Environment (development, production)', 'production');

      // Build configuration
      this.config = {
        TELEGRAM_BOT_TOKEN: botToken,
        TELEGRAM_CHANNEL_ID: channelId,
        TELEGRAM_ADMIN_IDS: adminIds,
        CHECK_INTERVAL_MINUTES: checkInterval,
        LOG_LEVEL: logLevel,
        NODE_ENV: environment,
        MAX_RETRIES: '3',
        REQUEST_TIMEOUT_MS: '30000',
        REQUEST_DELAY_MS: '1000',
        VERSIONS_FILE: './data/versions.json',
        LOG_FILE: './logs/app.log',
        TZ: 'UTC'
      };

      // Create .env file
      console.log('\n📝 Creating configuration file...');
      await this.createEnvFile();

      // Create directories
      console.log('📁 Creating directories...');
      await this.createDirectories();

      // Test configuration
      console.log('\n🧪 Testing configuration...');
      const testPassed = await this.testConfiguration();

      if (testPassed) {
        console.log('\n✅ Setup completed successfully!');
        console.log('\nNext steps:');
        console.log('1. Run: npm test (to verify everything works)');
        console.log('2. Run: npm start (to start monitoring)');
        console.log('3. Configure GitHub secrets for automated deployment');
        console.log('\nGitHub Secrets needed:');
        console.log(`- TELEGRAM_BOT_TOKEN: ${botToken}`);
        console.log(`- TELEGRAM_CHANNEL_ID: ${channelId}`);
        if (adminIds) {
          console.log(`- TELEGRAM_ADMIN_IDS: ${adminIds}`);
        }
      } else {
        console.log('\n⚠️ Setup completed with warnings.');
        console.log('Please check the configuration and try running tests manually.');
      }

    } catch (error) {
      console.error('\n❌ Setup failed:', error.message);
      process.exit(1);
    } finally {
      this.rl.close();
    }
  }

  /**
   * Create .env file
   */
  async createEnvFile() {
    const envContent = Object.entries(this.config)
      .map(([key, value]) => `${key}=${value}`)
      .join('\n');

    const envHeader = `# Windsurf Release Monitor Configuration
# Generated by setup wizard on ${new Date().toISOString()}

`;

    await fs.writeFile('.env', envHeader + envContent);
    console.log('✅ Created .env file');
  }

  /**
   * Create necessary directories
   */
  async createDirectories() {
    const dirs = ['data', 'logs'];
    
    for (const dir of dirs) {
      try {
        await fs.mkdir(dir, { recursive: true });
        console.log(`✅ Created ${dir}/ directory`);
      } catch (error) {
        console.log(`⚠️ Could not create ${dir}/ directory:`, error.message);
      }
    }
  }

  /**
   * Test the configuration
   */
  async testConfiguration() {
    try {
      // Set environment variables
      Object.entries(this.config).forEach(([key, value]) => {
        process.env[key] = value;
      });

      // Import and test modules
      const { validateConfig } = require('./src/config');
      const telegram = require('./src/telegram');

      // Test config validation
      validateConfig();
      console.log('✅ Configuration validation passed');

      // Test Telegram bot
      await telegram.initialize();
      console.log('✅ Telegram bot connection successful');

      return true;
    } catch (error) {
      console.error('❌ Configuration test failed:', error.message);
      return false;
    }
  }
}

// Run setup if this file is executed directly
if (require.main === module) {
  const wizard = new SetupWizard();
  wizard.run();
}

module.exports = SetupWizard;
