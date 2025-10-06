package com.example.oauth2demo.config;

import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.*;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.util.matcher.AntPathRequestMatcher;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.client.userinfo.OAuth2UserRequest;
import org.springframework.security.oauth2.client.userinfo.OAuth2UserService;
import org.springframework.security.oauth2.client.userinfo.DefaultOAuth2UserService;
import org.springframework.security.oauth2.core.OAuth2AccessToken;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.security.oauth2.core.user.DefaultOAuth2User;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.web.client.RestTemplate;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.AuthenticationSuccessHandler;
import org.springframework.security.web.csrf.CookieCsrfTokenRepository;

import java.io.IOException;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }

    @Bean
    public AuthenticationSuccessHandler oauth2SuccessHandler() {
        return new AuthenticationSuccessHandler() {
            @Override
            public void onAuthenticationSuccess(HttpServletRequest request, HttpServletResponse response,
                                              Authentication authentication) throws IOException {
                if (authentication.getPrincipal() instanceof OidcUser oidcUser) {
                    // 获取ID Token
                    String idToken = oidcUser.getIdToken().getTokenValue();
                    
                    // 创建HTTP Only Cookie存储ID Token
                    Cookie idTokenCookie = new Cookie("id_token", idToken);
                    idTokenCookie.setHttpOnly(true);
                    idTokenCookie.setSecure(true); // HTTPS环境下设置为true
                    idTokenCookie.setPath("/");
                    idTokenCookie.setMaxAge(3600); // 1小时过期
                    
                    response.addCookie(idTokenCookie);
                    
                    System.out.println("=== OAuth2 Authentication Success ===");
                    System.out.println("User: " + oidcUser.getFullName());
                    System.out.println("Email: " + oidcUser.getEmail());
                    System.out.println("ID Token stored in cookie");
                }
                
                // 重定向到默认成功URL
                response.sendRedirect("/test");
            }
        };
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            /*
             * === CSRF（跨站请求伪造）保护配置 ===
             * 
             * 什么是CSRF攻击？
             * - CSRF (Cross-Site Request Forgery) 是一种恶意攻击方式
             * - 攻击者诱导用户在已登录的网站上执行非预期的操作
             * - 例如：用户登录了银行网站，然后访问了恶意网站，恶意网站可能会
             *   发送转账请求到银行网站，由于用户已登录，请求会被执行
             * 
             * CSRF保护原理：
             * 1. 服务器为每个用户会话生成一个随机的CSRF Token
             * 2. 用户发送POST请求时，必须携带这个Token
             * 3. 服务器验证Token是否正确，不正确则拒绝请求
             * 4. 恶意网站无法获取到用户的CSRF Token，因此无法伪造请求
             * 
             * CookieCsrfTokenRepository.withHttpOnlyFalse() 配置说明：
             * - 将CSRF Token存储在Cookie中
             * - withHttpOnlyFalse() 允许JavaScript读取Cookie中的CSRF Token
             * - 这样前端JavaScript可以获取Token并在AJAX请求中使用
             */
            .csrf(csrf -> csrf
                .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
            )
            .authorizeHttpRequests(authz -> authz
                .requestMatchers("/", "/login/**", "/oauth2/**", "/css/**", "/js/**", "/images/**", "/static/**", "/error").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2Login(oauth2 -> oauth2
                .loginPage("/login")
                .successHandler(oauth2SuccessHandler())
                .userInfoEndpoint(userInfo -> userInfo
                    .userService(oauth2UserService())
                )
                .redirectionEndpoint(redirection -> redirection
                    .baseUri("/oauth2/callback")
                )
            )
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)
            )
            .logout(logout -> logout
                .logoutRequestMatcher(new AntPathRequestMatcher("/logout", "GET"))
                .logoutSuccessUrl("/")
                .invalidateHttpSession(true)
                .clearAuthentication(true)
                .deleteCookies("id_token", "JSESSIONID")
                .permitAll()
            );

        return http.build();
    }

    // 新增：自定义OAuth2用户服务
    @Bean
    public OAuth2UserService<OAuth2UserRequest, OAuth2User> oauth2UserService() {
        DefaultOAuth2UserService delegate = new DefaultOAuth2UserService();

        return userRequest -> {
            OAuth2User oauth2User = delegate.loadUser(userRequest);

            // 根据提供商类型处理用户信息
            String registrationId = userRequest.getClientRegistration().getRegistrationId();
            if ("github".equals(registrationId)) {
                return processGitHubUser(oauth2User, userRequest.getAccessToken());
            } else if ("google".equals(registrationId)) {
                return processGoogleUser(oauth2User);
            }

            return oauth2User;
        };
    }

    private OAuth2User processGitHubUser(OAuth2User oauth2User, OAuth2AccessToken accessToken) {
        Map<String, Object> attributes = new HashMap<>(oauth2User.getAttributes());

        // GitHub邮箱获取：如果主用户信息中没有邮箱，尝试获取用户的邮箱列表
        if (attributes.get("email") == null && accessToken.getScopes().contains("user:email")) {
            try {
                String email = getGitHubUserEmail(accessToken.getTokenValue());
                if (email != null) {
                    attributes.put("email", email);
                    System.out.println("Successfully retrieved GitHub user email: " + email);
                } else {
                    System.out.println("No verified primary email found for GitHub user: " + attributes.get("login"));
                }
            } catch (Exception e) {
                System.err.println("Failed to fetch GitHub user email: " + e.getMessage());
                // 不要因为邮箱获取失败而影响整个登录流程
                // 用户仍可以使用其他信息登录
            }
        }

        return new DefaultOAuth2User(
            oauth2User.getAuthorities(),
            attributes,
            "login"  // GitHub的用户名字段是"login"
        );
    }

    // 新增：获取GitHub用户邮箱的方法
    private String getGitHubUserEmail(String accessToken) throws Exception {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        headers.setAccept(Collections.singletonList(MediaType.APPLICATION_JSON));

        HttpEntity<?> entity = new HttpEntity<>(headers);

        ResponseEntity<List<Map<String, Object>>> response = restTemplate().exchange(
            "https://api.github.com/user/emails",
            HttpMethod.GET,
            entity,
            new ParameterizedTypeReference<List<Map<String, Object>>>() {}
        );

        if (response.getBody() != null) {
            // 查找主要且已验证的邮箱
            return response.getBody().stream()
                .filter(email -> Boolean.TRUE.equals(email.get("primary")) &&
                               Boolean.TRUE.equals(email.get("verified")))
                .findFirst()
                .map(email -> (String) email.get("email"))
                .orElse(null);
        }

        return null;
    }

    private OAuth2User processGoogleUser(OAuth2User oauth2User) {
        // Google用户处理保持现有逻辑
        return oauth2User;
    }

}
