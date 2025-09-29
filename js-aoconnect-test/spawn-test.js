#!/usr/bin/env node

// Pure JS test that mirrors AOS CLI behaviour for spawning processes
const fs = require('fs');
const path = require('path');

// Bootstrapping configuration – mimic AOS CLI startup
console.log('🔧 Enabling undici ProxyAgent (same as AOS proxy handling)');

// Set proxy environment variables (same values AOS relies on)
process.env.HTTPS_PROXY = 'http://127.0.0.1:1235';
process.env.HTTP_PROXY = 'http://127.0.0.1:1235';
process.env.ALL_PROXY = 'http://127.0.0.1:1235';

// Default endpoints used by AOS when connecting in legacy mode
process.env.GATEWAY_URL = 'https://arweave.net';
process.env.CU_URL = 'https://cu.ao-testnet.xyz';
process.env.MU_URL = 'https://mu.ao-testnet.xyz'; // Back to original MU_URL
process.env.SCHEDULER = '_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA';

// Additional flags that AOS sets implicitly
process.env.ARWEAVE_GRAPHQL = 'https://arweave.net/graphql';
process.env.AO_URL = 'https://arweave.net'; // Set AO_URL even for legacy mode
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0'; // AOS might use this for proxy
process.env.AUTHORITY = 'fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY'; // AOS sets this in mainnet

// Global prompt/alerts used by AOS REPL – harmless but keeps parity
globalThis.alerts = {};
globalThis.prompt = 'aos> ';

// Set additional AOS environment variables
process.env.DEBUG = 'false';
process.env.NODE_ENV = 'development';
process.env.TZ = 'UTC';

try {
  const { ProxyAgent } = require('undici');
  if (process.env.HTTPS_PROXY) {
    const proxyAgent = new ProxyAgent(process.env.HTTPS_PROXY);
    const originalFetch = globalThis.fetch;
    globalThis.fetch = function (url, options = {}) {
      const finalOptions = { ...options, dispatcher: proxyAgent };
      return originalFetch(url, finalOptions);
    };
    console.log('🔧 ProxyAgent enabled: all fetch requests go through', process.env.HTTPS_PROXY);
  }
} catch (proxyError) {
  console.warn('⚠️ Failed to enable undici ProxyAgent:', proxyError.message);
}

// Import aoconnect AFTER environment variables and proxy override are set
const { connect, createDataItemSigner } = require('@permaweb/aoconnect');

console.log('🔧 Environment variables set:');
console.log('   GATEWAY_URL:', process.env.GATEWAY_URL);
console.log('   CU_URL:', process.env.CU_URL);
console.log('   MU_URL:', process.env.MU_URL);
console.log('   SCHEDULER:', process.env.SCHEDULER);

// AOS module IDs from package.json
const LEGACY_MODULE_ID = 'ISShJH1ij-hPPt9St5UFFr_8Ys3Kj5cyg7zrMGt7H9s';
const HYPER_MODULE_ID = 'wal-fUK-YnB9Kp5mN8dgMsSqPSqiGx-0SvwFUSwpDBI';

// Choose which module to test
const USE_HYPER_MODULE = process.argv.includes('--hyper');
const MODULE_ID = USE_HYPER_MODULE ? HYPER_MODULE_ID : LEGACY_MODULE_ID;

// Load wallet (use the EXACT same wallet as successful AOS)
async function loadWallet() {
  // Use AOS's wallet that successfully spawned a process
  const walletPath = path.join(require('os').homedir(), '.aos.json');

  if (!fs.existsSync(walletPath)) {
    throw new Error('AOS wallet not found. Please run AOS first to create a wallet.');
  }

  console.log('🔑 Loading AOS wallet that successfully spawned processes...');
  const walletData = fs.readFileSync(walletPath, 'utf8');
  return JSON.parse(walletData);
}

// Same helper as AOS services/connect
function getInfo() {
  return {
    MODE: 'legacy', // Back to legacy mode
    GATEWAY_URL: process.env.GATEWAY_URL,
    CU_URL: process.env.CU_URL,
    MU_URL: process.env.MU_URL
  };
}

// Spawn process function - EXACTLY LIKE AOS spawnProcess
async function spawnProcess({ wallet, src, tags, data }) {
  console.log('🚀 EXACTLY LIKE AOS spawnProcess with hyper-async...');

  // EXACT copy of AOS spawnProcess
  const SCHEDULER = process.env.SCHEDULER || "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA";
  const signer = createDataItemSigner(wallet);

  tags = tags.concat([{ name: 'aos-Version', value: '2.0.7' }]);

  // EXACT copy: return fromPromise(() => connect(getInfo()).spawn({...}).then(...))()
  // But convert to regular Promise for easier handling
  return connect(getInfo()).spawn({
    module: src, scheduler: SCHEDULER, signer, tags, data
  })
  .then(result => new Promise((resolve) => setTimeout(() => resolve(result), 500)));
}

