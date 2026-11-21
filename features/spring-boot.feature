Feature: The Spring Boot plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the Spring Boot builder, each
  AI folder lists the items of its kind the plugin ships, and the Plugins page lists the plugin
  with its steps.

  # Settings lists every plugin that was added; the package and what the plugin ships are on its own page.
  Scenario: Settings lists the plugin, and its own page names its package and what it ships
    Given I am on "/settings"
     Then I should see "Spring Boot"
     When I go to "/settings/plugin/spring-boot"
     Then I should see "@webship.co/workspace-spring-boot"
      And I should see "cmd-spring-boot-project.sh"
      And I should see "spring-boot-site-builder"

  Scenario: A sites folder offers the Spring Boot builder
    Given I am on "/dev"
     Then "option[value='cmd-spring-boot-project.sh']" should be attached

  # The AI folders are searched by name: with every plugin on, a folder lists more than one page of items.
  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents?q=spring-boot-"
     Then I should see "spring-boot-site-builder"
      And I should see "spring-boot-tester"

  Scenario: The AI Skills folder lists the skill the plugin ships
    Given I am on "/ai-skills?q=spring-boot-scenarios"
     Then I should see "spring-boot-scenarios"

  Scenario: The AI Commands folder lists the command the plugin ships
    Given I am on "/ai-commands?q=spring-boot-test"
     Then I should see "spring-boot-test"

  Scenario: The AI Prompts folder lists the prompts the plugin ships
    Given I am on "/ai-prompts?q=spring-boot-"
     Then I should see "spring-boot-build-and-test"
      And I should see "spring-boot-scenarios-for-an-area"
