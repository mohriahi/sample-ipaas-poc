#!/usr/bin/env bash
# Builds all WSO2 Integrator integrations into Docker images (bal build --cloud=docker),
# then (re)starts the services via Docker Compose.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

docker network inspect "$NETWORK_NAME" >/dev/null 2>&1 || docker network create "$NETWORK_NAME"

for project in "$SCRIPT_DIR"/data-plane/*/; do
    [ -f "$project/Ballerina.toml" ] || continue
    name="$(basename "$project")"
    echo "==> Building integration '$name'"
    (cd "$project" && bal build --cloud=docker)
done

echo "==> Starting containers"
(cd "$SCRIPT_DIR" && docker compose --env-file "$ENV_FILE" up -d)
