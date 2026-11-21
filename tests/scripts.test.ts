import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-spring-boot.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['tsx/cjs'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

/**
 * A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled. An app
 * of this plugin has the builder's .ddev/config.spring-boot.yaml; `app` says which app and whether it has a login.
 */
function project(kind: 'new' | 'petclinic' | 'drupal', security = true) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'spring-boot-plugin-'));
  const dir = path.join(root, 'dev', 'app1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: app1\ntype: ${kind === 'drupal' ? 'drupal11' : 'generic'}\n`);
  if (kind !== 'drupal') {
    fs.writeFileSync(path.join(dir, '.ddev', 'config.spring-boot.yaml'), 'web_extra_daemons: []\n');
    fs.mkdirSync(path.join(dir, 'app', 'config'), { recursive: true });
    const artifact = kind === 'petclinic' ? 'spring-petclinic' : 'demo';
    fs.writeFileSync(path.join(dir, 'app', 'pom.xml'), `<project><artifactId>${artifact}</artifactId>${security ? '<artifactId>spring-boot-starter-security</artifactId>' : ''}</project>\n`);
  }
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'app1', devDependencies: { 'webship-js': '^2.0.16' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  const plugin = path.join(scripts, 'plugins', 'spring-boot');
  fs.mkdirSync(plugin, { recursive: true });
  for (const f of ['testing/site.feature', 'scripts/app/spring-boot-prepare-app.py', 'scripts/app/SecurityConfiguration.java', 'scripts/app/spring-boot-signed-in.html']) {
    fs.copyFileSync(path.join(PKG, f), path.join(plugin, path.basename(f)));
  }
  return { root, dir, scripts };
}

/**
 * Run bash with the plugin's functions sourced and `ddev` replaced by a recorder of its command lines: the password
 * hash PHP makes from its standard input becomes a bcrypt-shaped value, the health check answers UP.
 */
function bash(script: string, env: Record<string, string> = {}) {
  const fake = [
    'ddev() {',
    '  echo "ddev $*" >> "${DDEV_LOG:-/dev/null}" ;',
    '  case "$*" in',
    '    *password_hash*) local secret ; secret="$(cat)" ; printf \'$2y$10$%s\' "$(printf \'%s\' "${secret}" | sha256sum | cut -c1-53)" ;;',
    '    *actuator/health*) echo \'{"status":"UP"}\' ;;',
    '    *) if [ ! -t 0 ] ; then cat > /dev/null ; fi ;;',
    '  esac',
    '  return 0 ;',
    '}',
  ].join('\n');
  return spawnSync('bash', ['-c', `${fake}\nsource ${FUNCTIONS}\n${script}`], { encoding: 'utf8', env: { ...process.env, ...env } });
}

test('the default accounts are an administrator with the ADMIN role and a user with the USER role, with example addresses', () => {
  const r = bash('set_spring_boot_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; g="user_${u}_role" ; echo "${!n}|${!m}|${!p}|${!g}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['administrator', 'user']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['ADMIN', 'USER']);
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    assert.ok(password.length >= 10, 'a password every common password rule accepts');
  }
});

test('the accounts go into the app as bcrypt hashes made from standard input: no password on a command line or in a file', () => {
  const p = project('petclinic');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('set_spring_boot_users ; add_spring_boot_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'app1', DDEV_LOG: log });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const file = fs.readFileSync(path.join(p.dir, 'app', 'config', 'accounts.properties'), 'utf8');
  assert.match(file, /^app\.accounts=administrator,user$/m);
  assert.match(file, /^app\.account\.administrator\.password=\{bcrypt\}\$2y\$10\$[./0-9A-Za-z]{53}$/m);
  assert.match(file, /^app\.account\.administrator\.roles=ADMIN$/m);
  assert.match(file, /^app\.account\.user\.roles=USER$/m);
  assert.doesNotMatch(file, /dD\.123123ddd/, 'the file holds hashes only');
  const recorded = fs.readFileSync(log, 'utf8');
  assert.doesNotMatch(recorded, /dD\.123123ddd/, 'no password on a command line');
  assert.match(recorded, /ddev exec supervisorctl restart webextradaemons:spring-boot/, 'the app restarts: it reads its accounts at its start');
});

test('cancelling the default accounts keeps the other accounts of the app', () => {
  const p = project('new');
  fs.writeFileSync(path.join(p.dir, 'app', 'config', 'accounts.properties'), [
    'app.accounts=administrator,tester,user',
    'app.account.administrator.password={bcrypt}$2y$10$aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'app.account.administrator.roles=ADMIN',
    'app.account.tester.password={bcrypt}$2y$10$bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    'app.account.tester.roles=USER',
    'app.account.user.password={bcrypt}$2y$10$ccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    'app.account.user.roles=USER',
    '',
  ].join('\n'));
  const r = bash('set_spring_boot_users ; cancel_spring_boot_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'app1' });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const file = fs.readFileSync(path.join(p.dir, 'app', 'config', 'accounts.properties'), 'utf8');
  assert.match(file, /^app\.accounts=tester$/m);
  assert.match(file, /^app\.account\.tester\.roles=USER$/m);
  assert.doesNotMatch(file, /app\.account\.(administrator|user)\./);
});

test('an app built without a login has no place for accounts: the tools say so and change nothing', () => {
  const p = project('new', false);
  const r = bash('set_spring_boot_users ; add_spring_boot_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'app1' });
  assert.notStrictEqual(r.status, 0);
  assert.match(r.stdout, /has no login \(it was built without --install\)/);
  assert.ok(!fs.existsSync(path.join(p.dir, 'app', 'config', 'accounts.properties')));
});

test('the claim file and the web image: the daemon, the port, the Maven settings, the JDK of the official image', () => {
  const p = project('new');
  const r = bash(`spring_boot_write_ddev_config "${p.dir}" 21`);
  assert.strictEqual(r.status, 0, r.stderr);
  const claim = fs.readFileSync(path.join(p.dir, '.ddev', 'config.spring-boot.yaml'), 'utf8');
  assert.match(claim, /container_port: 8080\n    http_port: 80\n    https_port: 443/);
  assert.match(claim, /exec java -Xms128m -Xmx512m -jar \/var\/www\/html\/app\.jar/);
  assert.match(claim, /MAVEN_OPTS=-Dmaven\.repo\.local=\/var\/www\/html\/\.m2\/repository/);
  const docker = fs.readFileSync(path.join(p.dir, '.ddev', 'web-build', 'Dockerfile.spring-boot'), 'utf8');
  assert.match(docker, /^COPY --from=eclipse-temurin:21-jdk \/opt\/java\/openjdk \/opt\/java\/openjdk$/m);
  assert.match(docker, /ln -sf \/opt\/java\/openjdk\/bin\/\$tool \/usr\/local\/bin\/\$tool/);
});

test('the settings of the run: forwarded headers always, the rules of the sample only for the sample, the login only with --install', () => {
  const read = (p: { dir: string }) => fs.readFileSync(path.join(p.dir, 'app', 'config', 'application.properties'), 'utf8');
  const pet = project('petclinic');
  assert.strictEqual(bash(`spring_boot_write_settings "${pet.dir}" yes`).status, 0);
  assert.match(read(pet), /^server\.forward-headers-strategy=native$/m);
  assert.match(read(pet), /^app\.security\.admin-paths=\/owners\/new,\/owners\/\*\/edit,/m);
  assert.match(read(pet), /^management\.endpoint\.health\.roles=ADMIN$/m);
  assert.match(read(pet), /^app\.remember-me\.key=[A-Za-z0-9]{32}$/m);
  assert.match(read(pet), /^spring\.config\.import=optional:file:\.\/config\/accounts\.properties$/m);
  const fresh = project('new');
  assert.strictEqual(bash(`spring_boot_write_settings "${fresh.dir}" yes`).status, 0);
  assert.doesNotMatch(read(fresh), /app\.security\./, 'a new app takes the default rules of the security configuration');
  const open = project('petclinic', false);
  assert.strictEqual(bash(`spring_boot_write_settings "${open.dir}" no`).status, 0);
  assert.strictEqual(read(open).split('\n').filter((l) => l && !l.startsWith('#')).join('\n'), 'server.forward-headers-strategy=native', 'without a login: nothing but the forwarded headers');
});

test('the testing hook adds the pack, the pages of the app, the browser messages and the users registry, once', () => {
  for (const kind of ['petclinic', 'new'] as const) {
    const p = project(kind);
    const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'app1' };
    const first = bash(`testing_configure_spring_boot "${p.dir}"`, env);
    assert.strictEqual(first.status, 0, first.stderr + first.stdout);
    const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
    assert.strictEqual(pkg.devDependencies['@webship-js/spring-boot-steps'], '^2.0.0');
    const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
    assert.match(cucumber, /'node_modules\/webship-js\/tests\/step-definitions\/\*\*\/\*\.js',.*\n\s+'node_modules\/@webship-js\/spring-boot-steps\/tests\/step-definitions\/\*\*\/\*\.js',/, 'the pack after webship-js');
    assert.match(cucumber, /tags: process\.env\.CUCUMBER_TAGS \|\| 'not @wip and not @must-fail',/);
    assert.match(cucumber, /loginPath: '\/login',/);
    assert.match(cucumber, /logoutPath: '\/logout',/);
    assert.match(cucumber, new RegExp(`protectedPath: '${kind === 'petclinic' ? '/owners/find' : '/'}',`), `the page only a signed-in account opens, of the ${kind} app`);
    assert.match(cucumber, /healthPath: '\/actuator\/health',/);
    assert.match(cucumber, /javascript: \{ mode: process\.env\.WEBSHIP_JS_ERROR_MODE \|\| 'warn'/);
    assert.match(cucumber, /administrator: \{ username: process\.env\.SPRING_BOOT_ADMINISTRATOR_USERNAME \|\| 'administrator', password: process\.env\.SPRING_BOOT_ADMINISTRATOR_PASSWORD \|\| 'dD\.123123ddd' \},/);
    assert.match(cucumber, /user: \{ username: process\.env\.SPRING_BOOT_USER_USERNAME \|\| 'user'/);
    assert.match(cucumber, /process\.env\.LAUNCH_URL \|\| 'https:\/\/app1\.ddev\.site'/, 'the address of the app');
    assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')), 'a first feature');
    assert.match(first.stdout, /the default accounts are in the app \(administrator user\)/);
    // A second run adds nothing and resets nothing.
    const again = bash(`testing_configure_spring_boot "${p.dir}"`, env);
    assert.strictEqual(again.status, 0, again.stderr);
    assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber, 'the second run changes nothing in cucumber.js');
  }
});

test('the testing hook leaves a project of another platform alone', () => {
  const p = project('drupal');
  const r = bash(`testing_configure_spring_boot "${p.dir}"`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'app1' });
  assert.strictEqual(r.status, 0, r.stderr);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
  assert.strictEqual(r.stdout, '');
});
