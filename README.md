# Sample Demo iPaaS

This repository provides a ready-to-run environment for a **POC integration
platform (iPaaS)**, combining:

- **WSO2 API Platform** — two deployment modes are available in this POC:
  - **api-manager**: Full On-premise API Manager (Control Plane and Data
    Plane all-in-one)
  - **saas / hybrid**: SaaS API Platform (Control Plane on SaaS, Data Plane
    on premise)
- **WSO2 Integrator** — lightweight integration engine used to develop and
  expose integration services (connectors, transformations, orchestrations)
  as APIs.

Everything is **fully containerized with Docker**, with no need for a
Kubernetes cluster or a dedicated VM: a machine (or server) with Docker
installed is enough to run the whole POC end to end.

## Architecture

**Mode 1 - Full On-premise API Manager**

![Full on-premise architecture](.docs/archi-full-on-premise.png)

**Mode 2 - SaaS / Hybrid API Platform**

![Hybrid architecture](.docs/archi-hybrid.png)

In both modes, WSO2 API Manager (or the Self-Hosted Gateway) and the WSO2
Integrator integrations share the same Docker network (`ipaas-network`),
which lets you **publish a WSO2 Integrator integration as an API backend**
in the WSO2 Publisher, simply referencing it by its container name (e.g.
`http://hello-world:9095`).

## Deployment modes

The repository offers two independent modes for the API management part,
to pick depending on what you want to demonstrate:

| Mode | Folder | Description |
|---|---|---|
| **api-manager** (default, aliases: `on-prem`, `full-on-prem`) | [`apim/api-manager/`](apim/api-manager) | Full WSO2 API Manager (Publisher, DevPortal, Gateway, Admin) self-hosted on Docker, no cloud dependency. |
| **saas** / **hybrid** | [`apim/saas-hybrid-gateway/`](apim/saas-hybrid-gateway) | Control plane (API management/publishing) hosted by WSO2's SaaS Integration Platform; only the Gateway (the component that routes API traffic) is deployed locally in Docker. |

A single pair of scripts, `./start.sh` and `./stop.sh`, controls whichever mode you pick with a simple `--mode` flag.
The [`integrations/`](integrations) part (WSO2 Integrator) is the same either way and starts automatically with `./start.sh`.

## Repository structure

