/**
 * Spring Boot for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the Maven wrapper's CLI
 * tool in the sites folders, their functions and argparse under core/scripts/plugins/spring-boot/ (with the files
 * the builder adds to the sample: the security configuration, the "signed in" part of its navigation bar and the
 * script that puts them in), and its AI items (ai/ in this package) in the folder of their kind: the agents in AI
 * Agents, the skill in AI Skills, the command in AI Commands, the prompts in AI Prompts. The dashboard needs
 * nothing drawn for it: the builder is in the Build list because it is a cmd-*-project.sh, the row menus are the
 * core's, the AI items are listed like any other. What register() adds is what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the dashboard's
 * own files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/**
 * The plugin's name. A Spring Boot app is a generic DDEV project: the plugin claims it with
 * .ddev/config.spring-boot.yaml, and the core's tools call its functions under spring_boot.
 */
export const PLATFORM = 'spring-boot';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-spring-boot-project.sh', 'cmd-tools-spring-boot-cli.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['spring-boot-site-builder', 'spring-boot-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['spring-boot-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['spring-boot-test'];

/** The prompts the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['spring-boot-build-and-test', 'spring-boot-scenarios-for-an-area'];

/** What the assistant is told about Spring Boot in this workspace. */
export function assistantContext(): string {
  return [
    'Spring Boot (a plugin, @webship.co/workspace-spring-boot): an app is built with',
    '`bash cmd-spring-boot-project.sh <name> --install --add-users` from a sites folder (dev, test, sandboxes, demos):',
    'the Spring PetClinic sample at the current Spring Boot release, built with its own Maven wrapper on the current long-term-support JDK (Eclipse Temurin, in the web image)',
    'and run as a production jar by the web container of a generic DDEV project at https://<name>.ddev.site;',
    '`--install` adds Spring Security (form login with the generated login and logout pages, remember-me, the role rules; `--no-security` keeps the sample as it is),',
    '`--add-users` adds the default accounts (administrator with the ADMIN role, user with the USER role, in memory),',
    '`--spring-boot-version` takes a release (4.2.0 by default), `--java-version` a JDK (25 by default), `--default-error-page` takes the sample\'s own error page away.',
    'A build takes a few minutes the first time (Maven downloads the libraries into the project\'s .m2/) and the app about 500 MB of memory.',
    '`bash cmd-tools-spring-boot-cli.sh <name>` says what the app is; `--mvnw "<goals>"` runs the Maven wrapper in the container, `--rebuild` builds the jar again and restarts the app,',
    '`--restart` restarts it, `--logs` shows its log, `--add-users` and `--cancel-users` manage the default accounts.',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the Spring Boot step pack; `--run` runs the suite.',
    `For Spring Boot work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <site>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run java, mvn or the wrapper on the host for a project; removing the project removes its Maven downloads too.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
