# WSO2 API Platform — Self-Hosted Gateway connected to the WSO2 Integration Platform

Second deployment mode of the POC, alternative to
[`apim/api-manager/`](../api-manager) (api-manager mode). Here,
the **control plane** (API management, Publisher, DevPortal, analytics) is
hosted by WSO2 in the **WSO2 Integration Platform** SaaS, and only the
**Gateway** (the component that actually receives and routes API traffic)
is deployed locally in Docker.

Use case: demonstrate a deployment where API traffic stays within the
organization's own infrastructure (data, internal network) while
delegating API management/publishing to a SaaS platform.

## Prerequisites

- A WSO2 Integration Platform account with a Self-Hosted Gateway created in the console
- `curl`, `unzip`
- Docker + Docker Compose installed and running

## Step 1 — Get the connection token (manual, WSO2 Integration Platform console)

This step cannot be automated: the token is **single-use** and specific to
your WSO2 Integration Platform account.

1. In the WSO2 Integration Platform console, create (or select) a
   **Self-Hosted Gateway**.
2. In the "Configure the Gateway" step, generate a registration token.
   ⚠️ Regenerating a token revokes the previous one and disconnects any
   gateway that was using it.
3. Copy [`keys.env.example`](keys.env.example) to `keys.env` (same folder,
   gitignored) and fill in the values shown by the console
   (`MOESIF_KEY`, `GATEWAY_CONTROLPLANE_HOST`, `GATEWAY_REGISTRATION_TOKEN`).

## Step 2 — Start the gateway

```bash
./setup.sh
```

This script:
1. checks that `keys.env` exists (created in step 1 — the script stops
   with instructions if it's missing);
2. downloads and unpacks the official Self-Hosted Gateway release
   (`wso2apip-api-gateway-1.1.0.zip` from the `wso2/api-platform` GitHub
   releases) if not already present;
3. copies `keys.env` into the release folder
   (`wso2apip-api-gateway-1.1.0/configs/keys.env`) — done on every run, so
   the secrets survive even if that folder is deleted and re-downloaded;
4. starts the gateway with `docker compose --env-file configs/keys.env up -d`.

Once started:

- Gateway URL: https://localhost:8443
- Associated environment: the one chosen when creating it in the WSO2
  Integration Platform console

Next step: create an API in the WSO2 Integration Platform and deploy it to
this gateway.

## Stopping

```bash
./stop.sh
```

To also remove the gateway's local data:

```bash
./stop.sh --purge
```

## Security

`keys.env` contains connection secrets to the WSO2 Integration Platform
control plane — **never commit it** (already excluded via the root
`.gitignore`, along with the downloaded `wso2apip-api-gateway-*/` folder
and its own copy of `configs/keys.env`). Only `keys.env.example`
(placeholder values) is tracked in the repository.
