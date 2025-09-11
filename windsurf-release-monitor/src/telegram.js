const TelegramBot = require('node-telegram-bot-api');
const { logger, telegramMessage, errorWithContext } = require('./logger');
const { config } = require('./config');

class TelegramNotifier {
  constructor() {
    this.bot = null;
    this.initialized = false;
  }

  /**
   * Initialize Telegram bot
   */
  async initialize() {
    try {
      if (!config.telegram.botToken) {
        throw new Error('Telegram bot token is required');
      }

      this.bot = new TelegramBot(config.telegram.botToken, { polling: false });
      
      // Test the bot token
      const botInfo = await this.bot.getMe();
      logger.info('Telegram bot initialized', { 
        username: botInfo.username,
        id: botInfo.id 
      });
      
      this.initialized = true;
      return true;
    } catch (error) {
      errorWithContext('Failed to initialize Telegram bot', error);
      throw error;
    }
  }

  /**
   * Format release message for Telegram
   */
  formatReleaseMessage(release) {
    const { version, type, downloads, changelog, changes, title, manualPush, pushType } = release;
    
    let message = '';
    
    // Header with emoji based on type
    const emoji = type === 'stable' ? '🚀' : '🧪';
    const typeLabel = type === 'stable' ? 'Stable Release' : 'Next Release';
    
    message += `${emoji} *Windsurf ${typeLabel}*\n`;
    message += `📦 Version: \`${version}\`\n`;
    
    // Add manual push indicator if applicable
    if (manualPush && pushType) {
      message += `🔔 ${this.escapeMarkdown(pushType)}\n`;
    }
    
    message += '\n';
    
    // Add title for Next releases
    if (title && type === 'next') {
      message += `📋 *${this.escapeMarkdown(title)}*\n\n`;
    }
    
    // Add changes for Next releases
    if (changes && changes.length > 0) {
      message += `📝 *Changes:*\n`;
      changes.slice(0, 5).forEach(change => {
        message += `• ${this.escapeMarkdown(change)}\n`;
      });
      if (changes.length > 5) {
        message += `• _...and ${changes.length - 5} more changes_\n`;
      }
      message += '\n';
    }
    
    // Add download links
    if (downloads && Object.keys(downloads).length > 0) {
      message += `💾 *Downloads:*\n`;
      
      for (const [platform, links] of Object.entries(downloads)) {
        if (links && links.length > 0) {
          message += `\n*${platform}:*\n`;
          links.slice(0, 3).forEach(link => {
            const linkText = this.escapeMarkdown(link.name);
            message += `• [${linkText}](${link.url})\n`;
          });
          if (links.length > 3) {
            message += `• _...and ${links.length - 3} more options_\n`;
          }
        }
      }
      message += '\n';
    } else if (type === 'next') {
      message += `💾 [Download Windsurf Next](${config.windsurf.nextDownloadUrl})\n\n`;
    }
    
    // Add changelog link
    if (changelog) {
      message += `📖 [View Changelog](${changelog})\n`;
    }
    
    // Add footer
    message += `\n🕒 Detected: ${new Date(release.detectedAt).toLocaleString('en-US', { 
      timeZone: 'UTC',
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })} UTC`;
    
    return message;
  }

