import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';

import { register, assistantContext, PLATFORM, COMMANDS, AGENTS } from '../src/index';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const read = (f: string) => fs.readFileSync(path.join(PKG, f), 'utf8');
const manifest = JSON.parse(read('package.json')).workspacePlugin;

test('the manifest names the platform, and every file it names ships', () => {
  assert.strictEqual(manifest.name, PLATFORM);
  const named = [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args, ...manifest.scripts.machine,
    ...manifest.ai.agents, ...manifest.ai.skills, ...manifest.ai.commands, ...manifest.ai.prompts, ...manifest.features];
  for (const f of named) assert.ok(fs.existsSync(path.join(PKG, f)), `${f} is in the package`);
  assert.deepStrictEqual(manifest.commands.files.map((f: string) => path.basename(f)), COMMANDS);
  assert.deepStrictEqual(manifest.ai.agents.map((f: string) => path.basename(f, '.md')), AGENTS);
  assert.deepStrictEqual(manifest.commands.types, ['sites'], 'the commands go to sites folders only');
  const files: string[] = JSON.parse(read('package.json')).files;
  for (const f of named) assert.ok(files.includes(f.split('/')[0]), `${f} is published with the package`);
  // The machine files land side by side in core/scripts/plugins/spring-boot/: no two may share a name.
  const names = manifest.scripts.machine.map((f: string) => path.basename(f));
  assert.strictEqual(new Set(names).size, names.length, 'the machine files have names of their own');
});

