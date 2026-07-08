#!/usr/bin/env bash
# Stops the Self-Hosted Gateway connected to the WSO2 Integration Platform.
# Use --purge to also remove the gateway's local volumes/data.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${GATEWAY_VERSION:-1.1.0}"
GATEWAY_DIR="$SCRIPT_DIR/wso2apip-api-gateway-${VERSION}"

PURGE_FLAG=""
if [[ "${1:-}" == "--purge" ]]; then
    PURGE_FLAG="-v"
fi

if [ ! -d "$GATEWAY_DIR" ]; then
    echo "Nothing to stop: $GATEWAY_DIR not found."
    exit 0
fi

(cd "$GATEWAY_DIR" && docker compose --env-file configs/keys.env down $PURGE_FLAG)
echo "==> Self-Hosted Gateway stopped"
