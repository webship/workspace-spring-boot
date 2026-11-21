Feature: Remember-me and who may open what
  # On the PetClinic sample built with --petclinic --install --add-users.

  Scenario: With remember-me ticked, a browser closed and opened again is still signed in
    Given I am not logged in
    When I log in as "user" with the login form and "Remember me on this computer." checked
    Then the remember-me cookie should last 14 days
    When I close the browser and open it again
    Then I should be logged in as "user"

  Scenario: A session that ended sends the browser to the login page
    Given I am a logged in user with the "user" user
    When my session expires
    Then I should not be logged in

  @js-off
  Scenario: The USER role finds owners, but may not add or edit one
    Given I am a logged in user with the "user" user
    Then I should be allowed to open "/owners/find"
    And I should not be allowed to open "/owners/new"
    And I should not be allowed to open "/owners/1/edit"

  Scenario: The ADMIN role adds and edits owners
    Given I am a logged in user with the "administrator" user
    Then I should be allowed to open "/owners/new"
    And I should be allowed to open "/owners/1/edit"
