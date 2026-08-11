import { mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { chromium } from 'playwright';

const root = dirname(fileURLToPath(import.meta.url));
const source = resolve(root, 'index.html');
const output = resolve(root, 'output', 'pdf', 'St-John-Presentation-Print.pdf');

await mkdir(dirname(output), { recursive: true });

const browser = await chromium.launch({ channel: 'chrome', headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  await page.goto(pathToFileURL(source).href, { waitUntil: 'load', timeout: 120_000 });
  await page.emulateMedia({ media: 'print' });
  await page.evaluate(() => document.fonts.ready);
  await page.evaluate(() => {
    window.dispatchEvent(new Event('resize'));
    if (typeof window.layoutMapMarkers === 'function') window.layoutMapMarkers();
  });
  await page.waitForTimeout(100);
  await page.pdf({
    path: output,
    printBackground: true,
    preferCSSPageSize: true,
    tagged: true,
  });
  console.log(`Wrote: ${output}`);
} finally {
  await browser.close();
}
