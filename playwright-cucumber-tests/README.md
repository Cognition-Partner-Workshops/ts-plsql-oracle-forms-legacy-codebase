# Playwright + Cucumber BDD Tests - Metro in Hyderabad

Automated browser tests using **Playwright** with **Cucumber BDD** framework to search for "Metro in Hyderabad" on Google Chrome.

## Project Structure

```
playwright-cucumber-tests/
├── src/
│   ├── features/           # Cucumber feature files (Gherkin)
│   │   └── google-search-metro.feature
│   ├── steps/              # Step definitions (TypeScript)
│   │   └── google-search.steps.ts
│   └── support/            # Support files (World, hooks)
│       └── world.ts
├── cucumber.js             # Cucumber configuration
├── package.json            # Dependencies
├── tsconfig.json           # TypeScript config
└── README.md
```

## Prerequisites

- Node.js >= 18
- npm or yarn

## Setup

```bash
cd playwright-cucumber-tests
npm install
npx playwright install chromium
```

## Running Tests

### Headless mode (default)
```bash
npm test
```

### Headed mode (visible browser)
```bash
npm run test:headed
```

## Test Scenario

The test performs the following steps:
1. Opens a Chromium browser instance
2. Navigates to https://google.com
3. Enters "Metro in Hyderabad" in the search box
4. Clicks the search button (presses Enter)
5. Verifies that search results are displayed
6. Verifies that results contain "Hyderabad"

## Reports

After running tests, reports are generated in the `reports/` directory:
- `cucumber-report.html` - HTML report
- `cucumber-report.json` - JSON report

## Tech Stack

- **Playwright** - Browser automation
- **Cucumber.js** - BDD test framework
- **TypeScript** - Type-safe step definitions
- **Chromium** - Browser engine (Google Chrome compatible)
