package com.reboot.patterns.p1.gateway.filter;

import net.logstash.logback.marker.Markers;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.cloud.gateway.support.ServerWebExchangeUtils;
import org.springframework.core.Ordered;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import java.net.URI;

// Emits one structured JSON log line per gateway request, after the downstream responds.
// Fields: method, path, downstream (K8s service name), status, latencyMs, correlationId.
// Uses LogstashMarker so every field appears as a first-class JSON key — parseable by jq.
@Component
public class GatewayLoggingFilter implements GlobalFilter, Ordered {

    private static final Logger log = LoggerFactory.getLogger(GatewayLoggingFilter.class);

    // Run after routing filters so the route attributes (resolved URL, etc.) are populated.
    @Override
    public int getOrder() {
        return Ordered.LOWEST_PRECEDENCE;
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        long startMs = System.currentTimeMillis();
        ServerHttpRequest request = exchange.getRequest();
        String method = request.getMethod().name();
        String path = request.getURI().getPath();

        return chain.filter(exchange).then(
                // beforeCommit runs after the downstream has responded but before we flush
                // to the client — the status code is available at this point.
                Mono.fromRunnable(() -> {
                    long latencyMs = System.currentTimeMillis() - startMs;

                    // Resolve downstream service name from the lb:// URI that Spring Cloud
                    // Gateway stores after load-balancer resolution.
                    // The resolved URL host may be a full FQDN (e.g. order.reboot-patterns.svc.cluster.local)
                    // so we take only the first dot-separated segment to get the bare service name.
                    String downstream = "unknown";
                    URI requestUrl = exchange.getAttribute(ServerWebExchangeUtils.GATEWAY_REQUEST_URL_ATTR);
                    if (requestUrl != null && requestUrl.getHost() != null) {
                        String host = requestUrl.getHost();
                        downstream = host.contains(".") ? host.substring(0, host.indexOf('.')) : host;
                    }

                    String correlationId = exchange.getAttribute(CorrelationIdFilter.CORRELATION_ID_KEY);
                    int status = exchange.getResponse().getStatusCode() != null
                            ? exchange.getResponse().getStatusCode().value()
                            : 0;

                    // Emit a single log line; LogstashEncoder converts the markers to JSON fields.
                    log.info(
                            Markers.appendEntries(java.util.Map.of(
                                    "method", method,
                                    "path", path,
                                    "downstream", downstream,
                                    "status", status,
                                    "latencyMs", latencyMs,
                                    "correlationId", correlationId != null ? correlationId : ""
                            )),
                            "gateway request"
                    );
                })
        );
    }
}
