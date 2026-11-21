#!/usr/bin/env bash

# Installed by the Spring Boot plugin (plugins.sh --install spring-boot); __WORKSPACE__ is the workspace it was installed into.
#
# The Maven wrapper and the run of one Spring Boot app of this workspace, in its web container: say what the app is,
# run the wrapper's goals, build the jar again, restart the app, show its log, add or cancel the default accounts.
# Nothing here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="spring_boot";

ARGPARSE_DESCRIPTION="Run the Maven wrapper of a Spring Boot app of __WORKSPACE__: status, its goals, a rebuild, a restart, its log, the default accounts"
# The args file comes with the plugin: core/scripts/plugins/spring-boot/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/spring-boot/args/arg-spring-boot-cli.sh || exit 1 ;

shift $#;

spring_boot_cli_tool ;
