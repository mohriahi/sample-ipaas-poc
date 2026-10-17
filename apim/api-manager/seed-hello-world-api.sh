#!/usr/bin/env bash
# Creates and publishes a "HelloWorld" API in WSO2 API Manager, in front of
# the hello-world integration (http://hello-world:9095). Calls through the
# gateway then show up in the Grafana dashboards (traces, logs, metrics).
#
#   Gateway URL: http://localhost:$WSO2AM_GATEWAY_HTTP_PORT/hello-world/1.0/hello
#
# Safe to run several times: does nothing if the API already exists.
# The API needs no token (demo only, not for production).
# Requires curl and python3, and WSO2 API Manager up and running.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../.env"
set +a

BASE="https://localhost:${WSO2AM_HTTPS_PORT}"
API_NAME="HelloWorld"
API_CONTEXT="/hello-world"
API_VERSION="1.0"

json() { python3 -c "import json,sys; print(json.load(sys.stdin)$1)"; }

echo "==> Registering a REST API client (DCR)"
DCR=$(curl -sk -u admin:admin -H "Content-Type: application/json" \
  -X POST "$BASE/client-registration/v0.17/register" \
  -d '{"callbackUrl":"www.example.com","clientName":"ipaas_seed_script","owner":"admin","grantType":"password refresh_token","saasApp":true}')
CLIENT_ID=$(echo "$DCR" | json "['clientId']")
CLIENT_SECRET=$(echo "$DCR" | json "['clientSecret']")

echo "==> Getting an admin token"
TOKEN=$(curl -sk -u "$CLIENT_ID:$CLIENT_SECRET" -X POST "$BASE/oauth2/token" \
  -d "grant_type=password&username=admin&password=admin&scope=apim:api_create apim:api_publish apim:api_view apim:api_manage" \
  | json "['access_token']")
AUTH="Authorization: Bearer $TOKEN"

# Turns on API logs for this API (repository/logs/api.log): one line per
# request/response step. BASIC level: no headers or message body.
# Docs: https://apim.docs.wso2.com/en/latest/monitoring/observability/monitoring-api-logs/
enable_api_logs() {
    echo "==> Enabling API Logs (BASIC) on '$API_NAME'"
    curl -sk -o /dev/null -u admin:admin -H "Content-Type: application/json" \
      -X PUT "$BASE/api/am/devops/v0/tenant-logs/carbon.super/apis/$1" \
      -d '{"logLevel":"BASIC"}'
}

EXISTING=$(curl -sk -H "$AUTH" "$BASE/api/am/publisher/v4/apis?query=name:$API_NAME")
if [[ "$(echo "$EXISTING" | json "['count']")" != "0" ]]; then
    echo "==> API '$API_NAME' already exists"
    enable_api_logs "$(echo "$EXISTING" | json "['list'][0]['id']")"
    exit 0
fi

echo "==> Creating API '$API_NAME' ($API_CONTEXT/$API_VERSION → http://hello-world:9095)"
API_ID=$(curl -sk -H "$AUTH" -H "Content-Type: application/json" \
  -X POST "$BASE/api/am/publisher/v4/apis" \
  -d "{
    \"name\": \"$API_NAME\",
    \"context\": \"$API_CONTEXT\",
    \"version\": \"$API_VERSION\",
    \"policies\": [\"Unlimited\"],
    \"operations\": [{\"target\": \"/*\", \"verb\": \"GET\", \"authType\": \"None\", \"throttlingPolicy\": \"Unlimited\"}],
    \"endpointConfig\": {
      \"endpoint_type\": \"http\",
      \"production_endpoints\": {\"url\": \"http://hello-world:9095\"},
      \"sandbox_endpoints\": {\"url\": \"http://hello-world:9095\"}
    }
  }" | json "['id']")

echo "==> Creating and deploying a revision to the 'Default' gateway"
REV_ID=$(curl -sk -H "$AUTH" -H "Content-Type: application/json" \
  -X POST "$BASE/api/am/publisher/v4/apis/$API_ID/revisions" \
  -d '{"description":"seed"}' | json "['id']")
curl -sk -o /dev/null -H "$AUTH" -H "Content-Type: application/json" \
  -X POST "$BASE/api/am/publisher/v4/apis/$API_ID/deploy-revision?revisionId=$REV_ID" \
  -d '[{"name":"Default","vhost":"localhost","displayOnDevportal":true}]'

echo "==> Publishing"
curl -sk -o /dev/null -H "$AUTH" \
  -X POST "$BASE/api/am/publisher/v4/apis/change-lifecycle?apiId=$API_ID&action=Publish"

enable_api_logs "$API_ID"

echo "==> Done: http://localhost:${WSO2AM_GATEWAY_HTTP_PORT}${API_CONTEXT}/${API_VERSION}/hello"
echo "    (allow a few seconds for the gateway to deploy the API)"
