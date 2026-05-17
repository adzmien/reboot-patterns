package com.reboot.patterns.p1.gateway;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

// Entry point for Pattern 1 — API Gateway.
// Spring Cloud Gateway runs on Netty (reactive); there is no servlet container.
@SpringBootApplication
public class GatewayApplication {

    public static void main(String[] args) {
        SpringApplication.run(GatewayApplication.class, args);
    }
}
