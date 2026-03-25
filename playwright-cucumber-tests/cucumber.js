module.exports = {
  default: {
    requireModule: ['ts-node/register'],
    require: ['src/steps/**/*.ts', 'src/support/**/*.ts'],
    paths: ['src/features/**/*.feature'],
    format: [
      'progress-bar',
      'html:reports/cucumber-report.html',
      'json:reports/cucumber-report.json'
    ],
    formatOptions: {
      snippetInterface: 'async-await'
    },
    publishQuiet: true
  }
};
