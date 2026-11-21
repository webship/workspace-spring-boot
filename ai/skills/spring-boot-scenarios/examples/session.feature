Feature: Logging in and out
  # On the PetClinic sample built with --petclinic --install --add-users.

  Scenario: A visitor is sent to the login page, and back to the page after the login
    Given I am not logged in
    When I go to "/owners/find"
    Then I should be on the login page
    When I log in as "user" with the login form
    Then I should be back on the page I asked for
    And I should be logged in as "user"
    And the login should have started a new session

  Scenario: A wrong password and an unknown account are refused with the same words
    Given I am on the login page
    When I log in with the username "user" and the password "Wrong-password-1"
    Then the login should be refused with "Invalid credentials"
    When I log in with the username "no-such-account" and the password "Wrong-password-1"
    Then the login should be refused with "Invalid credentials"
    And I should not be logged in

  Scenario: The logout button of the page ends the session
    Given I am a logged in user with the "user" user
    When I go to "/owners/find"
    And I log out
    Then I should be on the login page
    And I should see the success message "You have been signed out"
    And I should not be logged in

  # The logout page names no icon: the browser asks for /favicon.ico, a 404 for a signed-in account.
  @js-off
  Scenario: The logout page asks first
    Given I am a logged in user with the "administrator" user
    When I go to the logout page
    Then I should be asked to confirm the logout
    When I confirm the logout
    Then I should not be logged in
