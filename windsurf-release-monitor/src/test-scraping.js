#!/usr/bin/env node

const axios = require('axios');
const cheerio = require('cheerio');

// Test scraping Windsurf releases
async function testScraping() {
  console.log('=== Testing Windsurf Scraping ===\n');
  
  // Test 1: Check network connectivity
  console.log('1. Testing network connectivity...');
  try {
    const response = await axios.get('https://www.google.com', { timeout: 5000 });
    console.log('✅ Network connectivity OK\n');
  } catch (error) {
    console.error('❌ Network connectivity failed:', error.message);
    return;
  }
  
  // Test 2: Scrape stable releases
  console.log('2. Testing Windsurf stable releases page...');
  const stableUrl = 'https://windsurf.com/editor/releases';
  
  try {
    console.log(`   URL: ${stableUrl}`);
    const response = await axios.get(stableUrl, {
      timeout: 10000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      }
    });
    
    console.log(`   Status: ${response.status}`);
    console.log(`   Content-Type: ${response.headers['content-type']}`);
    console.log(`   Content Length: ${response.data.length} bytes`);
    
    const $ = cheerio.load(response.data);
    
    // Try to find version elements
    const versions = [];
    
    // Common selectors for version info
    const selectors = [
      'h2', 'h3', 'h4',
      '.version', '.release-version',
      '[class*="version"]', '[id*="version"]',
      'a[href*="download"]'
    ];
    
    console.log('\n   Searching for version information...');
    for (const selector of selectors) {
      const elements = $(selector);
      if (elements.length > 0) {
        console.log(`   Found ${elements.length} elements with selector: ${selector}`);
        elements.slice(0, 3).each((i, el) => {
          const text = $(el).text().trim().substring(0, 50);
          if (text) console.log(`     - ${text}`);
        });
      }
    }
    
    // Look for specific version patterns
    const versionPattern = /\d+\.\d+\.\d+/g;
    const pageText = $('body').text();
    const foundVersions = pageText.match(versionPattern);
    
    if (foundVersions) {
      console.log(`\n   Found version numbers: ${foundVersions.slice(0, 5).join(', ')}`);
    }
    
    console.log('\n✅ Stable releases page accessible\n');
    
  } catch (error) {
    console.error(`❌ Failed to scrape stable releases: ${error.message}`);
    if (error.response) {
      console.error(`   Response status: ${error.response.status}`);
      console.error(`   Response text: ${error.response.data?.substring(0, 200)}`);
    }
  }
  
  // Test 3: Scrape Next releases
  console.log('3. Testing Windsurf Next releases page...');
  const nextUrl = 'https://windsurf.com/changelog/windsurf-next';
  
  try {
    console.log(`   URL: ${nextUrl}`);
    const response = await axios.get(nextUrl, {
      timeout: 10000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      }
    });
    
    console.log(`   Status: ${response.status}`);
    console.log(`   Content Length: ${response.data.length} bytes`);
    
    const $ = cheerio.load(response.data);
    
    // Look for version info
    const pageText = $('body').text();
    const versionPattern = /\d+\.\d+\.\d+/g;
    const foundVersions = pageText.match(versionPattern);
    
    if (foundVersions) {
      console.log(`   Found version numbers: ${foundVersions.slice(0, 5).join(', ')}`);
    }
    
    console.log('\n✅ Next releases page accessible\n');
    
  } catch (error) {
    console.error(`❌ Failed to scrape Next releases: ${error.message}`);
    if (error.response) {
      console.error(`   Response status: ${error.response.status}`);
    }
  }
  
  console.log('=== Scraping Test Complete ===');
}

// Run the test
testScraping().catch(console.error);
