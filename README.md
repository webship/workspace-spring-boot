# @webship.co/workspace-spring-boot

Spring Boot for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a builder that makes a
real Spring Boot app in containers (a new app made with Spring Initializr, or the Spring PetClinic sample, at the
current Spring Boot release, built with its own Maven wrapper on the current long-term-support JDK and run as a
production jar), Spring Security added with form login, remember-me and role-named accounts, a tool for the
app's Maven wrapper and its run, the default accounts, the
[Spring Boot step pack](https://github.com/webship/spring-boot-steps) wired into the workspace's testing setup,
and its AI items — two agents, a skill, a command and two prompts — each listed in the workspace folder of its
kind.

The workspace is container-based (DDEV by default): a Spring Boot app is a row like any other, so the row menus
the core draws (start, stop, launch, clone, remove, tests) work on it unchanged. The plugin claims its apps with a
file of its own (`.ddev/config.spring-boot.yaml`), so the Tests menu of the row offers the plugin's test users
(Workspace core 1.0.27 and later; see [The default accounts](#the-default-accounts)).

It is made from the reference platform plugin, `@webship.co/workspace-wordpress`, and runs its app the way the
Strapi plugin runs its server: a generic project whose web container runs the app as a daemon, with the router
of the container tool sending the project's address to the app's port.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require @webship.co/workspace-spring-boot --with-needs   # npm install into the dashboard
bash core/scripts/plugins.sh --activate spring-boot --with-needs                        # plugins.spring-boot in settings.yml
bash core/scripts/plugins.sh --install spring-boot                                      # commands, functions, args, AI items
bash core/scripts/plugins.sh --configure spring-boot                                    # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is idempotent.
`--uninstall` removes what it placed; an AI item you edited stays. `--remove spring-boot` then takes the package
out of the dashboard.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-spring-boot-project.sh`, `cmd-tools-spring-boot-cli.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The agents `spring-boot-site-builder`, `spring-boot-tester` | `ai-agents/` |
| The skill `spring-boot-scenarios` | `ai-skills/` |
| The command `/spring-boot-test` | `ai-commands/` |
| The prompts `spring-boot-build-and-test`, `spring-boot-scenarios-for-an-area` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompts are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate spring-boot --with-needs   # dev and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install spring-boot
```

Everything the builder runs for an app runs in containers, through the container tool the workspace already
needs, and Python 3, which prepares the app's files on the machine: the JDK, the Maven wrapper and the app are the
containers'. The plugin asks for no command of its own on the machine.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-spring-boot-project.sh` | The builder, in the Build list as **Spring Boot (a new app or the PetClinic sample, with Spring Security)**, installed into every sites folder |
| `commands/cmd-tools-spring-boot-cli.sh` | The app's Maven wrapper and run: what the app is, the wrapper's goals, a rebuild, a restart, its log, the default accounts |
| `scripts/functions/fun-spring-boot.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_spring_boot_users`, `add_spring_boot_users`, `cancel_spring_boot_users`, `testing_configure_spring_boot`) |
| `scripts/args/arg-spring-boot.sh`, `arg-spring-boot-cli.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `scripts/app/spring-boot-prepare-app.py` | Prepares the app before it is built (the step pack's own script): the Spring Boot release of the sample, and with `--install` Spring Security, its configuration in the package of the app's main class, the "Signed in as" part of the sample's navigation, and the CSRF token in the sample's forms that post without a `th:action` |
| `scripts/app/SecurityConfiguration.java`, `spring-boot-signed-in.html` | What it adds: form login with the generated login and logout pages, remember-me, the role rules, in-memory accounts; who is signed in and a "Log out" button |
| `testing/site.feature` | The first feature an app gets when testing is set up |
| `ai/agents/spring-boot-site-builder.md` | The agent that builds and maintains apps with these commands |
| `ai/agents/spring-boot-tester.md` | The agent that writes and runs scenarios with the Spring Boot step pack |
| `ai/skills/spring-boot-scenarios/` | The skill: the step pack's phrases by area, the traps found on a real app, three example features |
| `ai/commands/spring-boot-test.md` | The slash command `/spring-boot-test <app>`: set up, match every step, run, report |
| `ai/prompts/spring-boot-build-and-test.md`, `spring-boot-scenarios-for-an-area.md` | Two prompts: whole launch commands for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about Spring Boot here |
| `features/spring-boot.feature` | Scenarios for the dashboard's own browser suite |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## What is different from a PHP platform

A Spring Boot app is a Java app with its own server and its own database, and DDEV has no project type for it. The
plugin keeps the shape of the reference and changes only this:

| | WordPress (the reference) | Spring Boot |
| --- | --- | --- |
| Project | `--project-type=wordpress`, nginx and PHP | `--project-type=generic --webserver-type=generic --docroot=app --omit-containers=db`: the web container runs the app's jar as a daemon and the router sends ports 80 and 443 of the project's address to its port (8080); no database of the container tool's own |
| Recognised by | The DDEV project type | The file `.ddev/config.spring-boot.yaml`: the daemon of the app, its port and the Maven settings, and the plugin's claim on the project |
| The runtime | PHP of the web image | Eclipse Temurin at `--java-version` (25 by default), copied from its official image into the web image (`.ddev/web-build/Dockerfile.spring-boot`) |
| Getting the code | `wp core download` | A new app from Spring Initializr (start.spring.io: web, Thymeleaf, validation, the management endpoints, JPA with an in-memory database), or with `--petclinic` the Spring PetClinic sample from its repository, at `--spring-boot-version` (4.2.0 by default) |
| Building it | Nothing to build | The app's own Maven wrapper in the web container; Maven keeps its downloads in the project (`.m2/`) |
| Install | `wp core install` | `--install`: Spring Security with form login, remember-me, the role rules and in-memory accounts (`app/config/accounts.properties`, password hashes only) |
| Database | The container tool's | The app's own in-memory database (H2): every start of the app begins with its data again |
| Accounts | WP-CLI | Written with their bcrypt hashes into the app's accounts file, and read at the app's start: adding or cancelling them restarts the app |
| Removing it | `ddev delete` | The same, and the project's folder takes the Maven downloads with it |
| Tests menu of the row | Reads the project type | The plugin's claim: core 1.0.27 and later offer the plugin's test users (`spring_boot`) |

No public domain, no hosted service and no account anywhere: the app answers at `https://<name>.ddev.site`
through the container tool's router.

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build an app

```bash
cd ~/workspace/dev
bash cmd-spring-boot-project.sh myapp --install --add-users                  # a new app from Spring Initializr
bash cmd-spring-boot-project.sh mypets --petclinic --install --add-users     # the Spring PetClinic sample
```

| Flag | What it does |
| --- | --- |
| `--petclinic` | The Spring PetClinic sample (owners, pets, visits, forms with validation, its own error page) instead of a new app |
| `--install` | Add Spring Security: form login with the generated login and logout pages, remember-me, the role rules, in-memory accounts. Without it the app is built as it is, with no login |
| `--add-users` | With `--install`: add the default accounts |
| `--spring-boot-version <v>` | The Spring Boot release: `4.2.0` by default (a release Spring Initializr offers, for a new app) |
| `--java-version <n>` | The JDK, a major release of Eclipse Temurin: `25`, the current long-term-support one, by default |
| `--launch` | Open the app when it is ready |

The app answers at `https://myapp.ddev.site`, its login at `/login` (the page Spring Security generates) and its
health at `/actuator/health`. A project of the same name is deleted first.

A build takes about five minutes the first time (the JDK's image is about 160 MB, and Maven downloads the app's
libraries into the project, about 230 MB) and two after that; the app then uses about 500 MB of memory (its heap is
limited to 512 MB). Check the free memory first (`free -g`), and build one app at a time on a machine others use.

The rules a new app gets: anybody opens its error page and its health; `/admin/**` and the other management
endpoints are for the ADMIN role; every other page needs a signed-in account. A new app has no page of its own
yet, so a signed-in account meets the framework's default error page until you write one. The sample keeps its
home page, its veterinarians and its error page open to anybody, needs a signed-in account for the owners and the
visits, and keeps adding and editing owners and pets for the ADMIN role.

### Work on an app

```bash
bash cmd-tools-spring-boot-cli.sh myapp                       # kind, versions, addresses, accounts
bash cmd-tools-spring-boot-cli.sh myapp --mvnw "test"         # the wrapper's goals in the web container
bash cmd-tools-spring-boot-cli.sh myapp --mvnw "dependency:tree"
bash cmd-tools-spring-boot-cli.sh myapp --rebuild             # the jar again after a change to the code, and a restart
bash cmd-tools-spring-boot-cli.sh myapp --restart             # restart the app and wait for it
bash cmd-tools-spring-boot-cli.sh myapp --logs                # the end of the web container's log
bash cmd-tools-spring-boot-cli.sh myapp --add-users           # the default accounts, and a restart
bash cmd-tools-spring-boot-cli.sh myapp --cancel-users        # take them out again, and a restart
```

The wrapper runs in the web container with the project's Maven downloads. The app's code is in `app/` of the
project: change it, then `--rebuild`.

### The default accounts

| Account | Address | Role | Handle in the tests |
| --- | --- | --- | --- |
| `administrator` | `administrator@example.com` | ADMIN | `administrator` |
| `user` | `user@example.com` | USER | `user` |

Each account has the password of the workspace's other default lists. They are in-memory accounts of the app,
written with their bcrypt hashes into `app/config/accounts.properties` (no password on a command line or in a
file), and read at the app's start. An account of your own added to that file stays when the default accounts are
added or cancelled again. They are for local apps and for tests.

The row's Tests menu offers **Add the test users** and **Cancel the test users** for an app this plugin claims
(Workspace core 1.0.27 and later): they run the same list as

```bash
bash cmd-tools-add-users.sh myapp spring_boot       # the core's tool, with the plugin's list
bash cmd-tools-cancel-users.sh myapp spring_boot
```

An app built without `--install` has no login, and so no place for accounts: the tools say so and change nothing.
On a core older than 1.0.27 the Tests menu hands every project that is not of a known type the Webship
distribution's list (which starts by adding Drush with Composer): leave those two items alone there and use the
CLI tool.

### Test an app

```bash
bash cmd-tools-testing.sh mypets                 # webship-js, the step pack, the users registry, a first feature
bash cmd-tools-testing.sh mypets --run           # run the suite in the container
bash cmd-tools-testing.sh mypets --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For a Spring Boot app it also adds `@webship-js/spring-boot-steps`
to `package.json`, lists its step definitions in `cucumber.js` after webship-js's own, writes the pages of the app
the steps need (the login and logout pages, a page only a signed-in account may open: `/owners/find` for the
sample, `/` for a new app, the health and info endpoints), the users registry (the handles above, by their
usernames, overridable with `SPRING_BOOT_<HANDLE>_USERNAME` and `SPRING_BOOT_<HANDLE>_PASSWORD`), the browser
messages the step pack's scenarios turn off, the tags that keep the pack's assertions that must fail out of a
normal run, and the app's address in place of the starter's `http://localhost:8080`. It places
`tests/features/site.feature` when the project has none, and makes sure the default accounts are in an app with a
login once it answers again (installing the webship-js add-on restarts the project, and the app with it). Run it
again and it adds what is missing and keeps what you changed.

Until `@webship-js/spring-boot-steps` is on npm, give the testing setup its tarball (`npm pack` of the pack) with
`bash cmd-tools-testing.sh mypets --add-steps <path to the tarball>`, then run the setup again.

A scenario of your own reads like this one, from the step pack's phrases (the skill `spring-boot-scenarios` lists
them by area):

```gherkin
Feature: A session that ended
  Scenario: The browser is sent to the login page, and back to the page after the login
    Given I am a logged in user with the "user" user
    When my session expires
    And I go to "/owners/find"
    Then I should be on the login page
    When I log in as "user" with the login form
    Then I should be back on the page I asked for
```

`tests/features/site.feature` passes on an app built with `--install --add-users`, a new one or the sample, and the
features of the step pack pass on the sample built with `--petclinic --install --add-users`.

## The AI items

`ai/` in the package holds one folder per kind, the manifest's `ai` block names each item, and `--install` places
it in the workspace folder of that kind.

| Kind | Item | Use it to |
| --- | --- | --- |
| Agent | `spring-boot-site-builder` | Build, maintain or remove an app with the commands above, in containers only |
| Agent | `spring-boot-tester` | Set the testing stack up, look at the pages in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |
| Skill | `spring-boot-scenarios` | Write a scenario from phrases that exist: the pack's steps by area, the handles of the users registry, the traps found on a real app, and three features that pass on the sample with the default accounts |
| Command | `/spring-boot-test <app> [feature or @tag]` | Run the suite of an app from inside a session: set up when missing, match every step, run, report what failed and why |
| Prompt | `spring-boot-build-and-test` | Start a session that builds the sample, says what it is, sets the testing stack up and runs the first feature |
| Prompt | `spring-boot-scenarios-for-an-area` | Start a session that writes and runs the scenarios of one area of an app |

After `--install` each is in its folder on the dashboard. **Install** there puts an agent, a skill or a command
into Claude Code (`~/.claude/agents`, `~/.claude/skills`, `~/.claude/commands`), or from the command line:

```bash
cd ~/workspace/ai-agents   && bash cmd-tools-ai-items.sh spring-boot-tester --install
cd ~/workspace/ai-skills   && bash cmd-tools-ai-items.sh spring-boot-scenarios --install
cd ~/workspace/ai-commands && bash cmd-tools-ai-items.sh spring-boot-test --install
```

A prompt is not installed: it is the whole `claude …` launch command of a new session, and the dashboard's
**New screen** form lists it as a template. By hand, fill the placeholders in and run the command of the file from
the folder it names.

The items are written for any AI CLI, with Claude Code as the default shape: the frontmatter and the file layout
are Claude Code's, the body of each item is plain Markdown that names no tool or feature of one CLI, a command says
in words what its arguments are, and the text between the triple quotes of a prompt can be given to another AI CLI
as it is.

Every step phrase the items show is checked against the definitions of the step pack and of webship-js
(`tests/fixtures/step-definitions.txt`), and every command and flag against the plugin's own.

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the AI items, the functions against a scaffolded project
```

CI runs the same on Node.js 20 and 24, parses every shell script, and runs the plugin's
`features/spring-boot.feature` against a dashboard with this plugin installed
(`webship/workspace/.github/workflows/plugin-browser-suite.yml`).
