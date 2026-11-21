#!/usr/bin/env python3
"""Prepares the app of the test site before it is built with its own Maven wrapper.

Run by the build of the test site (the step pack's build script, or the Webship Workspace's builder) on the
app's folder: the Spring PetClinic sample, or a new app made with Spring Initializr.

    python3 prepare-app.py <app> [--boot-version 4.2.0] [--security on|off]

  --boot-version  the Spring Boot release of the parent POM (empty keeps the app's own).
  --security on   adds Spring Security when the app does not have it yet (the starter and the Thymeleaf extras of
                  the parent's dependency management) and the security configuration of this folder
                  (security/SecurityConfiguration.java, in the package of the app's main class): form login with the
                  generated login and logout pages, remember-me, the role rules of app.security.public-paths and
                  app.security.admin-paths, in-memory accounts from config/accounts.properties. In an app with a
                  layout (the sample's fragments/layout.html) the navigation bar also shows who is signed in and a
                  "Log out" button (security/signed-in.html), and every form that posts without a th:action gets the
                  CSRF token: Thymeleaf adds it only to a form with a th:action, so Spring Security would refuse every
                  save of the others. The field is the one Spring Security's reference gives for such forms.
                  off leaves the app as it is.

Every change fails loudly when the app does not look the way this script expects: the build stops instead of
testing an app that is not the one it says.
"""

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SECURITY_DEPENDENCIES = """
    <!-- Added by the build of the test site: Spring Security and its Thymeleaf extras. -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-security</artifactId>
    </dependency>
    <dependency>
      <groupId>org.thymeleaf.extras</groupId>
      <artifactId>thymeleaf-extras-springsecurity6</artifactId>
    </dependency>"""
CSRF_FIELD = '<input type="hidden" th:name="${_csrf.parameterName}" th:value="${_csrf.token}" />'


def fail(message):
    sys.exit('prepare-app.py: ' + message)


def asset(name, flat_name):
    """A file this script adds to the app: in security/ beside it (the step pack), or beside it under its flat
    name (the Webship Workspace's plugin places them side by side)."""
    for candidate in (os.path.join(HERE, 'security', name), os.path.join(HERE, flat_name)):
        if os.path.isfile(candidate):
            return candidate
    fail('%s is not beside this script (security/%s or %s).' % (name, name, flat_name))


def read(path):
    with open(path, encoding='utf-8') as handle:
        return handle.read()


def write(path, text):
    with open(path, 'w', encoding='utf-8') as handle:
        handle.write(text)


def set_boot_version(app, version):
    pom_file = os.path.join(app, 'pom.xml')
    pom = read(pom_file)
    parent = re.search(r'<parent>.*?</parent>', pom, re.S)
    if not parent or 'spring-boot-starter-parent' not in parent.group(0):
        fail('pom.xml has no spring-boot-starter-parent.')
    block = re.sub(r'<version>[^<]+</version>', '<version>%s</version>' % version, parent.group(0), count=1)
    write(pom_file, pom[:parent.start()] + block + pom[parent.end():])
    print('  Spring Boot %s (the parent POM)' % version)


def main_package(app):
    """The folder and the package of the app's main class (the one annotated @SpringBootApplication)."""
    sources = os.path.join(app, 'src', 'main', 'java')
    for folder, _, files in os.walk(sources):
        for name in sorted(files):
            if name.endswith('.java') and '@SpringBootApplication' in read(os.path.join(folder, name)):
                package = re.search(r'^package\s+([\w.]+)\s*;', read(os.path.join(folder, name)), re.M)
                if not package:
                    fail('the main class %s has no package.' % name)
                return folder, package.group(1)
    fail('the app has no class annotated @SpringBootApplication under src/main/java.')


def add_csrf_fields(app, layout):
    """The token field in every form of the templates that posts without a th:action."""
    templates = os.path.join(app, 'src', 'main', 'resources', 'templates')
    forms = 0
    for folder, _, files in os.walk(templates):
        for name in sorted(files):
            if not name.endswith('.html'):
                continue
            path = os.path.join(folder, name)
            text = read(path)
            if CSRF_FIELD in text:
                forms += text.count(CSRF_FIELD)
                continue
            found = []

            def add(match):
                tag = match.group(0)
                if 'th:action' in tag or not re.search(r'method="post"', tag, re.I):
                    return tag
                found.append(tag)
                line_start = text.rfind('\n', 0, match.start()) + 1
                indent = re.match(r'[ \t]*', text[line_start:]).group(0)
                return tag + '\n' + indent + '  ' + CSRF_FIELD

            changed = re.sub(r'<form\b[^>]*>', add, text)
            if found:
                write(path, changed)
                forms += len(found)
    if layout and not forms:
        fail('no form of the templates posts without a th:action: the sample changed.')
    if forms:
        print('  the CSRF token in the %d form(s) that post without a th:action' % forms)


def add_security(app):
    pom_file = os.path.join(app, 'pom.xml')
    pom = read(pom_file)
    if 'spring-boot-starter-security' not in pom:
        match = re.search(r'<dependencies>', pom)
        if not match:
            fail('pom.xml has no <dependencies>.')
        write(pom_file, pom[:match.end()] + SECURITY_DEPENDENCIES + pom[match.end():])
    folder, package = main_package(app)
    config = read(asset('SecurityConfiguration.java', 'SecurityConfiguration.java'))
    config = re.sub(r'^package\s+[\w.]+\s*;', 'package %s;' % package, config, count=1, flags=re.M)
    write(os.path.join(folder, 'SecurityConfiguration.java'), config)
    layout_file = os.path.join(app, 'src', 'main', 'resources', 'templates', 'fragments', 'layout.html')
    layout = os.path.isfile(layout_file)
    if layout:
        text = read(layout_file)
        if 'signed-in-as' not in text:
            nav_end = text.find('</nav>')
            last_list = text.rfind('</ul>', 0, nav_end)
            if nav_end < 0 or last_list < 0:
                fail('the layout has no navigation bar with a list of links.')
            snippet = read(asset('signed-in.html', 'spring-boot-signed-in.html'))
            cut = last_list + len('</ul>')
            write(layout_file, text[:cut] + '\n' + snippet.rstrip('\n') + text[cut:])
    print('  Spring Security in %s: form login, remember-me, logout, the role rules%s' % (
        package, ', who is signed in in the navigation bar' if layout else ''))
    add_csrf_fields(app, layout)


def main():
    parser = argparse.ArgumentParser(description='Prepare the app of the test site.')
    parser.add_argument('app')
    parser.add_argument('--boot-version', default='')
    parser.add_argument('--security', choices=['on', 'off'], default='on')
    args = parser.parse_args()
    if not os.path.isfile(os.path.join(args.app, 'pom.xml')):
        fail('%s is not an app built with Maven (no pom.xml).' % args.app)
    if args.boot_version:
        set_boot_version(args.app, args.boot_version)
    if args.security == 'on':
        add_security(args.app)


if __name__ == '__main__':
    main()