| Folder | Contents |
|---|---|
| [`apim/api-manager/`](apim/api-manager) | `api-manager` mode (aliases: `on-prem`, `full-on-prem`): "all-in-one" Docker Compose install of WSO2 API Manager backed by MySQL, with data persistence on Docker volumes. |
| [`apim/saas-hybrid-gateway/`](apim/saas-hybrid-gateway) | `saas` / `hybrid` mode: WSO2 API Platform Self-Hosted Gateway connected to the WSO2 Integration Platform SaaS control plane. |
| [`integrations/`](integrations) | WSO2 Integrator integrations, including a `hello-world` sample, built into Docker images (`bal build --cloud=docker`) and started via Docker Compose. |

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose v2 (Podman also works)
- [WSO2 Integrator (`bal` CLI)](https://ballerina.io/downloads/) — only
  needed to build/modify the integrations, not to run WSO2 API Integrator
  ([download page](https://wso2.com/products/downloads/?product=wso2integrator))
- A bash terminal
- For **saas / hybrid** mode only: a WSO2 Integration Platform account with
  a Self-Hosted Gateway created in the console — see
  [Self-Hosted Gateway — getting started](https://wso2.com/api-platform/docs/cloud/api-platform-gateway/getting-started/)

Quick check:

```bash
docker --version
docker compose version
bal version
```

## Configuration (`.env`)

The WSO2 API Manager version, the shared Docker network name, and the
exposed ports are centralized in the [`.env`](.env) file at the root:

```dotenv
WSO2AM_VERSION=4.7.0
NETWORK_NAME=ipaas-network
WSO2AM_HTTPS_PORT=9443
WSO2AM_GATEWAY_HTTPS_PORT=8243
WSO2AM_GATEWAY_HTTP_PORT=8280
HELLO_WORLD_PORT=9095
```

### Docker registry

> **TODO**: this demo currently pulls images from the public registry
> ([hub.docker.com/u/wso2](https://hub.docker.com/u/wso2)). It will move to
> WSO2's private registry (`registry.wso2.com`, patched images, requires
> [WSO2 access](https://updates.docs.wso2.com/en/latest/updates/customer-guide-harbor-registry/))
> — details to follow.

## Setup & launch

### Step 0 — `saas` / `hybrid` mode only: get the connection token

Skip this step if you're running the default `api-manager` mode — it's
only needed to connect the gateway to the SaaS control plane.

1. In the WSO2 Integration Platform console, create (or select) a
   **Self-Hosted Gateway** (see the
   [getting started guide](https://wso2.com/api-platform/docs/cloud/api-platform-gateway/getting-started/)).
2. In the "Configure the Gateway" step, generate a registration token.
   ⚠️ Regenerating a token revokes the previous one and disconnects any
   gateway that was using it.
3. Copy [`apim/saas-hybrid-gateway/keys.env.example`](apim/saas-hybrid-gateway/keys.env.example)
   to `apim/saas-hybrid-gateway/keys.env` (same folder, gitignored) and
   fill in the values shown by the console (`MOESIF_KEY`,
   `GATEWAY_CONTROLPLANE_HOST`, `GATEWAY_REGISTRATION_TOKEN`).

### Step 1 — Start the platform

A single script orchestrates the whole platform, in the mode of your choice:

Full on-premise API Manager + WSO2 Integrator:

```bash
./start.sh                        # api-manager mode (default)
./start.sh --mode on-prem         # same as --mode api-manager
```

Self-Hosted Gateway (SaaS/Hybrid) + WSO2 Integrator:

```bash
./start.sh --mode saas            # Self-Hosted Gateway + WSO2 Integration Platform mode
```

### Step 2 — Verify the platform is up

**Full on-premise (`api-manager`):**

| Service | URL | Credentials |
|---|---|---|
| WSO2 Console (Publisher) | https://localhost:9443/publisher | `admin` / `admin` |
| WSO2 Console (DevPortal ) | https://localhost:9443/devportal | `admin` / `admin` |
| WSO2 Console (Admin) | https://localhost:9443/admin | `admin` / `admin` |
| API Gateway (HTTPS) | https://localhost:8243 | — |
| API Gateway (HTTP) | http://localhost:8280 | — |
| WSO2 Integrator "Hello World" integration | http://localhost:9095/hello | — |

**SaaS / Hybrid gateway:**

| Service | URL |
|---|---|
| Self-Hosted Gateway | https://localhost:8443 |
| API management (Publisher/DevPortal) | WSO2 Integration Platform console |
| WSO2 Integrator "Hello World" integration | http://localhost:9095/hello |

> WSO2 certificates are self-signed by default: it's normal to get a
> security warning in the browser on first access.

### Step 3 — Connect to the Publisher portal

Expose the `hello-world` WSO2 Integrator integration as an API on the
Gateway:

1. Open the Publisher portal:
   - `api-manager` mode: https://localhost:9443/publisher
   - `saas` / `hybrid` mode: WSO2 Integration Platform [console](https://console.bijira.dev)
2. **Create API** → **Import Open API** → upload
   [`integrations/data-plane/hello-world/openapi.yaml`](integrations/data-plane/hello-world/openapi.yaml)
3. **Deploy** the API to expose it on the Gateway.

> Discovery (automatically publishing new WSO2 Integrator integrations as
> APIs) can be automated later — for now, importing the OpenAPI contract
> is a manual, per-integration step.

## Stopping the platform

```bash
./stop.sh                     # stops the api-manager mode (default)
./stop.sh --mode saas         # stops the saas / hybrid gateway mode
```

To start over on a completely clean environment (removes the data
volumes, Docker images are kept for a fast restart):

```bash
./stop.sh --purge
```

## Documentation

### Integration Platform

- [Website](https://wso2.com/integration-platform/)
- [Documentation](https://wso2.com/integration-platform/docs/)
- Deployment:
  - [VM](https://wso2.com/integration-platform/docs/deploy/self-hosted/vm-deployment)
  - [Container](https://wso2.com/integration-platform/docs/deploy/self-hosted/containerized-deployment)
- [CI/CD](https://wso2.com/integration-platform/docs/deploy-operate/cicd/gitlab)
- [Observability](https://wso2.com/integration-platform/docs/deploy-operate/observe/observability-overview)
- [Control Plane](https://wso2.com/integration-platform/docs/manage/choosing-a-control-plane)
- [Develop](https://wso2.com/integration-platform/docs/develop/create-integrations/create-a-new-integration)
- [Download product](https://wso2.com/products/downloads/?product=wso2integrator)

### Integration Control Plane

- [Documentation](https://wso2.com/integration-platform/docs/manage/icp/quick-start)
- [Installation](https://wso2.com/integration-platform/docs/manage/icp/deploy-kubernetes)
- [Connect your runtime](https://wso2.com/integration-platform/docs/manage/icp/connect-runtime)
- [Setup the observability](https://wso2.com/integration-platform/docs/manage/icp/observability-setup)

### API Manager (Full on-premise)

- [Website](https://wso2.com/api-platform/api-manager/)
- [Technical documentation](https://apim.docs.wso2.com/en/latest/)
- [Installation](https://apim.docs.wso2.com/en/latest/install-and-setup/install-and-setup-overview/)
- [Installation best practices](https://apim.docs.wso2.com/en/latest/install-and-setup/install/installation-prerequisites/)
- Deployment:
  - [VM (all-in-one)](https://apim.docs.wso2.com/en/latest/install-and-setup/setup/single-node/configuring-a-single-node/)
  - [VM (distributed)](https://apim.docs.wso2.com/en/latest/install-and-setup/setup/single-node/configuring-a-single-node/)
  - [Kubernetes](https://apim.docs.wso2.com/en/latest/install-and-setup/setup/kubernetes-deployment/kubernetes/kubernetes-overview/)
  - [Docker](https://apim.docs.wso2.com/en/latest/install-and-setup/install/installation-options/#2-dockerdocker-compose)
- [Download product](https://wso2.com/products/downloads/)

### API Platform (SaaS)

- [Website](https://wso2.com/api-platform/)
- [Technical documentation](https://wso2.com/api-platform/docs/)
- [Self-Hosted Gateway — getting started](https://wso2.com/api-platform/docs/cloud/api-platform-gateway/getting-started/)
- [Setting up](https://wso2.com/api-platform/docs/cloud/api-platform-gateway/setting-up/)

### Docker Registry

- [Docker Registry](https://updates.docs.wso2.com/en/latest/updates/customer-guide-harbor-registry/)
- [Download product](https://wso2.com/products/downloads/)
- [Website](https://wso2.com/)

## POC scope

This environment is designed for a functional demo/validation and **is not
a production deployment**: single-node MySQL with default credentials,
self-signed certificates, no high availability. A production deployment
would need a properly secured/managed database, security hardening,
and an adapted deployment architecture (cluster, backups, monitoring,
etc.).

