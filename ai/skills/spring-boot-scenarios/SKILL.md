---
name: spring-boot-scenarios
description: Write webship-js scenarios for a Spring Boot app of the Webship Workspace from phrases that exist — the Spring Boot step pack's steps by area (the generated login and logout pages, remember-me and a session that ended, who may open what, the CSRF protection, the app's own and the default error pages, the health endpoint, the validation and flash messages of server-rendered forms), the handles of the users registry, the traps found on a real app, and three features that pass on the PetClinic sample built with the default accounts. Use when writing or fixing a scenario for a Spring Boot app, choosing a step for one of its pages, or turning a manual check of the login, an error page or a form into a feature.
---

# spring-boot-scenarios

Scenarios for an app built with the Spring Boot plugin (`bash cmd-spring-boot-project.sh <app> --petclinic --install
--add-users`, or a new app without `--petclinic`) in a container-based workspace (DDEV by default), tested with
webship-js and `@webship-js/spring-boot-steps` once `bash cmd-tools-testing.sh <app>` set the project up. Every phrase
below exists in the pack or in webship-js; a scenario names no platform.

## Accounts

- `Given I am a logged in user with the "user" user`: `administrator` (the ADMIN role: adds and edits owners and pets
  of the sample, the management endpoints, the health details) and `user` (the USER role: finds owners, adds visits).
  `Given I am not logged in` for a visitor.
- The accounts are in-memory accounts of the app (`cmd-tools-spring-boot-cli.sh <app> --add-users`); a suite never
  creates or deletes one, and never writes a password: it logs in by the handle.

## Phrases by area

| Area | Steps |
| --- | --- |
| Session | `I am on the login page`, `I go to the login page`, `I log in as "user" with the login form` (`… and "Remember me on this computer." checked`), `I log in with the username "…" and the password "…"`, `the login should be refused with "Invalid credentials"`, `I should be on the login page`, `I should see the login form`, `I log out`, `I go to the logout page`, `I should be asked to confirm the logout`, `I confirm the logout`, `I should be logged in`, `I should not be logged in`, `I should be logged in as "user"`, `I should be back on the page I asked for`, `the login should have started a new session`, `the session cookie should be HttpOnly` (`Secure`) |
| Remember-me | `I close the browser and open it again`, `my session expires`, `the remember-me cookie should last 14 days`, `the remember-me cookie should be HttpOnly`, and webship-js's `a cookie with the name "remember-me" should exist` (`should not exist`) |
| Access | `I should be allowed to open "/owners/find"`, `I should not be allowed to open "/owners/new"` (a visitor is sent to the login page, an account without the role gets 403) |
| CSRF | `every form that posts on this page should carry a CSRF token`, `the form of the "Update Owner" button should carry a CSRF token` (`should not`), `I press "Update Owner" with a forged token`, `a page of another site sends a form to "/owners/1/edit"` |
| Error pages | `I should see the 404 error page` (403, 500), `I should see the default error page` (`should not`), `the default error page should say "Not Found" with the status 404`, `the page should not show debug information`, `a program asks for "/oups"`, `the program should get the error "Internal Server Error" with the status 500`, `the error answer should not carry a stack trace` (`the exception message`) |
| Health | `the health endpoint should report "UP"`, `the health endpoint should show the component "db"` (`should not`), `the health endpoint should show no components`, `the health component "db" should report "UP"`, `the health group "liveness" should report "UP"`, `the info endpoint should show "build.artifact" as "spring-petclinic"` |
| Forms | `the "Telephone" field should have the error "Telephone must be a 10-digit number"` (`should not`), `the "Last Name" field should have no error`, `the form should show the errors:` with a table of labels and messages, `the form should show no errors`, `I should see the success message "Owner Values Updated"` (`should not`) |

Text, links, buttons and fields are webship-js's own: `I should see "…"`, `I press "…"`, `I fill in "…" with "…"`,
`I go to "…"`, `I reload the page`, `the path should be "…"`.

## A scenario, start to end

A forged save is refused and changes nothing: the scenario reads the value back as the account it used.

```gherkin
Feature: The CSRF protection
  @js-off
  Scenario: A form sent with a forged token is refused, and nothing changes
    Given I am a logged in user with the "administrator" user
    When I go to "/owners/1/edit"
    And I fill in "Telephone" with "6085550000"
    And I press "Update Owner" with a forged token
    Then I should see the 403 error page
    When I go to "/owners/1"
    Then I should see "6085551023"
```

## Traps found on a real app

- The pages are rendered on the server: an action is a form post and a new page, and a refused form comes back with
  the status 200 and its messages next to the fields.
- The browser logs every error page it gets (a 403, a 404, a 500, also a program's refused request), and the pages
  Spring Security generates ask for `/favicon.ico`, a 404 for a signed-in account: tag those scenarios `@js-off`.
- For a signed-in browser the generated login page holds the account's username in a read-only field: log out
  before logging in as another account.
- A visitor who asks for a missing page is sent to the login page, not to a 404: Spring Security guards every page
  that is not open to anybody.
- A form that posts without a `th:action` carries no CSRF token, and every one of its saves is refused with 403.
- A request from another site carries the session cookie only while the cookie is new, and its 403 answer can give
  the browser another session: log in again before you look at the data.
- A new app has no page of its own: every page a signed-in account opens is the default error page (404).
- The app keeps its data in memory: a restart (`cmd-tools-spring-boot-cli.sh <app> --restart`) begins with its data
  again. A scenario that saves a form saves the value the field had, or puts it back.

## Examples

- [`examples/session.feature`](examples/session.feature): the login, a refusal, the page asked for, the logout pages.
- [`examples/remember-me-and-access.feature`](examples/remember-me-and-access.feature): remember-me, a session that ended, the pages of each role.
- [`examples/errors-and-forms.feature`](examples/errors-and-forms.feature): the app's own error pages, the health by role, a refused form.

Copy them into `tests/features/` of a project of the PetClinic sample and run them:

```bash
bash cmd-tools-testing.sh <app> --run --path tests/features/session.feature
```

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For Spring Boot.** Start with `ch10-authentication-authorization.md` (logins, sessions, remember-me, roles and
  refusals), `ch07-waiting-dynamic-content.md` (waiting on the app's own signals), `ch06-form-testing-recipes.md`
  (forms and their validation) and `ch44-javascript-and-friendly-errors.md` (the browser messages of a page).
