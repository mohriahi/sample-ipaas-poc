#!/usr/bin/env bash
# Stops the iPaaS POC platform without removing persisted data.
# Options:
#   --mode api-manager|on-prem|full-on-prem|saas|hybrid   (default: api-manager)
#   --purge                                                also removes the data volumes
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT_DIR/.env"
MODE="api-manager"
PURGE_FLAG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            MODE="${2:-}"
            shift 2
            ;;
        --purge)
            PURGE_FLAG="-v"
            shift
            ;;
        *)
            echo "Usage: $0 [--mode api-manager|on-prem|full-on-prem|saas|hybrid] [--purge]" >&2
            exit 1
            ;;
    esac
done

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if [[ -n "$PURGE_FLAG" ]]; then
    echo "==> Purge mode enabled: data volumes will be removed"
fi

echo "==> Stopping WSO2 Integrator integrations"
(cd "$ROOT_DIR/integrations" && docker compose --env-file "$ENV_FILE" down $PURGE_FLAG)

echo "==> Stopping WSO2 Integration Control Plane (ICP)"
(cd "$ROOT_DIR/integrations/control-plane" && docker compose --env-file "$ENV_FILE" down $PURGE_FLAG)

echo "==> Stopping observability (Prometheus + Grafana)"
(cd "$ROOT_DIR/observability" && docker compose --env-file "$ENV_FILE" down $PURGE_FLAG)

case "$MODE" in
    api-manager|on-prem|full-on-prem)
        echo "==> Stopping WSO2 API Manager ($MODE)"
        (cd "$ROOT_DIR/apim/api-manager" && docker compose --env-file "$ENV_FILE" down $PURGE_FLAG)
        if [[ -n "$PURGE_FLAG" ]]; then
            docker network rm "$NETWORK_NAME" >/dev/null 2>&1 || true
        fi
        ;;
    saas|hybrid)
        echo "==> Stopping the Self-Hosted Gateway ($MODE)"
        (cd "$ROOT_DIR/apim/saas-hybrid-gateway" && ./stop.sh ${PURGE_FLAG:+--purge})
        ;;
    *)
        echo "Unknown mode: '$MODE' (expected: api-manager | on-prem | full-on-prem | saas | hybrid)" >&2
        exit 1
        ;;
esac

echo "==> Platform stopped"