test('every command finds the workspace by itself, names its folder, and sources its args from where the installer puts them', () => {
  for (const f of manifest.commands.files) {
    const src = read(f);
    assert.match(src, /^#!\/usr\/bin\/env bash/, `${f} is a bash script`);
    assert.match(src, /WORKSPACE_SCRIPTS="\$\{WORKSPACE_SCRIPTS:-\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)\/\.\.\/core\/scripts" && pwd\)\}"/, `${f} locates the tooling from its own path`);
    assert.match(src, /workspace\.__WORKSPACE__\.settings\.yml/, `${f} loads the settings of the folder it is installed into`);
    assert.match(src, /source \$\{WORKSPACE_SCRIPTS\}\/plugins\/spring-boot\/args\/arg-[a-z-]+\.sh \|\| exit 1 ;/, `${f} reads its arguments from the plugin's args`);
    assert.match(src, /^distribution_name="spring_boot";$/m, `${f}: the user list of the core's tools is spring_boot`);
    const last = src.trim().split('\n').pop() as string;
    assert.match(read('scripts/functions/fun-spring-boot.sh'), new RegExp(`^function ${last.replace(/ ;$/, '')}\\(\\)`, 'm'), `${f} ends by calling a function the plugin defines`);
  }
  assert.match(read('commands/cmd-spring-boot-project.sh'), /^# workspace-name: Spring Boot/m, 'the builder carries the name the Build list shows');
  assert.doesNotMatch(read('commands/cmd-tools-spring-boot-cli.sh'), /^# workspace-name:/m, 'a tool is not a builder');
});

test('every shell script and the preparation script parse', () => {
  for (const f of [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args]) {
    const r = spawnSync('bash', ['-n', path.join(PKG, f)], { encoding: 'utf8' });
    assert.strictEqual(r.status, 0, `${f}: ${r.stderr}`);
  }
  const py = spawnSync('python3', ['-c', 'import ast, sys; ast.parse(open(sys.argv[1]).read())', path.join(PKG, 'scripts/app/spring-boot-prepare-app.py')], { encoding: 'utf8' });
  assert.strictEqual(py.status, 0, py.stderr);
});

test('the claim file is the plugin\'s own name, and is a real overlay of the container tool: the daemon, the port, the Maven settings', () => {
  const src = read('scripts/functions/fun-spring-boot.sh');
  assert.match(src, /\.ddev\/config\.spring-boot\.yaml/, 'the file the core reads as the plugin\'s claim (#490): config.<plugin>.yaml');
  const yaml = (src.match(/config\.spring-boot\.yaml" <<YAMLEOF\n([\s\S]*?)\nYAMLEOF/) || [])[1] || '';
  assert.match(yaml, /^web_extra_exposed_ports:\n  - name: spring-boot\n    container_port: \$\{SPRING_BOOT_PORT\}\n    http_port: 80\n    https_port: 443$/m, 'the router sends the project\'s address to the app\'s port');
  assert.match(yaml, /^web_extra_daemons:\n  - name: spring-boot\n    command: ".*exec java .*-jar \$\{SPRING_BOOT_ROOT\}\/app\.jar'"/m, 'the web container runs the app\'s jar as a daemon');
  assert.match(yaml, /MAVEN_USER_HOME=\$\{SPRING_BOOT_ROOT\}\/\.m2/, 'Maven keeps its downloads in the project');
  assert.match(src, /^function set_spring_boot_users\(\) \{/m, 'the claim names a plugin with a user list: set_<plugin>_users with the dash as an underscore');
});

test('the functions carry the names the core\'s tools look for, and build the app the official way', () => {
  const src = read('scripts/functions/fun-spring-boot.sh');
  for (const fn of ['set_spring_boot_users', 'add_spring_boot_users', 'cancel_spring_boot_users', 'testing_configure_spring_boot', 'spring_boot_build', 'spring_boot_cli_tool']) {
    assert.match(src, new RegExp(`^function ${fn}\\(\\) \\{`, 'm'), `${fn} is defined`);
  }
  assert.match(src, /--project-type=generic --webserver-type=generic --docroot=app/, 'a generic project whose web container runs the app itself');
  assert.match(src, /--omit-containers=db/, 'the app keeps its own data');
  assert.match(src, /--nodejs-version=\$\(ddev_nodejs_version\)/, 'the project carries the Node.js of the workspace rule');
  assert.match(src, /COPY --from=eclipse-temurin:\$\{java_version\}-jdk \/opt\/java\/openjdk \/opt\/java\/openjdk/, 'the JDK from its official image');
  assert.match(src, /https:\/\/start\.spring\.io\/starter\.zip\?type=maven-project/, 'a new app made with Spring Initializr');
  assert.match(src, /github\.com\/spring-projects\/spring-petclinic\.git/, 'the sample from its own repository');
  assert.match(src, /\.\/mvnw -B -ntp -Dmaven\.repo\.local=\$\{SPRING_BOOT_ROOT\}\/\.m2\/repository/, 'the app\'s own Maven wrapper, in the container');
  assert.match(src, /readonly SPRING_BOOT_DEFAULT_VERSION='4\.2\.0';/, 'the current Spring Boot release');
  assert.match(src, /readonly SPRING_BOOT_DEFAULT_JAVA='25';/, 'the current long-term-support JDK');
  assert.match(src, /password_hash\(stream_get_contents\(STDIN\), PASSWORD_BCRYPT\)/, 'the passwords become bcrypt hashes from standard input, never on a command line');
  assert.doesNotMatch(src, /ddev stop -y/, 'ddev stop takes no -y');
  assert.doesNotMatch(src, /\| head -n 1 \| tr|java -version 2>&1" < \/dev\/null 2>\/dev\/null \| head/, 'no head that cuts the pipe of the container tool');
});

test('the preparation script is the step pack\'s, and its files are beside it', () => {
  const py = read('scripts/app/spring-boot-prepare-app.py');
  assert.match(py, /def asset\(name, flat_name\):/, 'it finds its files beside it under their flat names');
  assert.match(py, /asset\('SecurityConfiguration\.java', 'SecurityConfiguration\.java'\)/);
  assert.match(py, /asset\('signed-in\.html', 'spring-boot-signed-in\.html'\)/);
  const java = read('scripts/app/SecurityConfiguration.java');
  assert.match(java, /\.formLogin\(Customizer\.withDefaults\(\)\)/, 'form login with the generated pages');
  assert.match(java, /\.rememberMe\(/, 'remember-me');
  assert.match(java, /new InMemoryUserDetailsManager\(users\)/, 'in-memory accounts');
  assert.match(read('scripts/app/spring-boot-signed-in.html'), /sec:authentication="name"/, 'who is signed in, in the navigation bar');
});

test('each agent is a definition the AI Agents folder can list: named after its file, described, on the fable model', () => {
  for (const f of manifest.ai.agents) {
    const src = read(f);
    const head = src.split('\n---\n')[0];
    assert.match(head, /^---\n/, `${f} opens with frontmatter`);
    assert.match(head, new RegExp(`^name: ${path.basename(f, '.md')}$`, 'm'));
    assert.match(head, /^description: .{80,}$/m, `${f} says when to use it`);
    assert.match(head, /^model: fable$/m);
    assert.match(head, /^tools:\n(  - \S+\n?)+/m);
    assert.match(src, /cmd-tools-testing\.sh|cmd-spring-boot-project\.sh/, `${f} names the plugin's commands`);
  }
  const tester = read('ai/agents/spring-boot-tester.md');
  assert.match(tester, /Never create or delete an account in a suite/);
  assert.match(tester, /No platform name in a step phrase/);
  assert.match(tester, /Playwright MCP browser first/);
});

test('register() adds the assistant context and nothing else', () => {
  const calls: string[] = [];
  const api: any = { name: 'spring-boot', addAssistantContext: (fn: () => string) => calls.push(fn()) };
  register(api);
  assert.strictEqual(calls.length, 1);
  assert.strictEqual(calls[0], assistantContext());
  for (const c of COMMANDS) assert.ok(calls[0].includes(c), `the assistant is told about ${c}`);
  for (const a of AGENTS) assert.ok(calls[0].includes(a), `the assistant is told about ${a}`);
});

test('the docs say container-based, name only what ships, and carry no personal value', () => {
  const docs = ['README.md', ...manifest.ai.agents, 'scripts/functions/fun-spring-boot.sh'];
  for (const f of docs) {
    const src = read(f);
    assert.doesNotMatch(src, /DDEV-only/i, `${f}: the workspace is container-based, DDEV by default`);
    assert.doesNotMatch(src, /\/home\/(?!YOUR_USER)[a-z]/, `${f} carries no personal path`);
    const mails = src.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[a-z]{2,}/g) || [];
    for (const m of mails) assert.match(m, /@example\.(com|org)$/, `${f}: ${m} is not an example address`);
  }
  for (const c of COMMANDS) assert.ok(read('README.md').includes(c), `the README lists ${c}`);
});
