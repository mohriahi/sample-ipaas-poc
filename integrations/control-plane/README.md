# Control plane

Runs the WSO2 Integration Control Plane (ICP) via Docker, using the official
`wso2/wso2-integration-control-plane` image and its embedded H2 database
(POC-only, not meant for production use).

## Control plane install

Docs: [ICP console overview](https://wso2.com/integration-platform/docs/manage/icp/icp-console-overview)
— see the [Get Started guide](https://wso2.com/integration-platform/docs/manage/icp/quick-start)
for a full walkthrough.

Started/stopped automatically as part of `./start.sh` / `./stop.sh` at the
repo root. To run it standalone:

```bash
docker compose --env-file ../../.env up -d
```

- Console: https://localhost:9446 (default port, see `ICP_HTTPS_PORT` in `.env`)
- Default credentials: `admin` / `admin` — change before any non-evaluation use.
- Data (organizations, projects, environments, components, users) persists
  across `./stop.sh` / `./start.sh` in the `icp_data` Docker volume. It is
  only wiped by `./stop.sh --purge`.

## Connecting a runtime (integration)

Docs: [Connect an integration to ICP](https://wso2.com/integration-platform/docs/manage/icp/connect-runtime)

An integration registers itself with ICP using the `wso2/icp.runtime.bridge`
Ballerina module (not `ballerinax/wso2.controlplane` — that one implements
the older MI Dashboard protocol and does not work with ICP 2.0):

```ballerina
import wso2/icp.runtime.bridge as _;
```

with a matching `Config.toml` table:

```toml
[wso2.icp.runtime.bridge]
environment = "<env>"
project = "<project handler>"
integration = "<component/integration name>"
runtime = "<any unique id you choose for this instance>"
secret = "<kid>.<secret>"   # from ICP console: Project > Component > "connect a runtime"
```

`environment`/`project`/`integration`/`secret` must match a runtime
connection created via the ICP console's "connect a runtime" flow
(https://localhost:9446). `runtime` is self-chosen and not required to match
anything — see [../data-plane/hello-world/Config.toml](../data-plane/hello-world/Config.toml)
for a working example.

## Observability

Docs: [Observability setup](https://wso2.com/integration-platform/docs/manage/icp/observability-setup)

Connects the platform's native observability (OpenSearch + Fluent Bit) so
runtime logs and per-request metrics (response times, error rates) show up
in the ICP console's Logs and Metrics pages. Not set up in this POC — see
the doc above to add it.

## Other ICP console sections

- [Manage projects](https://wso2.com/integration-platform/docs/manage/icp/manage-projects)
- [Manage environments](https://wso2.com/integration-platform/docs/manage/icp/manage-environments)
- [Manage integrations](https://wso2.com/integration-platform/docs/manage/icp/manage-integrations)
- [Manage runtimes](https://wso2.com/integration-platform/docs/manage/icp/manage-runtimes)
- [Access control](https://wso2.com/integration-platform/docs/manage/icp/access-control)
