#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The Spring Boot project in this workspace.')
parser.add_argument('-m', '--mvnw',
                    default="_none_",
                    help='Goals and options of the app\'s Maven wrapper, run in the web container. Example: --mvnw "test" or --mvnw "dependency:tree"')
parser.add_argument('-r', '--rebuild',
                    action='store_true',
                    default=False,
                    help='Build the app\'s jar again with its wrapper and restart the app (after a change to its code).')
parser.add_argument('--restart',
                    action='store_true',
                    default=False,
                    help='Restart the app, and wait for it.')
parser.add_argument('--logs',
                    action='store_true',
                    default=False,
                    help='Show the end of the log of the app\'s web container.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Write the default accounts into the app and restart it. An account that is already there gets its password and role back.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Take the default accounts out of the app and restart it (its other accounts stay).')
ARGEOF
