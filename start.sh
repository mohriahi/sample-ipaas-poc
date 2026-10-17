#!/usr/bin/env bash
# Starts the iPaaS POC platform:
#   1. Starts API management, in the chosen mode (--mode):
#        - api-manager (default) : full, self-hosted WSO2 API Manager
#          (aliases: on-prem, full-on-prem)
#        - saas | hybrid         : Self-Hosted Gateway connected to the WSO2 Integration Platform (SaaS)
#   2. Builds then starts the WSO2 Integrator integrations
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT_DIR/.env"
MODE="api-manager"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            MODE="${2:-}"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--mode api-manager|on-prem|full-on-prem|saas|hybrid]" >&2
            exit 1
            ;;
    esac
done

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

case "$MODE" in
    api-manager|on-prem|full-on-prem)
        echo "==> Mode: $MODE (full self-hosted WSO2 API Manager)"
        echo "==> Checking shared Docker network '$NETWORK_NAME'"
        docker network inspect "$NETWORK_NAME" >/dev/null 2>&1 || docker network create "$NETWORK_NAME"

        echo "==> Starting WSO2 API Manager $WSO2AM_VERSION (+ MySQL)"
        (cd "$ROOT_DIR/apim/api-manager" && docker compose --env-file "$ENV_FILE" up -d)
        ;;
    saas|hybrid)
        echo "==> Mode: $MODE (Self-Hosted Gateway connected to the WSO2 Integration Platform)"
        (cd "$ROOT_DIR/apim/saas-hybrid-gateway" && ./setup.sh)
        ;;
    *)
        echo "Unknown mode: '$MODE' (expected: api-manager | on-prem | full-on-prem | saas | hybrid)" >&2
        exit 1
        ;;
esac

echo "==> Building and starting WSO2 Integrator integrations"
(cd "$ROOT_DIR/integrations" && ./build.sh)

echo "==> Starting WSO2 Integration Control Plane (ICP) $ICP_VERSION"
(cd "$ROOT_DIR/integrations/control-plane" && docker compose --env-file "$ENV_FILE" up -d)

echo "==> Starting observability (Prometheus + Loki + Tempo + Grafana)"
(cd "$ROOT_DIR/observability" && docker compose --env-file "$ENV_FILE" up -d)

case "$MODE" in
    api-manager|on-prem|full-on-prem)
        echo "==> Waiting for WSO2 API Manager to be healthy (up to 5 min)"
        for _ in $(seq 1 60); do
            [[ "$(docker inspect --format '{{.State.Health.Status}}' "wso2am-$WSO2AM_VERSION" 2>/dev/null)" == "healthy" ]] && break
            sleep 5
        done
        if [[ "$(docker inspect --format '{{.State.Health.Status}}' "wso2am-$WSO2AM_VERSION" 2>/dev/null)" == "healthy" ]]; then
            echo "==> Publishing the HelloWorld API on the gateway (fronts hello-world)"
            "$ROOT_DIR/apim/api-manager/seed-hello-world-api.sh"
        else
            echo "!! WSO2 API Manager not healthy yet — run apim/api-manager/seed-hello-world-api.sh once it is"
        fi
cat <<EOF

======================================================================
 Sample Demo iPaaS - Platform started ($MODE)
======================================================================

 WSO2 API Manager $WSO2AM_VERSION
   - Console (Publisher)                 : https://localhost:$WSO2AM_HTTPS_PORT/admin
   - Console (DevPortal)                 : https://localhost:$WSO2AM_HTTPS_PORT/devportal
   - Console (Admin)                     : https://localhost:$WSO2AM_HTTPS_PORT/admin
   - Default credentials                 : admin / admin
   - API Gateway (HTTPS)                 : https://localhost:$WSO2AM_GATEWAY_HTTPS_PORT
   - API Gateway (HTTP)                  : http://localhost:$WSO2AM_GATEWAY_HTTP_PORT

 WSO2 Integrator integrations
   - Hello World                         : http://localhost:$HELLO_WORLD_PORT/hello
   - Hello World via the API Gateway     : http://localhost:$WSO2AM_GATEWAY_HTTP_PORT/hello-world/1.0/hello

 WSO2 Integration Control Plane (ICP) $ICP_VERSION
   - Console                             : https://localhost:$ICP_HTTPS_PORT
   - Default credentials                 : admin / admin

 Observability (metrics + logs + traces, correlated by trace ID)
   - Grafana (dashboards "WSO2 iPaaS")   : http://localhost:$GRAFANA_PORT
   - Prometheus                          : http://localhost:$PROMETHEUS_PORT
   - Generate demo traffic               : ./observability/generate-traffic.sh

 To stop the platform: ./stop.sh
======================================================================
EOF
        ;;
    *)
cat <<EOF

======================================================================
 Sample Demo iPaaS - Platform started ($MODE)
======================================================================

 Self-Hosted Gateway (connected to the WSO2 Integration Platform)
   - URL                                   : https://localhost:8443
   - WSO2 Integration Platform console.    : https://console.bijira.dev

 WSO2 Integrator integrations
   - Hello World                           : http://localhost:$HELLO_WORLD_PORT/hello

 WSO2 Integration Control Plane (ICP) $ICP_VERSION
   - Console                               : https://localhost:$ICP_HTTPS_PORT
   - Default credentials                   : admin / admin

 Observability (hello-world only in this mode — no local wso2am)
   - Grafana (dashboards "WSO2 iPaaS")     : http://localhost:$GRAFANA_PORT
   - Prometheus                            : http://localhost:$PROMETHEUS_PORT

 To stop the platform: ./stop.sh --mode $MODE
======================================================================
EOF
        ;;
esac
