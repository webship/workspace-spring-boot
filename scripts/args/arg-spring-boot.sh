#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its DDEV project and its host name.')
parser.add_argument('-p', '--petclinic',
                    action='store_true',
                    default=False,
                    help='Build the Spring PetClinic sample (owners, pets, visits, forms with validation, its own error page) instead of a new app made with Spring Initializr.')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Add Spring Security: form login with the generated login and logout pages, remember-me, the role rules, and in-memory accounts. Without it the app is built as it is, with no login.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts (administrator with the ADMIN role, user with the USER role): the ones the test scenarios log in as.')
parser.add_argument('-s', '--spring-boot-version',
                    default="",
                    help='The Spring Boot release of the app, 4.2.0 by default. Example: --spring-boot-version 4.1.3')
parser.add_argument('-j', '--java-version',
                    default="",
                    help='The JDK, a major release of Eclipse Temurin, 25 (the current long-term-support one) by default. Example: --java-version 21')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the app in a browser when it is ready.')
ARGEOF
