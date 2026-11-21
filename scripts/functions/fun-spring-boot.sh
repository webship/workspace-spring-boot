#!/usr/bin/env bash

# Spring Boot for the Webship Workspace: build a Spring Boot app (a new one made with Spring Initializr, or the
# Spring PetClinic sample), add Spring Security and its default accounts, run the Maven wrapper's tasks, and wire
# its step pack into the testing setup.
#
# Placed by `plugins.sh --install spring-boot` in core/scripts/plugins/spring-boot/functions/, where bootstrap
# sources it after the core's own functions. Everything runs in containers (DDEV by default), never on the host:
# the JDK is Eclipse Temurin's, copied from its official image into the project's web image; the app is built with
# its own Maven wrapper in the web container (the downloads stay in the project, .m2/) and runs there as a daemon,
# a production jar, with the router of the container tool sending the project's address to its port. No public
# domain, no hosted service, no account anywhere.
#
# DDEV has no project type for Spring Boot, so an app of this plugin is a generic project that the plugin claims
# with a file of its own (.ddev/config.spring-boot.yaml, written by the builder: the daemon of the app, its port, the
# Maven settings), and four names are the ones the core's tools look for (the claim file's name with its dash as an
# underscore):
#   set_spring_boot_users          the default accounts                     (cmd-tools-add-users.sh <project> spring_boot)
#   add_spring_boot_users          write them into the app and restart it   (the same tool, and --add-users of the builder)
#   cancel_spring_boot_users       take them out again                      (cmd-tools-cancel-users.sh <project> spring_boot)
#   testing_configure_spring_boot  the step pack in the testing stack       (cmd-tools-testing.sh <project>)

# The step pack a Spring Boot app is tested with, and the release line it is required at.
readonly SPRING_BOOT_STEPS_PACKAGE='@webship-js/spring-boot-steps';
readonly SPRING_BOOT_STEPS_VERSION='^2.0.0';

# The Spring Boot release the builder makes an app at when none is asked for, the JDK (a major release of Eclipse
# Temurin, the current long-term-support one), and the commit of the PetClinic sample this plugin was proven on.
readonly SPRING_BOOT_DEFAULT_VERSION='4.2.0';
readonly SPRING_BOOT_DEFAULT_JAVA='25';
readonly SPRING_BOOT_PETCLINIC_REF='500158f732419217507c7656904b8e6aa1bcc0d6';

# Where the project lives in the web container, and the port the app listens on.
readonly SPRING_BOOT_ROOT='/var/www/html';
readonly SPRING_BOOT_PORT='8080';

# The default accounts, the ones a scenario logs in as: in-memory accounts of the app named after their roles.
# Accounts are configuration, written once into the app (config/accounts.properties, password hashes only); a test
# suite never creates or deletes one. An app built without --install has no login, so no place for them.
function set_spring_boot_users() {
  users=(administrator user);
  local user ;
  for user in "${users[@]}" ; do
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
  done
  user_administrator_role='ADMIN' ;
  user_user_role='USER' ;
}

# Is this folder a Spring Boot app of this plugin? The builder leaves .ddev/config.spring-boot.yaml in it.
function spring_boot_is_project() {
  [ -f "$1/.ddev/config.spring-boot.yaml" ] ;
}

# Go to the project a tool was asked about, or say why not.
function spring_boot_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! spring_boot_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a Spring Boot app of this plugin (it has no .ddev/config.spring-boot.yaml)." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# Is the app of a project the PetClinic sample? Its POM says so.
function spring_boot_is_petclinic() {
  grep -q '<artifactId>spring-petclinic</artifactId>' "${1:-.}/app/pom.xml" 2>/dev/null ;
}

# Has the app of a project a login (Spring Security, added by --install)?
function spring_boot_has_security() {
  grep -q 'spring-boot-starter-security' "${1:-.}/app/pom.xml" 2>/dev/null ;
}

