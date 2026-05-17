package com.reboot.patterns.p1.gateway.config;

import org.springframework.cloud.gateway.route.RouteLocator;
import org.springframework.cloud.gateway.route.builder.RouteLocatorBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

// Defines all gateway routes for Pattern 1.
// Each route matches an incoming path prefix and forwards to the matching
// Kubernetes Service using lb:// (load-balanced via Spring Cloud Kubernetes Discovery).
// When a K8s Service named "order" exists in the namespace, lb://order resolves to its ClusterIP.
@Configuration
public class RouteConfig {

    @Bean
    public RouteLocator gatewayRoutes(RouteLocatorBuilder builder) {
        return builder.routes()

                // /order/** → K8s Service "order" (selector: app=wiremock for now)
                .route("order-route", r -> r
                        .path("/order/**")
                        .uri("lb://order"))

                // /payment/** → K8s Service "payment"
                .route("payment-route", r -> r
                        .path("/payment/**")
                        .uri("lb://payment"))

                // /inventory/** → K8s Service "inventory"
                .route("inventory-route", r -> r
                        .path("/inventory/**")
                        .uri("lb://inventory"))

                // /shipping/** → K8s Service "shipping"
                .route("shipping-route", r -> r
                        .path("/shipping/**")
                        .uri("lb://shipping"))

                // /notification/** → K8s Service "notification"
                .route("notification-route", r -> r
                        .path("/notification/**")
                        .uri("lb://notification"))

                .build();
    }
}
