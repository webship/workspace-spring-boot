package org.springframework.samples.petclinic.system;

import java.util.ArrayList;
import java.util.List;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;

/**
 * The security of the test app, added by the build of the test site (the step pack's build script, or
 * the Webship Workspace's builder), in the package of the app's main class: form login with the
 * generated login and logout pages, remember-me, CSRF protection (on, as by default), and in-memory
 * accounts named after their roles.
 *
 * <ul>
 * <li>{@code app.security.public-paths}: the paths anybody may open (by default the error page and the
 * health and info endpoints).</li>
 * <li>{@code app.security.admin-paths}: the paths only the ADMIN role may open (by default /admin/** and
 * the other management endpoints).</li>
 * <li>Any other path needs a signed-in account.</li>
 * </ul>
 *
 * The accounts come from the app's configuration (config/accounts.properties, written by the build):
 * {@code app.accounts} lists them, {@code app.account.<name>.password} holds each one's password hash
 * and {@code app.account.<name>.roles} its roles.
 */
@Configuration(proxyBeanMethods = false)
class SecurityConfiguration {

	@Bean
	SecurityFilterChain securityFilterChain(HttpSecurity http, Environment environment) throws Exception {
		String[] open = environment.getProperty("app.security.public-paths", String[].class,
				new String[] { "/error", "/actuator/health", "/actuator/health/**", "/actuator/info" });
		String[] admin = environment.getProperty("app.security.admin-paths", String[].class,
				new String[] { "/admin/**", "/actuator/**" });
		http.authorizeHttpRequests((requests) -> requests.requestMatchers(open)
			.permitAll()
			.requestMatchers(admin)
			.hasRole("ADMIN")
			.anyRequest()
			.authenticated())
			.formLogin(Customizer.withDefaults())
			.rememberMe((rememberMe) -> rememberMe.key(environment.getRequiredProperty("app.remember-me.key")))
			.logout(Customizer.withDefaults());
		return http.build();
	}

	@Bean
	UserDetailsService userDetailsService(Environment environment) {
		List<UserDetails> users = new ArrayList<>();
		for (String name : environment.getProperty("app.accounts", String[].class, new String[0])) {
			String password = environment.getRequiredProperty("app.account." + name + ".password");
			String[] roles = environment.getProperty("app.account." + name + ".roles", String[].class, new String[0]);
			users.add(User.withUsername(name).password(password).roles(roles).build());
		}
		return new InMemoryUserDetailsManager(users);
	}

}