# What the container tool is told about the app: the router sends ports 80 and 443 of the project's address to the
# app's port, the web container runs the app's jar as a daemon once it is built (app.jar), Maven keeps its downloads
# in the project, and the JDK is in the web image. This file is also the plugin's claim on the project.
function spring_boot_write_ddev_config() {
  local project_path="$1" java_version="$2" ;
  mkdir -p "${project_path}/.ddev/web-build" || return 1 ;
  cat > "${project_path}/.ddev/config.spring-boot.yaml" <<YAMLEOF
# Spring Boot in this project, and the claim of the workspace's Spring Boot plugin on it. Written by the Spring
# Boot builder of the workspace; build again rather than editing by hand. The web container serves no files of its
# own: the router sends ports 80 and 443 of the project's address to the app, which the web container runs as a
# daemon once its jar is built (app.jar). Maven keeps its downloads in the project (.m2/).
web_extra_exposed_ports:
  - name: spring-boot
    container_port: ${SPRING_BOOT_PORT}
    http_port: 80
    https_port: 443
web_extra_daemons:
  - name: spring-boot
    command: "bash -c 'while [ ! -f ${SPRING_BOOT_ROOT}/app.jar ]; do sleep 2; done; exec java -Xms128m -Xmx512m -jar ${SPRING_BOOT_ROOT}/app.jar'"
    directory: ${SPRING_BOOT_ROOT}/app
web_environment:
  - MAVEN_USER_HOME=${SPRING_BOOT_ROOT}/.m2
  - MAVEN_OPTS=-Dmaven.repo.local=${SPRING_BOOT_ROOT}/.m2/repository
YAMLEOF
  cat > "${project_path}/.ddev/web-build/Dockerfile.spring-boot" <<DOCKEREOF
# The JDK of the app: Eclipse Temurin ${java_version}, copied from its official image. Written by the Spring Boot
# builder of the workspace.
COPY --from=eclipse-temurin:${java_version}-jdk /opt/java/openjdk /opt/java/openjdk
ENV JAVA_HOME=/opt/java/openjdk
RUN for tool in java javac jar jshell; do ln -sf /opt/java/openjdk/bin/\$tool /usr/local/bin/\$tool; done && java -version
DOCKEREOF
}

# How the app runs in the project (app/config/application.properties, which the app reads from its working folder):
# behind the router's HTTPS, and with a login the health details for the ADMIN role, a remember-me key of its own, the
# accounts file, and for the sample which of its pages anybody may open and which only the ADMIN role.
function spring_boot_write_settings() {
  local project_path="$1" security="$2" ;
  mkdir -p "${project_path}/app/config" || return 1 ;
  {
    echo "# The settings of the app's run in this project. Written by the Spring Boot builder of the workspace."
    echo "server.forward-headers-strategy=native"
    if [ "${security}" == 'yes' ] ; then
      if spring_boot_is_petclinic "${project_path}" ; then
        echo "app.security.public-paths=/,/resources/**,/webjars/**,/error,/oups,/vets,/vets.html,/actuator/health,/actuator/health/**,/actuator/info"
        echo "app.security.admin-paths=/owners/new,/owners/*/edit,/owners/*/pets/new,/owners/*/pets/*/edit,/actuator/**"
      fi
      echo "management.endpoint.health.show-details=when-authorized"
      echo "management.endpoint.health.roles=ADMIN"
      echo "app.remember-me.key=$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32)"
      echo "spring.config.import=optional:file:./config/accounts.properties"
    fi
  } > "${project_path}/app/config/application.properties" ;
}

# A bcrypt hash of a password, made by PHP in the web container from its standard input (no password on a command
# line), in the form Spring Security's delegating password encoder reads.
function spring_boot_hash() {
  printf '%s' "$1" | ddev exec "php -r 'echo password_hash(stream_get_contents(STDIN), PASSWORD_BCRYPT);'" | tr -d '\r\n' | sed 's/^/{bcrypt}/' ;
}