  /**
   * Escape markdown special characters
   */
  escapeMarkdown(text) {
    if (!text) return '';
    return text.replace(/[_*\[\]()~`>#+=|{}.!-]/g, '\\$&');
  }

  /**
   * Send release notification to channel
   */
  async sendReleaseNotification(release) {
    try {
      if (!this.initialized) {
        await this.initialize();
      }

      const message = this.formatReleaseMessage(release);
      const channelId = config.telegram.channelId;
      
      const options = {
        parse_mode: 'MarkdownV2',
        disable_web_page_preview: false,
        disable_notification: false
      };

      const result = await this.bot.sendMessage(channelId, message, options);
      
      telegramMessage(channelId, 'release_notification', true);
      
      logger.info('Release notification sent', {
        version: release.version,
        type: release.type,
        messageId: result.message_id,
        channelId
      });
      
      return result;
    } catch (error) {
      telegramMessage(config.telegram.channelId, 'release_notification', false, error);
      errorWithContext('Failed to send release notification', error, { release });
      throw error;
    }
  }

  /**
   * Send multiple release notifications
   */
  async sendMultipleNotifications(releases) {
    const results = [];
    const errors = [];
    
    for (const release of releases) {
      try {
        const result = await this.sendReleaseNotification(release);
        results.push({ release, result, success: true });
        
        // Add delay between messages to avoid rate limiting
        if (releases.length > 1) {
          await this.sleep(2000);
        }
      } catch (error) {
        errors.push({ release, error, success: false });
        results.push({ release, error, success: false });
      }
    }
    
    logger.info('Multiple notifications sent', {
      total: releases.length,
      successful: results.filter(r => r.success).length,
      failed: errors.length
    });
    
    return { results, errors };
  }

  /**
   * Send error notification to admins
   */
  async sendErrorNotification(error, context = {}) {
    try {
      if (!config.telegram.adminIds || config.telegram.adminIds.length === 0) {
        return;
      }

      if (!this.initialized) {
        await this.initialize();
      }

      const message = this.formatErrorMessage(error, context);
      
      for (const adminId of config.telegram.adminIds) {
        try {
          await this.bot.sendMessage(adminId, message, { 
            parse_mode: 'MarkdownV2' 
          });
          
          telegramMessage(adminId, 'error_notification', true);
        } catch (adminError) {
          telegramMessage(adminId, 'error_notification', false, adminError);
        }
      }
    } catch (error) {
      logger.error('Failed to send error notification', { error: error.message });
    }
  }

  /**
   * Format error message
   */
  formatErrorMessage(error, context) {
    let message = '🚨 *Windsurf Release Monitor Error*\n\n';
    message += `❌ *Error:* \`${this.escapeMarkdown(error.message)}\`\n`;
    
    if (context.operation) {
      message += `🔧 *Operation:* ${this.escapeMarkdown(context.operation)}\n`;
    }
    
    if (context.url) {
      message += `🌐 *URL:* ${this.escapeMarkdown(context.url)}\n`;
    }
    
    if (config.github.runId) {
      message += `🔗 *GitHub Run:* \`${config.github.runId}\`\n`;
    }
    
    message += `\n🕒 *Time:* ${new Date().toISOString()}`;
    
    return message;
  }

  /**
   * Send status update
   */
  async sendStatusUpdate(stats) {
    try {
      if (!config.telegram.adminIds || config.telegram.adminIds.length === 0) {
        return;
      }

      if (!this.initialized) {
        await this.initialize();
      }

      let message = '📊 *Windsurf Monitor Status*\n\n';
      message += `📦 *Stable Releases:* ${stats.stable.total} total, ${stats.stable.unnotified} pending\n`;
      message += `🧪 *Next Releases:* ${stats.next.total} total, ${stats.next.unnotified} pending\n`;
      
      if (stats.lastCheck) {
        message += `🕒 *Last Check:* ${new Date(stats.lastCheck).toLocaleString()}\n`;
      }
      
      if (config.github.runId) {
        message += `🔗 *GitHub Run:* \`${config.github.runId}\`\n`;
      }

      for (const adminId of config.telegram.adminIds) {
        try {
          await this.bot.sendMessage(adminId, message, { 
            parse_mode: 'MarkdownV2' 
          });
        } catch (error) {
          logger.warn('Failed to send status to admin', { adminId, error: error.message });
        }
      }
    } catch (error) {
      logger.error('Failed to send status update', { error: error.message });
    }
  }

  /**
   * Test notification
   */
  async sendTestNotification() {
    try {
      if (!this.initialized) {
        await this.initialize();
      }

      const testMessage = `🧪 *Windsurf Release Monitor Test*\n\n` +
                         `✅ Bot is working correctly\\!\n` +
                         `🕒 Test time: ${new Date().toISOString()}\n` +
                         `🤖 Bot: @${(await this.bot.getMe()).username}`;

      const result = await this.bot.sendMessage(config.telegram.channelId, testMessage, {
        parse_mode: 'MarkdownV2'
      });

      logger.info('Test notification sent', { messageId: result.message_id });
      return result;
    } catch (error) {
      errorWithContext('Failed to send test notification', error);
      throw error;
    }
  }

  /**
   * Sleep utility
   */
  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = new TelegramNotifier();
