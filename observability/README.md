# Observability

Prometheus + Grafana for metrics, Loki + Promtail for logs. Metrics setup
reuses the pattern from
[anuruddhal/wso2-integrator-city-services-demo](https://github.com/anuruddhal/wso2-integrator-city-services-demo/blob/main/docker-compose.yml),
scraping metrics exposed by:

- **`hello-world`** (WSO2 Integrator integration) — native Prometheus
  support via `ballerinax/prometheus` (see
  [../integrations/data-plane/hello-world/Config.toml](../integrations/data-plane/hello-world/Config.toml)),
  metrics at `:9797/metrics`. Requires
  `[build-options] observabilityIncluded = true` in
  [Ballerina.toml](../integrations/data-plane/hello-world/Ballerina.toml) —
  without it the compiler strips the metrics instrumentation and
  `/metrics` responds `200` with an empty body regardless of the
  `Config.toml` settings (found this the hard way — verified live).
- **`wso2am`** (WSO2 API Manager) — no native Prometheus support; metrics
  come from its JMX MBeans via the
  [Prometheus JMX exporter](https://github.com/prometheus/jmx_exporter)
  javaagent, added in
  [../apim/api-manager/dockerfile/Dockerfile](../apim/api-manager/dockerfile/Dockerfile)
  and started via `JAVA_OPTS` in
  [../apim/api-manager/docker-compose.yml](../apim/api-manager/docker-compose.yml).
  [jmx-exporter/config.yml](../apim/api-manager/jmx-exporter/config.yml) uses
  a catch-all rule (exports every MBean) — fine for a POC, narrow it for
  anything real.

## Logs

Logs (raw text, e.g. `log:printInfo` calls in `main.bal`) are a separate
pipeline from metrics — Prometheus only stores numeric time series, it
never shows log lines. **Promtail** discovers any container labeled
`ipaas.logs=true` (see the `labels:` on the `hello-world` and `wso2am`
services in their respective `docker-compose.yml`) via the Docker socket,
tails its JSON log file, and ships it to **Loki**. To add another
container's logs, just add that label to it — no Promtail config change
needed.

Config:
[loki/loki-config.yaml](loki/loki-config.yaml) (minimal single-binary,
filesystem storage — adapted from
[Loki's official minimal config](https://github.com/grafana/loki/blob/main/cmd/loki/loki-local-config.yaml)),
[promtail/promtail-config.yaml](promtail/promtail-config.yaml) (Docker
service discovery, filtered on the `ipaas.logs` label).

In Grafana: **Explore** > **Loki** datasource, query e.g. `{container="hello-world"}`.

### wso2am: console logs only, not access/audit/correlation/API/websocket logs

Promtail only tails a container's **stdout** (via Docker's own JSON log
driver). `wso2am`'s Carbon/console startup logs go there and are captured.
But per [WSO2's observability overview](https://apim.docs.wso2.com/en/latest/monitoring/observability/observability-overview/),
API Manager also writes several other log categories — Correlation, HTTP
Access, Audit, API, WebSocket — each to its own **file** under
`repository/logs/`, with `additivity = false` in `log4j2.properties` (i.e.
deliberately *not* echoed to console). None of those reach Loki with the
current setup; read them with e.g.
`docker exec wso2am-4.7.0 cat repository/logs/http_access_<date>.log`.

**Correlation logs** (`repository/logs/correlation.log`) are enabled via
`command: ["-DenableCorrelationLogs=true"]` on the `wso2am` service in
[../apim/api-manager/docker-compose.yml](../apim/api-manager/docker-compose.yml) —
each request gets a Correlation-ID tracking it end-to-end (HTTP
in/out, JDBC calls, etc.), verified live. **This must be a script argument
to `bin/api-manager.sh`, not a `JAVA_OPTS` value** — the script's own java
invocation hardcodes `-DenableCorrelationLogs=false` *after* `$JAVA_OPTS`
on the same command line, which silently wins over a JAVA_OPTS-supplied
`true` (found this the hard way — verified both ways live: JAVA_OPTS gave
1 log line ever, `command:` gives thousands with real Correlation-IDs).

## Install

Started/stopped automatically as part of `./start.sh` / `./stop.sh` at the
repo root. To run it standalone:

```bash
docker compose --env-file ../.env up -d
```

- Prometheus: http://localhost:9090 (targets: http://localhost:9090/targets)
- Loki: http://localhost:3100 (labels: http://localhost:3100/loki/api/v1/labels)
- Grafana: http://localhost:3000 — anonymous access enabled as Admin (no
  login needed), `admin` / `admin` if you do log in. The `Prometheus` and
  `Loki` datasources are pre-provisioned.

## Dashboards

`grafana/dashboards/` is provisioned as a file-based dashboard folder (see
`grafana/provisioning/dashboards/dashboard.yml`) — drop a dashboard JSON
there (or build one in the Grafana UI and export it) and it shows up
automatically within ~30s, no restart needed.

**[ipaas-overview.json](grafana/dashboards/ipaas-overview.json)** — "iPaaS
POC Overview", bundled. Every panel query was checked live against
Prometheus/Loki before being committed (not just written from metric
names that looked plausible):

- **hello-world**: request rate (`requests_total_value`), p50/p95 latency
  (`response_time_seconds`, pinned to the 5-minute time window — it also
  reports 10s/60s windows as separate series, which would otherwise draw
  3 overlapping lines per endpoint), in-progress requests, logs (Loki).
- **wso2am**: JVM heap memory, thread count, HTTP request rate per
  connector (`Catalina_GlobalRequestProcessor_requestCount` — from the JMX
  exporter, since APIM has no native Prometheus metrics), G1 GC collection
  rate, console logs (Loki — see the "console logs only" caveat above).