# The accounts of the app (app/config/accounts.properties): the ones of the file that are not the default ones, then
# the default accounts of the list set_spring_boot_users loads, when `with_defaults` is yes.
function spring_boot_write_accounts() {
  local with_defaults="$1" file="app/config/accounts.properties" defaults=" " user name password role hash names="" body="" ;
  for user in "${users[@]}" ; do name="user_${user}_name"; defaults="${defaults}${!name} "; done
  # The accounts of the file that this list does not hold stay as they are.
  local kept="" account ;
  if [ -f "${file}" ] ; then
    for account in $(sed -n 's/^app\.accounts=//p' "${file}" | tr ',' ' ') ; do
      case "${defaults}" in *" ${account} "*) continue ;; esac
      names="${names:+${names},}${account}" ;
      kept="${kept}$(grep -E "^app\.account\.${account}\.(password|roles)=" "${file}")"$'\n' ;
    done
  fi
  if [ "${with_defaults}" == 'yes' ] ; then
    for user in "${users[@]}" ; do
      name="user_${user}_name"; password="user_${user}_password"; role="user_${user}_role";
      hash="$(spring_boot_hash "${!password}")" ;
      case "${hash}" in '{bcrypt}$2'*) ;; *) echo "  The password hash of ${!name} could not be made in the web container." ; return 1 ;; esac
      names="${names:+${names},}${!name}" ;
      body="${body}app.account.${!name}.password=${hash}"$'\n'"app.account.${!name}.roles=${!role}"$'\n' ;
    done
  fi
  {
    echo "# The accounts of the app: in-memory accounts, read by its security configuration at its start. Written by the"
    echo "# Spring Boot plugin of the workspace (cmd-tools-spring-boot-cli.sh <project> --add-users / --cancel-users)."
    echo "app.accounts=${names}"
    printf '%s' "${kept}" | sed '/^$/d'
    printf '%s' "${body}"
  } > "${file}" ;
}

# The Maven wrapper of the app in the web container, in the app's folder, with the downloads in the project.
function spring_boot_mvnw() {
  ddev exec -d "${SPRING_BOOT_ROOT}/app" "./mvnw -B -ntp -Dmaven.repo.local=${SPRING_BOOT_ROOT}/.m2/repository $*" < /dev/null ;
}

# Build the app's jar with its wrapper (no tests, none of the sample's style checks) and put it where the daemon runs it.
function spring_boot_package() {
  spring_boot_mvnw "-DskipTests -Dcheckstyle.skip=true -Dspring-javaformat.skip=true -Djacoco.skip=true package" || return 1 ;
  ddev exec "cp \"\$(ls ${SPRING_BOOT_ROOT}/app/target/*.jar | head -n 1)\" ${SPRING_BOOT_ROOT}/app.jar" < /dev/null ;
}

# Restart the app's daemon in the web container.
function spring_boot_restart() {
  ddev exec "supervisorctl restart webextradaemons:spring-boot" < /dev/null > /dev/null ;
}

# Wait until the app says it is up (its health endpoint, from inside the web container).
function spring_boot_wait() {
  local attempt ;
  for attempt in $(seq 1 150) ; do
    if ddev exec "curl -fsS http://127.0.0.1:${SPRING_BOOT_PORT}/actuator/health" < /dev/null 2>/dev/null | grep -q '"status":"UP"' ; then
      return 0 ;
    fi
    sleep 2 ;
  done
  echo "The app did not come up; the end of the web container's log:" ;
  ddev logs --tail 60 < /dev/null 2>/dev/null ;
  return 1 ;
}

# The Spring Boot release and the JDK the app runs on, as its jar and the container say them.
function spring_boot_versions() {
  local boot java ;
  boot="$(ddev exec "unzip -p ${SPRING_BOOT_ROOT}/app.jar META-INF/MANIFEST.MF" < /dev/null 2>/dev/null | sed -n 's/^Spring-Boot-Version: *//p' | tr -d '\r')" ;
  # sed reads the whole output: a head that stops early would cut the pipe of the container tool.
  java="$(ddev exec "java -version 2>&1" < /dev/null 2>/dev/null | tr -d '\r' | sed -n '1p')" ;
  echo "Spring Boot ${boot:-(unknown)} on ${java:-(unknown JDK)}" ;
}

