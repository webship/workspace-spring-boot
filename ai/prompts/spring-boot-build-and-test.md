Build the Spring PetClinic sample with Spring Security and its default accounts in a sites folder and prove it with its first webship-js feature.

The launch command below is for Claude Code, the default; the text between the triple quotes can be given to another AI CLI as it is.

```
claude --permission-mode bypassPermissions """
Build the Spring PetClinic sample named <name> with Spring Security and its default accounts in this sites folder and test it with webship-js
# ~/workspace/<dev|test|sandboxes|demos> · https://<name>.ddev.site · container-based (DDEV by default)
# the builder deletes a project of the same name first: stop if <name> is an app somebody still needs
# about 500 MB of memory once it runs, about five minutes the first time: check free -g first, build one app at a time
# nothing on the host: no java, mvn or Maven wrapper outside the containers; no public domain, no account anywhere
# a feature to write or a run to read: the book Automated Functional Testing Recipes first (its README.md, then the matching chapter), from .claude/automated-functional-testing-recipes/ in the project, ~/.claude/automated-functional-testing-recipes/ or https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes

1. bash cmd-spring-boot-project.sh <name> --petclinic --install --add-users
   (the JDK's image, the sample, Spring Security, the accounts, the jar built with the sample's own Maven wrapper)
2. bash cmd-tools-spring-boot-cli.sh <name>
   tell me the Spring Boot release, the JDK, the addresses and the accounts it lists
3. bash cmd-tools-testing.sh <name>
   webship-js, the step pack, the users registry and tests/features/site.feature
4. bash cmd-tools-testing.sh <name> --dry-run --path tests/features/site.feature
5. bash cmd-tools-testing.sh <name> --run --path tests/features/site.feature

If a command fails, show the line that failed and stop. Do not retry with other flags.
When the feature is green: the address, the versions, how many scenarios and steps passed.
Then ask me whether to keep the app or remove it with: bash cmd-tools-remove.sh <name>
"""
```
