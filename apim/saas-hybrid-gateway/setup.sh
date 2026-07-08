#!/usr/bin/env bash
# Downloads (if needed) the WSO2 API Platform Self-Hosted Gateway and starts
# it, connected to the WSO2 Integration Platform SaaS control plane, using
# the keys.env file obtained from the WSO2 Integration Platform console
# (manual step, see README.md).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_ENV_FILE="$SCRIPT_DIR/../../.env"
KEYS_SOURCE="$SCRIPT_DIR/keys.env"
VERSION="${GATEWAY_VERSION:-1.1.0}"
ZIP_NAME="wso2apip-api-gateway-${VERSION}.zip"
GATEWAY_DIR="$SCRIPT_DIR/wso2apip-api-gateway-${VERSION}"
KEYS_FILE="$GATEWAY_DIR/configs/keys.env"

set -a
# shellcheck disable=SC1090
[ -f "$ROOT_ENV_FILE" ] && source "$ROOT_ENV_FILE"
set +a
NETWORK_NAME="${NETWORK_NAME:-ipaas-network}"

if [ ! -f "$KEYS_SOURCE" ]; then
    cat <<EOF

File not found: $KEYS_SOURCE

This file holds the (single-use) registration token that links this
gateway to the WSO2 Integration Platform control plane. It cannot be
generated automatically, it must be retrieved from the WSO2 Integration
Platform console:

  1. WSO2 Integration Platform console -> Gateways -> create (or select) a Self-Hosted Gateway
  2. "Configure the Gateway" step -> generate a new registration token
     (⚠️ regenerating a token revokes the previous one and disconnects any
     gateway already using it)
  3. Copy $SCRIPT_DIR/keys.env.example to $KEYS_SOURCE and fill in the
     values shown by the console.

Then re-run this script.
EOF
    exit 1
fi

if [ ! -d "$GATEWAY_DIR" ]; then
    echo "==> Downloading Self-Hosted Gateway v$VERSION"
    (cd "$SCRIPT_DIR" && \
        curl -sLO "https://github.com/wso2/api-platform/releases/download/gateway/v${VERSION}/${ZIP_NAME}" && \
        unzip -q "$ZIP_NAME")
fi

# Attach gateway-runtime to the shared "ipaas-network" so it can reach
# WSO2 Integrator integrations by container name (see docker-compose.override.yaml).
docker network inspect "$NETWORK_NAME" >/dev/null 2>&1 || docker network create "$NETWORK_NAME"
cp "$SCRIPT_DIR/docker-compose.override.yaml" "$GATEWAY_DIR/docker-compose.override.yaml"

# Copy the connection secrets into the (gitignored, re-downloadable) release
# folder so they survive even if it gets deleted and re-extracted.
mkdir -p "$(dirname "$KEYS_FILE")"
cp "$KEYS_SOURCE" "$KEYS_FILE"

echo "==> Starting Self-Hosted Gateway (connected to the WSO2 Integration Platform)"
(cd "$GATEWAY_DIR" && docker compose --env-file configs/keys.env up -d)

cat <<EOF

======================================================================
 WSO2 API Platform Self-Hosted Gateway - started
======================================================================
 Gateway URL: https://localhost:8443
 Associated environment: the one chosen in the WSO2 Integration Platform console

 Next step: create an API in the WSO2 Integration Platform and deploy it
 to this gateway.
======================================================================
EOF