# Build a Spring Boot app from nothing: the project, the JDK in its web image, the app (a new one from Spring
# Initializr, or the sample with --petclinic), with --install Spring Security and its accounts file, with
# --add-users the default accounts; then the jar built with the app's wrapper and started.
function spring_boot_build() {
  trim_project_name ;
  local base_url="https://${PROJECT_NAME}.ddev.site" ;
  local version="${SPRING_BOOT_VERSION:-${SPRING_BOOT_DEFAULT_VERSION}}" ;
  local java_version="${JAVA_VERSION:-${SPRING_BOOT_DEFAULT_JAVA}}" ;
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" ;
  local security='no' kind="a new app from Spring Initializr" ;
  [ "${INSTALL}" == 'yes' ] && security='yes' ;
  [ "${PETCLINIC}" == 'yes' ] && kind="the Spring PetClinic sample" ;

  if ! [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
    echo "--spring-boot-version takes a release (4.2.0), not ${version}. Nothing was changed." ;
    exit 1 ;
  fi
  if ! [[ "${java_version}" =~ ^[0-9]+$ ]] ; then
    echo "--java-version takes a major release of the JDK (25), not ${java_version}. Nothing was changed." ;
    exit 1 ;
  fi
  if [ "${ADD_USERS}" == 'yes' ] && [ "${INSTALL}" != 'yes' ] ; then
    echo "--add-users needs --install: the default accounts go into the login --install adds." ;
    exit 1 ;
  fi
  if [ ${#PROJECT_NAME} -gt 40 ] || ! [[ "${PROJECT_NAME}" =~ ^[a-z0-9][a-z0-9-]*$ ]] ; then
    echo "The project name ${PROJECT_NAME} must be small letters, digits and dashes (its address and its container take it). Nothing was changed." ;
    exit 1 ;
  fi
  local prepare="${WORKSPACE_SCRIPTS}/plugins/spring-boot/spring-boot-prepare-app.py" ;
  if [ ! -f "${prepare}" ] ; then
    echo "spring-boot-prepare-app.py is not in ${WORKSPACE_SCRIPTS}/plugins/spring-boot: install the plugin (plugins.sh --install spring-boot)." ;
    exit 1 ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  # A project of the same name goes first, with its containers.
  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}" ;
  cd "${project_path}" || exit 1 ;

  if [ "${PETCLINIC}" == 'yes' ] ; then
    echo "Fetching the Spring PetClinic sample (${SPRING_BOOT_PETCLINIC_REF})." ;
    git init -q app && git -C app fetch -q --depth 1 https://github.com/spring-projects/spring-petclinic.git "${SPRING_BOOT_PETCLINIC_REF}" \
      && git -C app checkout -q FETCH_HEAD || { echo "The sample could not be fetched." ; exit 1 ; } ;
    python3 "${prepare}" app --boot-version "${version}" --security "$([ "${security}" == 'yes' ] && echo on || echo off)" || exit 1 ;
  else
    echo "Making a new app with Spring Initializr (start.spring.io): Spring Boot ${version}, Java ${java_version}." ;
    local dependencies="web,thymeleaf,validation,actuator,data-jpa,h2" ;
    [ "${security}" == 'yes' ] && dependencies="${dependencies},security" ;
    curl -fsSL -o app.zip "https://start.spring.io/starter.zip?type=maven-project&language=java&bootVersion=${version}&baseDir=app&groupId=com.example&artifactId=demo&name=demo&description=A%20new%20app&packageName=com.example.demo&javaVersion=${java_version}&dependencies=${dependencies}" \
      || { echo "Spring Initializr made no app for Spring Boot ${version} and Java ${java_version}: is that release one it offers?" ; exit 1 ; } ;
    unzip -q app.zip && rm -f app.zip || exit 1 ;
    if [ "${security}" == 'yes' ] ; then
      python3 "${prepare}" app --security on || exit 1 ;
    fi
  fi

  # A generic project: the web container runs the app's jar as a daemon and the router sends the project's address
  # to its port; no database of the container tool's own (the app keeps its data in memory), the Node.js of the
  # workspace rule for a test suite run in the web container.
  ddev config --project-type=generic --webserver-type=generic --docroot=app --project-name=${PROJECT_NAME} \
    --omit-containers=db --nodejs-version=$(ddev_nodejs_version) < /dev/null || exit 1 ;
  spring_boot_write_ddev_config "${project_path}" "${java_version}" || exit 1 ;
  spring_boot_write_settings "${project_path}" "${security}" || exit 1 ;

  echo "Starting the project: the JDK's image (eclipse-temurin:${java_version}-jdk) is about 160 MB the first time." ;
  ddev_up start -y < /dev/null || exit 1 ;
  if [ "${security}" == 'yes' ] ; then
    if [ "${ADD_USERS}" == 'yes' ] ; then
      set_spring_boot_users ;
      spring_boot_write_accounts yes || exit 1 ;
    else
      users=() ;
      spring_boot_write_accounts no || exit 1 ;
    fi
  fi
  echo "Building the app with its own Maven wrapper (the first build downloads Maven and the app's libraries into .m2/)." ;
  spring_boot_package || { echo "The app could not be built." ; exit 1 ; } ;
  echo "Waiting for the app." ;
  spring_boot_wait || exit 1 ;

  echo "${doc_name} ${PROJECT_NAME} has been built: ${kind}, $(spring_boot_versions), at ${base_url}." ;
  if [ "${security}" == 'yes' ] ; then
    echo "The login: ${base_url}/login (the page Spring Security generates) · the health: ${base_url}/actuator/health" ;
    if [ "${ADD_USERS}" == 'yes' ] ; then
      echo "The default accounts: administrator (ADMIN) and user (USER), with the workspace's shared password." ;
    else
      echo "No account yet: add the default ones with cmd-tools-spring-boot-cli.sh ${PROJECT_NAME} --add-users." ;
    fi
  else
    echo "Without a login (built without --install). The health: ${base_url}/actuator/health" ;
  fi
  users=() ;

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch "${base_url}" ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Write the default accounts into the app (an account already there gets its password and role back) and restart
# it: its accounts are read at its start. The list is loaded by the caller (set_spring_boot_users): the core's
# add_users, the builder, the tool.
function add_spring_boot_users() {
  spring_boot_enter_project || return 1 ;
  if ! spring_boot_has_security ; then
    echo "${PROJECT_NAME} has no login (it was built without --install): its accounts would have nowhere to go." ;
    cd ${WORKSPACE_ROOT}/${doc_name}; return 1 ;
  fi
  local user user_name user_mail user_password user_role ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role}";
    echo " ================================================================= ";
  done
  local status=0 ;
  spring_boot_write_accounts yes && spring_boot_restart && spring_boot_wait > /dev/null || status=1 ;
  [ ${status} -eq 0 ] && echo "The app has restarted with the accounts: $(sed -n 's/^app\.accounts=//p' app/config/accounts.properties)." ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# Take the default accounts out of the app (the other accounts of its file stay) and restart it.
function cancel_spring_boot_users() {
  spring_boot_enter_project || return 1 ;
  if ! spring_boot_has_security ; then
    echo "${PROJECT_NAME} has no login (it was built without --install): it has no accounts." ;
    cd ${WORKSPACE_ROOT}/${doc_name}; return 1 ;
  fi
  local user user_name ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo " ================================================================= ";
  done
  local status=0 ;
  spring_boot_write_accounts no && spring_boot_restart && spring_boot_wait > /dev/null || status=1 ;
  [ ${status} -eq 0 ] && echo "The app has restarted with the accounts: $(sed -n 's/^app\.accounts=//p' app/config/accounts.properties | sed 's/^$/(none)/')." ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# What cmd-tools-spring-boot-cli.sh does: the first of --mvnw, --rebuild, --restart, --logs, --add-users,
# --cancel-users that was asked for; with none of them, what the app is.
function spring_boot_cli_tool() {
  trim_project_name ;
  spring_boot_enter_project || exit 1 ;

  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y < /dev/null || exit 1 ;
  fi

  if [ ! "${MVNW}" == '_none_' ] ; then
    spring_boot_mvnw "${MVNW}" ;
    exit $? ;
  fi

  if [ "${REBUILD}" == 'yes' ] ; then
    spring_boot_package || exit 1 ;
    spring_boot_restart && spring_boot_wait || exit 1 ;
    echo "${PROJECT_NAME} is built again and running: $(spring_boot_versions)." ;
  elif [ "${RESTART}" == 'yes' ] ; then
    spring_boot_restart && spring_boot_wait || exit 1 ;
    echo "${PROJECT_NAME} is running again: $(spring_boot_versions)." ;
  elif [ "${LOGS}" == 'yes' ] ; then
    ddev logs --tail 200 < /dev/null ;
  elif [ "${ADD_USERS}" == 'yes' ] ; then
    set_spring_boot_users ;
    add_spring_boot_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    set_spring_boot_users ;
    cancel_spring_boot_users ;
  else
    local kind="a new app from Spring Initializr" ;
    spring_boot_is_petclinic && kind="the Spring PetClinic sample" ;
    echo "${doc_name}/${PROJECT_NAME}: ${kind}, $(spring_boot_versions)" ;
    echo "  the app:    https://${PROJECT_NAME}.ddev.site" ;
    echo "  the health: https://${PROJECT_NAME}.ddev.site/actuator/health" ;
    if spring_boot_has_security ; then
      echo "  the login:  https://${PROJECT_NAME}.ddev.site/login (Spring Security's generated page)" ;
      local accounts ;
      accounts="$(sed -n 's/^app\.accounts=//p' app/config/accounts.properties 2>/dev/null)" ;
      echo "Accounts: ${accounts:-(none)}" ;
      local account role ;
      for account in $(echo "${accounts}" | tr ',' ' ') ; do
        role="$(sed -n "s/^app\.account\.${account}\.roles=//p" app/config/accounts.properties)" ;
        echo "  ${account} (${role:-no role})" ;
      done
    else
      echo "  no login (built without --install)" ;
    fi
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a Spring Boot app. The core's testing_configure calls this in the project
# folder once webship-js is scaffolded and before the dependencies are installed; for a project that is not one of
# this plugin's it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's own, gives cucumber.js
# the tags that keep the pack's assertions that must fail out of a normal run, the pages of the app the steps need
# (the login and logout pages, a page only a signed-in account may open, the health and info endpoints), the browser
# messages the pack's scenarios turn off, and the users registry of the default accounts (a handle a scenario reads,
# mapped to an account), and writes a first feature when the project has none of its own. Every part is skipped when
# it is already there, so a second run adds what the first missed and never resets a suite.
function testing_configure_spring_boot() {
  local project_path="$1";
  spring_boot_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  Spring Boot: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the Spring Boot step pack (${SPRING_BOOT_STEPS_PACKAGE} ${SPRING_BOOT_STEPS_VERSION}).";
  set_spring_boot_users ;
  local registry="" user user_name user_password ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_password="user_${user}_password";
    registry="${registry}${user}|${!user_name}|${!user_password}"$'\n' ;
  done

  local site_name protected='/' ;
  site_name="$(sed -n 's/^name:[[:space:]]*"\{0,1\}\([A-Za-z0-9._-]*\)"\{0,1\}[[:space:]]*$/\1/p' "${project_path}/.ddev/config.yaml" | head -n 1)" ;
  spring_boot_is_petclinic "${project_path}" && protected='/owners/find' ;

  python3 - "${project_path}" "${SPRING_BOOT_STEPS_PACKAGE}" "${SPRING_BOOT_STEPS_VERSION}" 'SPRING_BOOT' "${registry}" "https://${site_name:-${PROJECT_NAME}}.ddev.site" "${protected}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry, address, protected = sys.argv[1:8]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=4) + '\n')
    print('  package.json: %s %s' % (pack, version))

cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

if not re.search(r"^[ \t]*tags:", src, re.M):
    default = re.search(r"^([ \t]*)default:[ \t]*\{[ \t]*$", src, re.M)
    if default:
        pad = default.group(1) + '  '
        block = [
            pad + "// The pack's assertions that must fail are no part of a normal run.",
            pad + "tags: process.env.CUCUMBER_TAGS || 'not @wip and not @must-fail',",
        ]
        src = src[:default.end()] + '\n' + '\n'.join(block) + src[default.end():]
        print('  cucumber.js: the tags that keep the assertions that must fail out of a normal run')

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not world:
    sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
pad = world.group(1) + '  '
additions = []
if not re.search(r"^[ \t]*loginPath:", src, re.M):
    additions += [
        pad + "// The pages of the app the steps need: the login and logout pages Spring Security generates, a page only a",
        pad + "// signed-in account may open (the steps ask it whether the browser is signed in), the health and info endpoints.",
        pad + "loginPath: '/login',",
        pad + "logoutPath: '/logout',",
        pad + "protectedPath: '%s'," % protected,
        pad + "healthPath: '/actuator/health',",
        pad + "infoPath: '/actuator/info',",
    ]
if not re.search(r"^[ \t]*javascript:", src, re.M):
    additions += [
        pad + "// The browser logs every error page it gets, and /favicon.ico, which the pages Spring Security generates ask for:",
        pad + "// the scenarios of the step pack that meet them carry @js-off.",
        pad + "javascript: { mode: process.env.WEBSHIP_JS_ERROR_MODE || 'warn', levels: ['error'], beforeScenario: false, afterScenario: true },",
    ]
if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    rows = [r.split('|') for r in registry.splitlines() if r.strip()]
    additions += [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of the app (the default accounts:",
        pad + "// cmd-tools-spring-boot-cli.sh --add-users). Override one with %s_<HANDLE>_USERNAME and %s_<HANDLE>_PASSWORD." % (prefix, prefix),
        pad + "users: {",
    ]
    for handle, username, password in rows:
        env = '%s_%s' % (prefix, handle.upper())
        additions.append(pad + "  %s: { username: process.env.%s_USERNAME || '%s', password: process.env.%s_PASSWORD || '%s' }," % (handle, env, username, env, password))
    additions.append(pad + "},")
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))
if additions:
    src = src[:world.end()] + '\n' + '\n'.join(additions) + src[world.end():]
    print('  cucumber.js: the pages of the app the steps need')

# The address the suite opens when LAUNCH_URL is not set: the placeholder of the scaffold becomes the app's.
placeholder = "process.env.LAUNCH_URL || 'http://localhost:8080'"
if placeholder in src:
    src = src.replace(placeholder, "process.env.LAUNCH_URL || '%s'" % address)
    print('  cucumber.js: the address of the app (%s)' % address)

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the app yet.
  local feature="${WORKSPACE_SCRIPTS}/plugins/spring-boot/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the login, the accounts and the health" ;
  fi

  # The scenarios log in as the default accounts: make sure an app with a login has them, once it answers again
  # (installing the webship-js add-on restarts the project, and the app with it).
  if spring_boot_has_security "${project_path}" ; then
    if ( cd "${project_path}" && spring_boot_wait > /dev/null 2>&1 && spring_boot_write_accounts yes > /dev/null 2>&1 && spring_boot_restart && spring_boot_wait > /dev/null 2>&1 ) ; then
      echo "  the default accounts are in the app (${users[*]})" ;
    else
      echo "  The default accounts could not be written: is the app running (ddev start in ${project_path})?" ;
    fi
  else
    echo "  ${PROJECT_NAME:-the app} has no login (built without --install): the login scenarios of tests/features/site.feature do not apply." ;
  fi
}
