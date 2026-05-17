package com.reboot.patterns.p1.gateway.config;

import org.springframework.boot.web.reactive.error.ErrorWebExceptionHandler;
import org.springframework.cloud.gateway.route.Route;
import org.springframework.cloud.gateway.support.ServerWebExchangeUtils;
import org.springframework.core.annotation.Order;
import org.springframework.core.io.buffer.DataBuffer;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import java.nio.charset.StandardCharsets;

// Converts connection failures and timeouts into a machine-readable 503 JSON response.
// Without this, Spring Boot's default Whitelabel Error page returns HTML on routing failures,
// which breaks any API client expecting JSON. @Order(-1) gives this handler highest precedence.
@Component
@Order(-1)
public class GatewayErrorHandler implements ErrorWebExceptionHandler {

    @Override
    public Mono<Void> handle(ServerWebExchange exchange, Throwable ex) {
        // Only handle errors that indicate the downstream service is unreachable.
        // All other errors (e.g. 404 from the gateway itself) fall through to the default handler.
        if (!isDownstreamFailure(ex)) {
            return Mono.error(ex);
        }

        // Extract the downstream service name from the route attribute.
        // The route URI is lb://order, lb://payment, etc. — getHost() returns the service name.
        String downstream = "unknown";
        Route route = exchange.getAttribute(ServerWebExchangeUtils.GATEWAY_ROUTE_ATTR);
        if (route != null && route.getUri() != null) {
            downstream = route.getUri().getHost();
        }

        var response = exchange.getResponse();
        response.setStatusCode(HttpStatus.SERVICE_UNAVAILABLE);
        response.getHeaders().setContentType(MediaType.APPLICATION_JSON);

        String body = String.format(
                "{\"status\":503,\"error\":\"Service unavailable\",\"downstream\":\"%s\"}",
                downstream
        );

        DataBuffer buffer = response.bufferFactory().wrap(body.getBytes(StandardCharsets.UTF_8));
        return response.writeWith(Mono.just(buffer));
    }

    /**
     * Walk the exception cause chain looking for any exception type that signals
     * the downstream service is unreachable or timed out.
     *
     * Spring Cloud Gateway wraps routing exceptions in ResponseStatusException, so we
     * must inspect getCause() recursively to find the root cause.
     */
    private boolean isDownstreamFailure(Throwable ex) {
        Throwable current = ex;
        while (current != null) {
            if (current instanceof org.springframework.cloud.gateway.support.NotFoundException) {
                return true;
            }
            if (current instanceof io.netty.channel.ConnectTimeoutException) {
                return true;
            }
            if (current instanceof java.util.concurrent.TimeoutException) {
                return true;
            }
            if (current instanceof java.net.ConnectException) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }
}
