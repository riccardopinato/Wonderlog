// Executes against the already-compiled Web output on a local /Wonderlog/
// mount, not against the Flutter development server. Do not use real accounts.
const { chromium } = require('playwright-core');

(async () => {
  const browser = await chromium.launch({
    channel: 'chrome',
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });
  const errors = [];
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
    page.on('pageerror', (error) => errors.push(error.message));
    const url = 'http://127.0.0.1:8765/Wonderlog/';
    const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    if (!response || response.status() !== 200) {
      throw Error('App entrypoint HTTP failure: ' + (response?.status() ?? 'null'));
    }
    // The Flutter view is attached only after main() finishes its awaited
    // profile, identity, premium and cloud initialization.
    await page.locator('flutter-view').first().waitFor({
      state: 'attached',
      timeout: 30000,
    });
    await page.waitForTimeout(2000);
    if (errors.length > 0) {
      throw Error('Uncaught browser startup errors: ' + errors.join(' | '));
    }
    // Worker/wasm network responses are also checked in the release validator.
    console.log('Wonderlog Web browser startup: PASS (/Wonderlog/ base path)');
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error('Wonderlog Web browser startup: FAIL: ' + error.message);
  process.exitCode = 1;
});
