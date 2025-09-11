# Windsurf Release Monitor

A production-grade Telegram bot that monitors Windsurf and Windsurf Next releases and automatically posts updates to a Telegram channel.

## Features

- 🚀 **Automatic Release Detection**: Monitors both Windsurf stable and Next releases
- 📱 **Telegram Notifications**: Sends formatted messages to your Telegram channel
- 🔄 **GitHub Actions Integration**: Runs automatically every 30 minutes
- 📊 **Comprehensive Logging**: Detailed logs with Winston logger
- 💾 **Persistent Storage**: Tracks release history to avoid duplicates
- 🛡️ **Error Handling**: Robust error handling with admin notifications
- 🧪 **Test Mode**: Built-in testing capabilities

## Quick Start

### 1. Create a Telegram Bot

1. Message [@BotFather](https://t.me/BotFather) on Telegram
2. Use `/newbot` command and follow instructions
3. Save the bot token

### 2. Get Channel ID

1. Add your bot to your channel as an administrator
2. Send a message to your channel
3. Visit `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
4. Find your channel ID in the response

### 3. Configure GitHub Secrets

Add these secrets to your GitHub repository:

- `TELEGRAM_BOT_TOKEN`: Your bot token from BotFather
- `TELEGRAM_CHANNEL_ID`: Your channel ID (e.g., `@yourchannel` or `-1001234567890`)
- `TELEGRAM_ADMIN_IDS`: (Optional) Comma-separated admin user IDs for error notifications

### 4. Deploy

The GitHub Action will run automatically every 30 minutes. You can also trigger it manually from the Actions tab.

## Local Development

### Prerequisites

- Node.js 18+
- npm or yarn

### Installation

```bash
cd windsurf-release-monitor
npm install
```

### Configuration

```bash
cp .env.example .env
# Edit .env with your configuration
```

### Running

```bash
# Test configuration
npm run test

# Run once
npm start

# Run continuously (development)
node src/index.js run
```

## Commands

```bash
node src/index.js [command]
```

- `run` / `start`: Start continuous monitoring
- `once`: Run once and exit (for GitHub Actions)
- `test`: Test configuration and connections
- `status`: Show current monitor status
- `help`: Show help message

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `TELEGRAM_BOT_TOKEN` | ✅ | - | Telegram bot token |
| `TELEGRAM_CHANNEL_ID` | ✅ | - | Telegram channel ID |
| `TELEGRAM_ADMIN_IDS` | ❌ | - | Admin user IDs (comma-separated) |
| `CHECK_INTERVAL_MINUTES` | ❌ | 30 | Check interval in minutes |
| `LOG_LEVEL` | ❌ | info | Log level (error, warn, info, debug) |
| `NODE_ENV` | ❌ | development | Environment (development, production) |
| `MAX_RETRIES` | ❌ | 3 | Maximum request retries |
| `REQUEST_TIMEOUT_MS` | ❌ | 30000 | Request timeout in milliseconds |

## Architecture

```
src/
├── index.js      # Main entry point
├── config.js     # Configuration management
├── logger.js     # Winston logging setup
├── storage.js    # Data persistence layer
├── scraper.js    # Web scraping logic
├── telegram.js   # Telegram bot integration
└── monitor.js    # Main monitoring orchestrator
```

## Monitoring Sources

- **Stable Releases**: https://windsurf.com/editor/releases
- **Next Releases**: https://windsurf.com/changelog/windsurf-next
- **Download Links**: Extracted from release pages

## Message Format

The bot sends formatted messages with:

- 🚀 Release type (Stable/Next)
- 📦 Version number
- 📝 Change notes (for Next releases)
- 💾 Download links by platform
- 📖 Changelog links
- 🕒 Detection timestamp

## GitHub Actions Workflow

The workflow:

1. Runs every 30 minutes via cron
2. Checks for new releases
3. Sends notifications for new versions
4. Caches data between runs
5. Uploads logs as artifacts
6. Handles errors gracefully

## Error Handling

- **Request Failures**: Automatic retries with exponential backoff
- **Telegram Errors**: Admin notifications for critical failures
- **Data Corruption**: Automatic recovery with default values
- **Rate Limiting**: Built-in delays between requests

## Logging

Comprehensive logging with:

- **File Logging**: Rotating log files with size limits
- **Console Output**: Colored output for development
- **GitHub Actions**: Formatted output for CI/CD
- **Structured Data**: JSON format for easy parsing

## Data Storage

- **Versions File**: JSON file tracking all detected releases
- **Persistent Cache**: GitHub Actions cache for data continuity
- **Cleanup**: Automatic cleanup of old data (keeps last 50 versions)

## Testing

```bash
# Test all components
node src/index.js test

# Test specific functionality
npm run test
```

## Troubleshooting

### Common Issues

1. **Bot not posting**: Check bot permissions in channel
2. **No releases detected**: Verify Windsurf website accessibility
3. **GitHub Action failing**: Check secrets configuration
4. **Rate limiting**: Increase delays in configuration

### Debug Mode

Set `LOG_LEVEL=debug` for detailed logging.

### Manual Testing

Use the workflow dispatch feature in GitHub Actions to test manually.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

- Create an issue for bug reports
- Check logs for troubleshooting
- Review GitHub Actions output for errors

---

**Note**: This bot is designed for production use with proper error handling, logging, and monitoring capabilities.
