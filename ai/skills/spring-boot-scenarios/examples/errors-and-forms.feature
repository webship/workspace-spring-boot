Feature: Error pages, health and forms
  # On the PetClinic sample built with --petclinic --install --add-users. The browser logs every error page it gets.

  @js-off
  Scenario: A page that fails shows the app's own error page, with no debug information
    Given I am not logged in
    When I go to "/oups"
    Then I should see the 500 error page
    And I should not see the default error page
    And the page should not show debug information

  Scenario: Anybody sees whether the app is up; the ADMIN role sees its parts
    Given I am not logged in
    Then the health endpoint should report "UP"
    And the health endpoint should show no components
    When I log in as "administrator" with the login form
    Then the health endpoint should show the component "db"

  Scenario: A refused owner form says what is wrong with each field
    Given I am a logged in user with the "administrator" user
    When I go to "/owners/1/edit"
    And I fill in "First Name" with ""
    And I fill in "Telephone" with "12ab"
    And I press "Update Owner"
    Then the form should show the errors:
      | First Name | must not be blank                   |
      | Telephone  | Telephone must be a 10-digit number |
