package com.reboot.patterns.p1.gateway.filter;

import org.springframework.core.Ordered;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.http.server.reactive.ServerHttpResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import org.springframework.web.server.WebFilter;
import org.springframework.web.server.WebFilterChain;
import reactor.core.publisher.Mono;

import java.util.UUID;

// Ensures every request carries a correlation ID (X-Correlation-ID header).
// If the caller already supplies one we preserve it; otherwise we generate a UUID.
// The value is stored in exchange attributes so other filters (e.g. GatewayLoggingFilter)
// can read it without re-parsing the header.
@Component
public class CorrelationIdFilter implements WebFilter, Ordered {

    // Attribute key used to share the correlation ID across the filter chain.
    public static final String CORRELATION_ID_KEY = "X-Correlation-ID";
    private static final String HEADER_NAME = "X-Correlation-ID";

    // Must run before routing so the downstream request already carries the header.
    @Override
    public int getOrder() {
        return Ordered.HIGHEST_PRECEDENCE;
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
        ServerHttpRequest request = exchange.getRequest();

        // Preserve caller-supplied ID; generate a UUID only when absent.
        String correlationId = request.getHeaders().getFirst(HEADER_NAME);
        if (correlationId == null || correlationId.isBlank()) {
            correlationId = UUID.randomUUID().toString();
        }

        // Store in exchange attributes so GatewayLoggingFilter can read it.
        exchange.getAttributes().put(CORRELATION_ID_KEY, correlationId);

        // Capture for use in lambda (must be effectively final).
        final String resolvedId = correlationId;

        // Mutate the downstream request to include a single occurrence of the header.
        ServerHttpRequest mutatedRequest = request.mutate()
                .headers(headers -> {
                    headers.remove(HEADER_NAME);       // remove any existing value to prevent duplication
                    headers.add(HEADER_NAME, resolvedId);
                })
                .build();

        // Write the correlation ID back to the response so the caller sees it.
        ServerHttpResponse mutatedResponse = exchange.getResponse();
        mutatedResponse.getHeaders().set(HEADER_NAME, resolvedId);

        return chain.filter(exchange.mutate().request(mutatedRequest).build());
    }
}
