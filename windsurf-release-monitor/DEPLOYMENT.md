# Deployment Guide

This guide will help you deploy the Windsurf Release Monitor to your GitHub repository.

## Prerequisites

1. **Telegram Bot**: Create a bot via [@BotFather](https://t.me/BotFather)
2. **Telegram Channel**: Create a channel and add your bot as administrator
3. **GitHub Repository**: Fork or clone this repository

## Quick Deployment Steps

### 1. Setup Telegram Bot

```bash
# Message @BotFather on Telegram
/newbot
# Follow instructions to create your bot
# Save the bot token (format: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz)
```

### 2. Get Channel ID

Method 1 - Using @userinfobot:
1. Add [@userinfobot](https://t.me/userinfobot) to your channel
2. Send any message to the channel
3. The bot will reply with channel information including ID

Method 2 - Using API:
1. Send a message to your channel
2. Visit: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
3. Find your channel ID in the JSON response

### 3. Configure GitHub Secrets

Go to your repository → Settings → Secrets and variables → Actions

Add these repository secrets:

| Secret Name | Value | Required |
|-------------|-------|----------|
| `TELEGRAM_BOT_TOKEN` | Your bot token from BotFather | ✅ |
| `TELEGRAM_CHANNEL_ID` | Your channel ID (e.g., `@mychannel` or `-1001234567890`) | ✅ |
| `TELEGRAM_ADMIN_IDS` | Comma-separated admin user IDs for error notifications | ❌ |

### 4. Enable GitHub Actions

1. Go to your repository → Actions tab
2. If prompted, click "I understand my workflows, go ahead and enable them"
3. The workflow will start running automatically every 30 minutes

### 5. Test the Setup

#### Manual Test:
1. Go to Actions tab → Windsurf Release Monitor workflow
2. Click "Run workflow" → Check "Run in test mode" → Run workflow
3. Check the workflow logs for any errors

#### Local Test:
```bash
cd windsurf-release-monitor
npm install
npm run setup  # Interactive setup wizard
npm test       # Run test suite
```

## Configuration Options

### Environment Variables

The bot can be configured using environment variables:

```bash
# Required
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHANNEL_ID=your_channel_id

# Optional
TELEGRAM_ADMIN_IDS=123456789,987654321
CHECK_INTERVAL_MINUTES=30
LOG_LEVEL=info
NODE_ENV=production
MAX_RETRIES=3
REQUEST_TIMEOUT_MS=30000
```

### GitHub Actions Schedule

The default schedule runs every 30 minutes. To change this, edit `.github/workflows/windsurf-monitor.yml`:

```yaml
on:
  schedule:
    # Run every hour instead
    - cron: '0 * * * *'
```

Common cron expressions:
- Every 15 minutes: `*/15 * * * *`
- Every hour: `0 * * * *`
- Every 6 hours: `0 */6 * * *`
- Daily at midnight: `0 0 * * *`

## Monitoring and Maintenance

### Check Workflow Status

1. Go to Actions tab in your repository
2. Look for green checkmarks (success) or red X's (failure)
3. Click on any workflow run to see detailed logs

### View Logs

Logs are automatically uploaded as artifacts:
1. Go to a workflow run
2. Scroll down to "Artifacts" section
3. Download "windsurf-monitor-logs" to view detailed logs

### Error Notifications

If you configured `TELEGRAM_ADMIN_IDS`, you'll receive error notifications via Telegram when:
- Scraping fails
- Telegram API errors occur
- Critical system errors happen

### Data Persistence

The bot uses GitHub Actions cache to persist data between runs:
- Release history is stored in `data/versions.json`
- Cache is automatically managed by GitHub Actions
- Data survives workflow runs and repository updates

## Troubleshooting

### Common Issues

#### Bot Not Posting Messages
- **Check**: Bot is administrator in the channel
- **Check**: Channel ID is correct (including @ or - prefix)
- **Check**: Bot token is valid and not expired

#### No Releases Detected
- **Check**: Windsurf website is accessible
- **Check**: Workflow logs for scraping errors
- **Try**: Run test mode to verify scraping works

#### GitHub Action Failing
- **Check**: All required secrets are set
- **Check**: Secrets don't have extra spaces or characters
- **Check**: Repository has Actions enabled

#### Rate Limiting
- **Solution**: Increase `REQUEST_DELAY_MS` in configuration
- **Solution**: Reduce check frequency in cron schedule

### Debug Mode

Enable debug logging by adding this secret:
- `LOG_LEVEL`: `debug`

This will provide detailed logs for troubleshooting.

### Manual Workflow Trigger

You can manually trigger the workflow:
1. Go to Actions → Windsurf Release Monitor
2. Click "Run workflow"
3. Choose test mode for testing or leave unchecked for normal run

## Security Considerations

### Secrets Management
- Never commit bot tokens or secrets to the repository
- Use GitHub Secrets for all sensitive configuration
- Regularly rotate bot tokens if compromised

### Bot Permissions
- Give the bot only necessary permissions in your channel
- Consider using a dedicated channel for release notifications
- Monitor bot activity through Telegram's bot management

### Network Security
- The bot only makes HTTPS requests to trusted domains
- No sensitive data is logged or transmitted
- All external requests have timeouts and retry limits

## Customization

### Message Format
Edit `src/telegram.js` → `formatReleaseMessage()` to customize notification format.

### Monitoring Sources
Edit `src/config.js` to add or modify URLs being monitored.

### Check Logic
Edit `src/scraper.js` to modify how releases are detected and parsed.

## Support

### Getting Help
1. Check this documentation first
2. Review workflow logs for specific errors
3. Test locally using `npm test`
4. Create an issue in the repository with:
   - Error messages from logs
   - Configuration details (without secrets)
   - Steps to reproduce the problem

### Contributing
1. Fork the repository
2. Create a feature branch
3. Test your changes locally
4. Submit a pull request with detailed description

---

**Note**: This deployment guide assumes you're using the provided GitHub Actions workflow. For other CI/CD systems, adapt the environment variable setup and scheduling accordingly.
