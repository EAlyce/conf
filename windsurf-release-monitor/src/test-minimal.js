#!/usr/bin/env node

// 最小化测试脚本 - 只测试环境变量
console.log('=== Minimal Test ===');
console.log('1. Process started successfully');
console.log('2. Node version:', process.version);
console.log('3. Environment variables check:');
console.log('   TELEGRAM_BOT_TOKEN:', process.env.TELEGRAM_BOT_TOKEN ? `Set (${process.env.TELEGRAM_BOT_TOKEN.length} chars)` : 'NOT SET');
console.log('   TELEGRAM_CHANNEL_ID:', process.env.TELEGRAM_CHANNEL_ID || 'NOT SET');
console.log('4. Test completed');
process.exit(0);