// Send message to the freshly spawned process (AOS-style)
async function sendMessageToProcess({ wallet, processId, action = 'Echo', data = 'Hello from JS aoconnect test!' }) {
  console.log('\n📨 Sending message to freshly spawned process...');

  const signer = createDataItemSigner(wallet);

  const messageResult = await connect(getInfo()).message({
    process: processId,
    signer,
    tags: [
      { name: 'Action', value: action }
    ],
    data
  });

  console.log('✅ Message dispatched!');
  console.log('   Target Process:', processId);
  console.log('   Action:', action);
  console.log('   Data:', data);
  console.log('   Message Result:', messageResult);

  return messageResult;
}

// Main test function
async function testSpawnProcess() {
  console.log('🚀 Starting pure JS aoconnect test...');
  console.log('🌐 AO Network Configuration:');
  console.log('   Gateway:', process.env.GATEWAY_URL);
  console.log('   CU:', process.env.CU_URL);
  console.log('   MU:', process.env.MU_URL);
  console.log('   Scheduler:', process.env.SCHEDULER);
  console.log('   Module:', MODULE_ID, USE_HYPER_MODULE ? '(HYPER)' : '(LEGACY)');

  try {
    // Phase 1: Spawn new AO process
    console.log('\n🚀 Phase 1: Spawning new AO process...');

    const wallet = await loadWallet();
    console.log('✅ Wallet loaded, address:', wallet.n.substring(0, 20) + '...');

    // Generate unique process name (same as AOS)
    const processName = `js-test-${Date.now()}`;

    // Prepare spawn parameters (EXACTLY same as AOS register function)
    let appName = "aos"
    if (process.env.AO_URL !== "undefined") {
      appName = "hyper-aos"  // AOS sets this when AO_URL is set
    }

    const spawnParams = {
      wallet: wallet,
      src: MODULE_ID,
      tags: [
        { name: 'App-Name', value: appName }, // Use correct appName based on AO_URL
        { name: 'Name', value: processName },
        { name: 'Authority', value: 'fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY' }
      ]
      // NOTE: AOS doesn't explicitly pass data parameter
    };

    console.log('\n📋 Spawn Parameters:');
    console.log('   Module:', spawnParams.src);
    console.log('   Process Name:', processName);
    console.log('   Tags:', spawnParams.tags.length);

    // First test network connectivity
    console.log('\n🔍 Testing network connectivity before spawn...');

    // Test CU
    try {
      const cuResponse = await global.fetch(`${process.env.CU_URL}/health-check`, {
        method: 'GET',
        timeout: 5000
      });
      console.log('✅ CU service is accessible');
    } catch (cuError) {
      console.log('⚠️  CU service test failed:', cuError.message);
    }

    // Test MU (spawn uses MU, not CU)
    try {
      const muResponse = await global.fetch(`${process.env.MU_URL}/health-check`, {
        method: 'GET',
        timeout: 5000
      });
      console.log('✅ MU service is accessible');
    } catch (muError) {
      console.log('⚠️  MU service test failed:', muError.message);
      console.log('🔍 MU is used for spawning processes - this might be the issue!');
    }

    // Try to spawn process
    console.log('\n⚙️ Attempting to spawn AO process...');
    console.log('ℹ️  Legacy network should NOT require AO tokens for spawning processes');

    let processId;
    try {
      processId = await spawnProcess(spawnParams);

      console.log('\n🎉 SUCCESS! AO Process spawned with AOS-style hyper-async!');
      console.log('📋 Process ID:', processId);
      console.log('   Type:', typeof processId);
      console.log('   Length:', processId ? processId.length : 'unknown');
      console.log('   Format check:', processId && processId.length === 43 && /^[A-Za-z0-9_-]+$/.test(processId) ? '✅ Valid AOS format' : '❌ Invalid format');

      if (!(processId && processId.length === 43 && /^[A-Za-z0-9_-]+$/.test(processId))) {
        console.log('\n❌ SPAWN TEST FAILED: Invalid process ID format');
        console.log('Expected: 43-character Arweave transaction ID');
        console.log('Got:', processId);
        throw new Error('Invalid process ID format');
      }
    } catch (spawnError) {
      console.log('\n❌ SPAWN TEST FAILED:', spawnError.message);
      console.log('🔍 Full error details:', JSON.stringify(spawnError, null, 2));
      console.log('🔍 Error stack:', spawnError.stack);
      throw spawnError;
    }

    // Phase 2: send message to the newly spawned process
    console.log('\n📨 Phase 2: Sending message to the new process...');
    const messageResult = await sendMessageToProcess({
      wallet,
      processId,
      action: 'Echo',
      data: 'Hello from freshly spawned process!'
    });
    console.log('📝 Message ID:', messageResult);

    // Overall test result
    console.log('\n🎯 TEST SUMMARY:');
    console.log('✅ Process spawning: WORKS (real AO process spawned via aoconnect)');
    console.log('✅ Message sending: WORKS (message delivered to newly spawned process)');
    console.log('🎉 RESULT: Pure JS aoconnect test fully succeeds!');

  } catch (error) {
    console.error('\n❌ TEST FAILED');
    console.error('Error message:', error.message);
    console.error('Error stack:', error.stack);
    process.exit(1);
  }
}

// Run the test
testSpawnProcess().catch(error => {
  console.error('❌ Unhandled error:', error);
  process.exit(1);
});