#!/usr/bin/env bash

# workspace-name: Spring Boot (a new app or the PetClinic sample, with Spring Security)

# Installed by the Spring Boot plugin (plugins.sh --install spring-boot); __WORKSPACE__ is the workspace it was installed into.
#
# Build a Spring Boot app in a container: a new app made with Spring Initializr, or the Spring PetClinic sample with
# --petclinic, at the current Spring Boot release, built with its own Maven wrapper on the current long-term-support
# JDK and run as a production jar by the web container at https://<name>.ddev.site. With --install Spring Security is
# added (form login with the generated login and logout pages, remember-me, the role rules); with --add-users the app
# also gets the default accounts.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="spring_boot";
distribution_title="Spring Boot";
distribution_webroot="app";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} project in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/spring-boot/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/spring-boot/args/arg-spring-boot.sh || exit 1 ;

shift $#;

spring_boot_build ;
