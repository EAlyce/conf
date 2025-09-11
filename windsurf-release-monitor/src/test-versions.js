#!/usr/bin/env node

const https = require('https');

// 直接检测Windsurf下载链接的版本
async function checkVersion(url, type) {
  return new Promise((resolve) => {
    console.log(`\nChecking ${type} version...`);
    console.log(`URL: ${url}`);
    
    https.get(url, { method: 'HEAD', timeout: 10000 }, (res) => {
      if (res.statusCode === 200 || res.statusCode === 302) {
        // 从URL中提取版本号
        const versionMatch = url.match(/(\d+\.\d+\.\d+(?:\+next\.[a-f0-9]+)?)/);
        const version = versionMatch ? versionMatch[1] : 'Unknown';
        
        console.log(`✅ ${type} version available: ${version}`);
        console.log(`   Status: ${res.statusCode}`);
        console.log(`   Content-Length: ${res.headers['content-length'] || 'N/A'}`);
        
        resolve({
          type,
          version,
          url,
          available: true,
          statusCode: res.statusCode
        });
      } else {
        console.log(`❌ ${type} version not available`);
        console.log(`   Status: ${res.statusCode}`);
        resolve({
          type,
          version: null,
          url,
          available: false,
          statusCode: res.statusCode
        });
      }
    }).on('error', (err) => {
      console.error(`❌ Error checking ${type}: ${err.message}`);
      resolve({
        type,
        version: null,
        url,
        available: false,
        error: err.message
      });
    });
  });
}

async function testVersions() {
  console.log('=== Testing Windsurf Version Detection ===');
  
  const versions = [
    // Stable versions
    {
      url: 'https://windsurf-stable.codeiumdata.com/win32-x64-user/stable/64804081c3f9a1652d6d325c28c01c3f5882f6fb/WindsurfUserSetup-x64-1.12.5.exe',
      type: 'Stable 1.12.5'
    },
    {
      url: 'https://windsurf-stable.codeiumdata.com/win32-x64-user/stable/f1e16e1e6214d7c44d078b1f0607b2388f29d729/WindsurfUserSetup-x64-1.12.4.exe',
      type: 'Stable 1.12.4'
    },
    {
      url: 'https://windsurf-stable.codeiumdata.com/win32-x64-user/stable/89c3fc3d3887c996e3f06eb2dd3c4850b2c9897c/WindsurfUserSetup-x64-1.12.3.exe',
      type: 'Stable 1.12.3'
    },
    // Next versions
    {
      url: 'https://windsurf-stable.codeiumdata.com/win32-x64-user/next/64804081c3f9a1652d6d325c28c01c3f5882f6fb/WindsurfUserSetup-x64-1.12.110+next.64804081c3.exe',
      type: 'Next 1.12.110'
    }
  ];
  
  const results = [];
  for (const version of versions) {
    const result = await checkVersion(version.url, version.type);
    results.push(result);
  }
  
  console.log('\n=== Summary ===');
  const available = results.filter(r => r.available);
  const unavailable = results.filter(r => !r.available);
  
  console.log(`✅ Available versions: ${available.length}`);
  available.forEach(r => console.log(`   - ${r.type}: ${r.version}`));
  
  if (unavailable.length > 0) {
    console.log(`❌ Unavailable versions: ${unavailable.length}`);
    unavailable.forEach(r => console.log(`   - ${r.type}`));
  }
  
  console.log('\n=== Test Complete ===');
  process.exit(available.length > 0 ? 0 : 1);
}

testVersions().catch(console.error);
