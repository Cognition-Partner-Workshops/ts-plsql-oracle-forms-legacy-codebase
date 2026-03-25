import { World, setWorldConstructor, Before, After, setDefaultTimeout } from '@cucumber/cucumber';
import { chromium, Browser, Page, BrowserContext } from 'playwright';

// Set default timeout to 30 seconds
setDefaultTimeout(30000);

export class CustomWorld extends World {
  browser: Browser | null = null;
  context: BrowserContext | null = null;
  page: Page | null = null;

  async launchBrowser(): Promise<void> {
    const isHeaded = process.env.HEADED === 'true';

    this.browser = await chromium.launch({
      headless: !isHeaded,
      channel: 'chromium',
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu'
      ]
    });

    this.context = await this.browser.newContext({
      viewport: { width: 1280, height: 720 },
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    });

    this.page = await this.context.newPage();
  }

  async closeBrowser(): Promise<void> {
    if (this.page) {
      await this.page.close();
      this.page = null;
    }
    if (this.context) {
      await this.context.close();
      this.context = null;
    }
    if (this.browser) {
      await this.browser.close();
      this.browser = null;
    }
  }
}

setWorldConstructor(CustomWorld);

Before(async function (this: CustomWorld) {
  // Browser will be launched in the step definition
});

After(async function (this: CustomWorld) {
  await this.closeBrowser();
});
