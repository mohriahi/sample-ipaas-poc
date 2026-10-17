# Observability

Metrics, logs and traces for the whole demo (the WSO2 API Manager gateway
and the `hello-world` WSO2 Integrator integration). Every request gets
**one ID that links everything together**: from a slow chart point you can
jump to the trace, and from the trace to the log lines of every component
it went through.

| What    | Tool       | Collected from                                              |
|---------|------------|-------------------------------------------------------------|
| Metrics | Prometheus | `hello-world`, WSO2 API Manager, and metrics computed from the traces |
| Logs    | Loki       | every container's output, plus the WSO2 API Manager log files |
| Traces  | Tempo      | the API gateway and `hello-world`                            |
| UI      | Grafana    | 4 ready-made dashboards                                      |

## Getting started

Everything starts and stops with `./start.sh` / `./stop.sh` at the root of
the repository. `./start.sh` also publishes the demo API on the gateway
([seed-hello-world-api.sh](../apim/api-manager/seed-hello-world-api.sh)).

Then send some traffic, either:

- **from Postman** — import
  [wso2-ipaas-demo.postman_collection.json](../postman/wso2-ipaas-demo.postman_collection.json).
  It contains successful calls, errors, a call without trace ID, a direct
  call to `hello-world`, API log settings and admin actions (for the audit
  logs). After each gateway call, the **Visualize** tab shows links that
  open its trace and logs in Grafana.
- **or in bulk** with the script:
  - `./observability/generate-traffic.sh 50` — acts like an application that
    already does tracing; prints the trace ID of each request.
  - `./observability/generate-traffic.sh --mobile 50` — acts like a simple
    mobile app with no tracing; the gateway creates a correlation ID for
    each request, printed on screen.

Then open the dashboards:

- Grafana: http://localhost:3000 (dashboards "WSO2 iPaaS — …")
- Prometheus: http://localhost:19090 (not 9090, which the Self-Hosted
  Gateway uses in saas/hybrid mode)
- Loki: http://localhost:3100 · Tempo: http://localhost:3200

## Following a single request

Each request through the gateway carries a **trace ID**. If the caller
already sends one (standard `traceparent` header), the gateway reuses it;
otherwise the gateway creates its own **correlation ID** for the request.
Either way, the same ID can be found in:

1. **Traces (Tempo)** — one trace showing each step inside the gateway
   (security checks, throttling, call to the backend) followed by the
   `hello-world` step.
2. **Gateway logs (Loki)** — the correlation, API and access logs of WSO2
   API Manager all carry the ID.
3. **`hello-world` logs (Loki)** — every log line carries the trace ID.
4. **Metrics (Prometheus)** — chart points link back to example traces.

To find a request, paste its ID in the **Trace ID or Correlation ID** field
of the **Traces** or **Logs** dashboard (for an ID of the form
`00-<32 characters>-<16 characters>-01`, paste only the 32-character middle
part). In the log views, IDs are clickable and open the matching trace or
log lines.

New traces take about 30 seconds to show up in searches (opening a trace
directly by its ID works right away).

## Dashboards

Found in Grafana under the `wso2-observability` tag, with links between
them at the top right:

- **WSO2 iPaaS — Overview**: traffic, error rate and response times of the
  gateway, health of the platform, latest errors and warnings, map of the
  services.
- **WSO2 iPaaS — Metrics**: traffic, errors and response times per API,
  where the time is spent inside the gateway, `hello-world` metrics, and
  API Manager memory and threads.
- **WSO2 iPaaS — Logs**: all API Manager logs plus `hello-world`, with
  filters by container, free text and request ID.
- **WSO2 iPaaS — Traces**: recent requests, failed requests (4xx/5xx), slow
  requests (> 200 ms) and the map of the services.

## WSO2 API Manager logs collected

Based on the [WSO2 observability docs](https://apim.docs.wso2.com/en/latest/monitoring/observability/observability-overview/).
In Grafana, each log type can be selected with its `job` name:

| Log | What it contains | `job` |
|---|---|---|
| Correlation logs | every step of every request, with its ID | `wso2am-correlation` |
| API logs | one line per request/response step, per API | `wso2am-api-log` |
| Gateway access logs | one line per call received by the gateway | `wso2am-gateway-access` |
| Console access logs | traffic on the Publisher, DevPortal, Admin and REST APIs | `wso2am-mgmt-access` |
| Audit logs | who did what (logins, API / application / user changes) | `wso2am-audit` |
| Server logs | the API Manager console output | (filter on the container) |

## Where things are configured

| Component | File |
|---|---|
| Prometheus | [prometheus/prometheus.yml](prometheus/prometheus.yml) |
| Tempo | [tempo/tempo.yaml](tempo/tempo.yaml) |
| Loki | [loki/loki-config.yaml](loki/loki-config.yaml) |
| Log collection (Promtail) | [promtail/promtail-config.yaml](promtail/promtail-config.yaml) |
| Grafana data sources and links | [grafana/provisioning/datasources/datasource.yml](grafana/provisioning/datasources/datasource.yml) |
| Grafana dashboards | [grafana/dashboards/](grafana/dashboards) |
| WSO2 API Manager side (traces, logs, metrics) | [../apim/api-manager/](../apim/api-manager) |
| `hello-world` side (traces, metrics) | [../integrations/data-plane/hello-world/](../integrations/data-plane/hello-world) |

## Known limitations

- **Service map**: it shows `user → /hello` but not the gateway in between,
  because of how the gateway reports its steps. The trace view still shows
  the full path.
- **`hello-world` appears as `/hello`** in Tempo (its URL path is used as
  its name).
- **Audit logs and console access logs have no request ID** (they are about
  admin actions, not API calls), so they are not linked to traces.
- **Demo settings**: Grafana is open to anyone as admin, every request is
  traced and logged in detail. Tune this before any real use.

## Troubleshooting

- **Promtail keeps restarting with `too many open files`**: the Docker VM
  has hit its file-watch limit, usually because a Kubernetes cluster
  (k3d/kind) runs in the same VM. Raise it (to redo after each VM restart):
  `docker run --rm --privileged busybox sysctl -w fs.inotify.max_user_instances=512`
- **Memory**: the whole platform (API Manager, MySQL, ICP, observability)
  uses about 3.5 GB of RAM, so plan for about 6 GB. With less, or when the
  Docker VM is shared with other workloads, API Manager can take more than
  5 minutes to start. A dedicated VM works best, e.g.
  `colima start -p ipaas --cpu 6 --memory 10`.
