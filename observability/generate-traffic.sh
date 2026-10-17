#!/usr/bin/env bash
# Sends demo traffic through the API gateway to hello-world, to fill the
# Grafana dashboards. Two modes:
#
# - instrumented (default): acts like an application that already does
#   tracing (web app, microservice, partner system). Each request gets its
#   own trace ID, printed on screen, and can be found with it in the traces
#   and in the logs of every component.
#
# - mobile (--mobile): acts like a simple mobile app with no tracing. The
#   gateway creates a correlation ID for each request, printed on screen.
#   Paste it in the "Trace ID or Correlation ID" field of the Traces or
#   Logs dashboard.
#
# Usage: ./generate-traffic.sh [--mobile] [requests]   (default: 30)
# About 1 request in 10 goes to an unknown path (404) so the error panels
# have something to show.
# Requires: curl, openssl, python3.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../.env"
set +a

MODE=instrumented
COUNT=30
for arg in "$@"; do
    case "$arg" in
        --mobile|--no-traceparent) MODE=mobile ;;
        --instrumented) MODE=instrumented ;;
        -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        ''|*[!0-9]*) echo "Unknown argument: $arg (see --help)" >&2; exit 1 ;;
        *) COUNT="$arg" ;;
    esac
done

GATEWAY="http://localhost:${WSO2AM_GATEWAY_HTTP_PORT}/hello-world/1.0"
OTLP="http://localhost:${OTLP_HTTP_PORT}/v1/traces"
NAMES=(Kevin Lisa Damien Julien Charlene Demo)

now_ns() { python3 -c 'import time; print(time.time_ns())'; }

send_client_span() {   # trace_id span_id start end path code
    local status=1; (( $6 >= 400 )) && status=2   # OTLP: 1 = OK, 2 = ERROR
    curl -s -o /dev/null -X POST "$OTLP" -H "Content-Type: application/json" -d "{
      \"resourceSpans\": [{
        \"resource\": {\"attributes\": [{\"key\": \"service.name\", \"value\": {\"stringValue\": \"demo-client\"}}]},
        \"scopeSpans\": [{\"spans\": [{
          \"traceId\": \"$1\", \"spanId\": \"$2\",
          \"name\": \"GET /hello-world/1.0$5\", \"kind\": 3,
          \"startTimeUnixNano\": \"$3\", \"endTimeUnixNano\": \"$4\",
          \"status\": {\"code\": ${status}},
          \"attributes\": [
            {\"key\": \"http.method\", \"value\": {\"stringValue\": \"GET\"}},
            {\"key\": \"http.url\", \"value\": {\"stringValue\": \"${GATEWAY}$5\"}},
            {\"key\": \"http.status_code\", \"value\": {\"intValue\": $6}}
          ]
        }]}]
      }]
    }" || true
}

echo "Mode: ${MODE} — ${COUNT} requests to ${GATEWAY}"
for ((i = 1; i <= COUNT; i++)); do
    if (( i % 10 == 0 )); then
        path="/does-not-exist"
    elif (( i % 2 == 0 )); then
        path="/hello/${NAMES[$((RANDOM % ${#NAMES[@]}))]}"
    else
        path="/hello"
    fi

    if [[ "$MODE" == instrumented ]]; then
        trace_id=$(openssl rand -hex 16)
        span_id=$(openssl rand -hex 8)
        start=$(now_ns)
        code=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "traceparent: 00-${trace_id}-${span_id}-01" "${GATEWAY}${path}")
        end=$(now_ns)
        send_client_span "$trace_id" "$span_id" "$start" "$end" "$path" "$code"
        printf "%3d  %s  %-22s trace_id=%s\n" "$i" "$code" "$path" "$trace_id"
    else
        # The gateway returns the correlation ID in the traceparent response header.
        headers=$(curl -s -o /dev/null -D - "${GATEWAY}${path}")
        code=$(awk 'NR==1 {print $2}' <<<"$headers")
        corr=$(awk 'tolower($1)=="traceparent:" {print $2}' <<<"$headers" | tr -d '\r')
        printf "%3d  %s  %-22s correlation_id=%s\n" "$i" "$code" "$path" "${corr:-?}"
    fi
    sleep 0.3
done
