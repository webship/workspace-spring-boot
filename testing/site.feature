Feature: The app answers, its login works and its accounts log in
  As the owner of the app
  I want the login, each default account and the health endpoint to work
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-spring-boot-cli.sh --add-users); a scenario logs in by a handle of the
  # users registry in cucumber.js, so no password is written here. It passes on an app built with
  # --install --add-users, a new one or the PetClinic sample. A new app has no page of its own yet: every page a
  # signed-in account opens there is the framework's default error page (404), which the browser logs, so the
  # scenarios that log in carry @js-off.

  @critical
  Scenario: A visitor who opens a page that needs a session is sent to the login page
    Given I am not logged in
    When I go to "/owners/find"
    Then I should be on the login page
    And I should see the login form

  @js-off
  Scenario Outline: The <account> account logs in through the login form
    Given I am not logged in
    When I log in as "<account>" with the login form
    Then I should be logged in
    And the login should have started a new session

    Examples:
      | account       |
      | administrator |
      | user          |

  Scenario: A wrong password is refused
    Given I am on the login page
    When I log in with the username "user" and the password "Wrong-password-1"
    Then the login should be refused with "Invalid credentials"
    And I should not be logged in

  @js-off
  Scenario: Anybody sees whether the app is up, and only the ADMIN role sees its parts
    Given I am not logged in
    Then the health endpoint should report "UP"
    And the health endpoint should show no components
    When I log in as "administrator" with the login form
    Then the health endpoint should show the component "db"
