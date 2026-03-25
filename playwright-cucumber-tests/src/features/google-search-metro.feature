Feature: Google Search for Metro in Hyderabad
  As a user
  I want to search for Metro in Hyderabad on Google
  So that I can find information about the Hyderabad Metro Rail

  Scenario: Search for Metro in Hyderabad using Google Chrome
    Given I open Chrome browser
    And I navigate to "https://google.com"
    When I enter "Metro in Hyderabad" in the search box
    And I click the search button
    Then I should see search results
    And the search results should contain "Hyderabad"
