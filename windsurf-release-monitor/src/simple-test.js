#!/usr/bin/env node

// Simple test script to diagnose GitHub Actions issues
console.log('=== Simple Test Script ===');
console.log('Node version:', process.version);
console.log('Current directory:', process.cwd());
console.log('Environment variables:');
console.log('- TELEGRAM_BOT_TOKEN exists:', !!process.env.TELEGRAM_BOT_TOKEN);
console.log('- TELEGRAM_BOT_TOKEN length:', process.env.TELEGRAM_BOT_TOKEN ? process.env.TELEGRAM_BOT_TOKEN.length : 0);
console.log('- TELEGRAM_CHANNEL_ID:', process.env.TELEGRAM_CHANNEL_ID || 'NOT SET');
console.log('- NODE_ENV:', process.env.NODE_ENV);
console.log('- LOG_LEVEL:', process.env.LOG_LEVEL);

// Test if we can require modules
try {
  console.log('\nTesting module loading...');
  const config = require('./config');
  console.log('Config module loaded successfully');
  console.log('Bot token from config:', config.config.telegram.botToken ? 'SET' : 'NOT SET');
  console.log('Channel ID from config:', config.config.telegram.channelId || 'NOT SET');
} catch (error) {
  console.error('Error loading config:', error.message);
  process.exit(1);
}

console.log('\n=== Test completed successfully ===');
process.exit(0);
