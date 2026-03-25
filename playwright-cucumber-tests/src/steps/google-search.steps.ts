import { Given, When, Then } from '@cucumber/cucumber';
import { expect } from '@playwright/test';
import { CustomWorld } from '../support/world';

Given('I open Chrome browser', async function (this: CustomWorld) {
  await this.launchBrowser();
});

Given('I navigate to {string}', async function (this: CustomWorld, url: string) {
  await this.page!.goto(url, { waitUntil: 'domcontentloaded' });
});

When('I enter {string} in the search box', async function (this: CustomWorld, searchText: string) {
  // Google search box can be identified by name="q" or aria-label="Search"
  const searchBox = this.page!.locator('textarea[name="q"], input[name="q"]');
  await searchBox.first().waitFor({ state: 'visible', timeout: 10000 });
  await searchBox.first().fill(searchText);
});

When('I click the search button', async function (this: CustomWorld) {
  // Press Enter to submit the search form
  await this.page!.keyboard.press('Enter');
  // Wait for the search results page to load
  await this.page!.waitForLoadState('domcontentloaded');
  // Wait for search results to appear
  await this.page!.waitForSelector('#search, #rso', { timeout: 15000 });
});

Then('I should see search results', async function (this: CustomWorld) {
  const searchResults = this.page!.locator('#search, #rso');
  await expect(searchResults.first()).toBeVisible({ timeout: 10000 });
});

Then('the search results should contain {string}', async function (this: CustomWorld, expectedText: string) {
  const bodyText = await this.page!.locator('body').innerText();
  expect(bodyText.toLowerCase()).toContain(expectedText.toLowerCase());
});
