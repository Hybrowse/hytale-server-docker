# Kubernetes

This repository ships optional Kubernetes deployment assets for the Docker image:

- Docker Hub: `hybrowse/hytale-server`
- GHCR: `ghcr.io/hybrowse/hytale-server`

The manifests are designed with:

- secure defaults (non-root, minimal privileges)
- operational flexibility (Helm values or Kustomize overlays)
- no redistribution of proprietary Hytale server files

## Helm

The Helm chart lives in `deploy/helm/hytale-server`. Published chart packages pin the
image to the release version. The source chart currently targets image 1.2.0.
ARM64 works without an architecture selector or privileged mode; only the
official downloader uses emulation. Java remains native.

### Add the Helm repo (GitHub Pages)

After a release is published, the Helm repository is available at:

- `https://hybrowse.github.io/hytale-server-docker`

Add it:

```bash
helm repo add hybrowse https://hybrowse.github.io/hytale-server-docker
helm repo update
```

### Install with persistence (StatefulSet)

Persistence is enabled by default in the Helm chart.
You can tune the requested size; start with 20Gi and allow more for worlds, mods and backups.
Native updates need room for staged files and recovery copies; the example uses 40Gi.

```bash
helm install hytale hybrowse/hytale-server \
  --set persistence.enabled=true \
  --set persistence.size=20Gi
```

Existing claims are not resized by changing this value alone. Read the upgrade notes below before upgrading an older installation.

### Install (ephemeral /data, no PVC)

For disposable testing only (all data is lost when the Pod is replaced):

```bash
helm install hytale hybrowse/hytale-server \
  --set persistence.enabled=false \
  --set env.HYTALE_AUTO_DOWNLOAD=true
```

Notes:

- `/data` will be an `emptyDir` (lost when the Pod is replaced).
- This is best suited for dev/testing or setups that synchronize state elsewhere.

### Switch workload type to Deployment

If you explicitly prefer a Deployment:

```bash
helm install hytale hybrowse/hytale-server \
  --set workload.kind=Deployment
```

If you want persistence with Deployment mode, the chart creates a PVC unless you point it at an existing one:

```bash
helm install hytale hybrowse/hytale-server \
  --set workload.kind=Deployment \
  --set persistence.enabled=true \
  --set persistence.existingClaim=my-existing-claim
```

### Exposing the UDP port

By default, the chart creates a `ClusterIP` Service (internal).

For external exposure, options depend on your cluster:

- `service.type=LoadBalancer` (common on managed clusters)
- `service.type=NodePort` (requires firewall / node routing)

Examples:

```bash
helm install hytale hybrowse/hytale-server \
  --set service.type=LoadBalancer
```

```bash
helm install hytale hybrowse/hytale-server \
  --set service.type=NodePort \
  --set service.nodePort=30520
```

### Example: values.yaml snippet (persistence and environment variables)

If you prefer a values file over long `--set` commands, use this starting point. Broker integration is optional; enable it only after deploying and authenticating a broker.

```yaml
workload:
  kind: StatefulSet

persistence:
  enabled: true
  size: 20Gi

env:
  HYTALE_AUTO_DOWNLOAD: "true"
  HYTALE_AUTO_UPDATE: "true"

  # Optional (advanced): fetch server session/identity tokens from the Hytale Session Token Broker by Hybrowse
  # and skip the interactive /auth flow.
  # HYTALE_SESSION_TOKEN_BROKER_ENABLED: "true"
  # HYTALE_SESSION_TOKEN_BROKER_URL: "http://hytale-session-token-broker:8080"
```

If your broker uses an HTTP bearer token, prefer mounting it as a file and set `HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN_SRC`.
You can do this via `extraVolumes` / `extraVolumeMounts` and `env`.

### Example: wiring secrets (server auth, CurseForge, downloader credentials)

The chart supports referencing existing Kubernetes `Secret` objects via `.Values.secrets.*`.
This avoids putting secrets into Helm values files.

Example secrets (create once per environment):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: hytale-server-auth
type: Opaque
stringData:
  sessionToken: "<redacted>"
  identityToken: "<redacted>"
---
apiVersion: v1
kind: Secret
metadata:
  name: hytale-curseforge
type: Opaque
stringData:
  apiKey: "<redacted>"
---
apiVersion: v1
kind: Secret
metadata:
  name: hytale-downloader-credentials
type: Opaque
stringData:
  credentials.json: "{...}" 
```

Then reference them from Helm values:

```yaml
secrets:
  serverAuth:
    name: hytale-server-auth
    sessionTokenKey: sessionToken
    identityTokenKey: identityToken

  curseforge:
    name: hytale-curseforge
    apiKeyKey: apiKey

  downloaderCredentials:
    name: hytale-downloader-credentials
    credentialsKey: credentials.json
```

Notes:

- The chart maps server auth secrets to `HYTALE_SERVER_SESSION_TOKEN` / `HYTALE_SERVER_IDENTITY_TOKEN`.
- The chart mounts the CurseForge key and downloader credentials as files and sets `HYTALE_CURSEFORGE_API_KEY_SRC` / `HYTALE_DOWNLOADER_CREDENTIALS_SRC`.

### Production pattern: multi-environment and multi-region

Treat each region as a separate Helm release. Keep its configuration, credentials and persistent data separate from other environments.

#### Namespaces

Use one namespace per environment, such as `hytale-dev`, `hytale-staging` and `hytale-prod`. For multiple regions, use names such as `hytale-prod-eu` and `hytale-prod-us`.

#### Values files

Keep non-secret configuration in values files and apply regional overrides after the shared configuration:

| File | Purpose |
| --- | --- |
| `values.prod.yaml` | Shared production settings |
| `values.prod-eu.yaml` | Overrides for the EU deployment |
| `values.prod-us.yaml` | Overrides for the US deployment |

Use separate files such as `values.dev.yaml` and `values.staging.yaml` for other environments. Do not put credentials in these files.

#### Secrets and permissions

Create Kubernetes Secrets separately in each namespace, preferably through your existing secret manager or GitOps tooling. Consistent Secret names let you reuse the same values structure across environments.

After rotating credentials, recreate the affected Pods so they read the updated values. Environment variables and `subPath` Secret mounts do not refresh inside an existing container.

Keep `serviceAccount.automount=false` unless the server needs Kubernetes API access. Give external secret tooling access only to the namespaces it manages.

#### Release names

Choose explicit names such as `hytale-eu` and `hytale-us`. For example, after preparing the values files and Secrets:

```sh
helm install hytale-eu hybrowse/hytale-server \
  --namespace hytale-prod-eu --create-namespace \
  -f values.prod.yaml -f values.prod-eu.yaml
helm install hytale-us hybrowse/hytale-server \
  --namespace hytale-prod-us --create-namespace \
  -f values.prod.yaml -f values.prod-us.yaml
```

## Operations

See [Kubernetes operations](kubernetes-operations.md) for first login, probes, native updates, credential recovery and existing PVCs.

## Kustomize

See the [Kustomize guide](kustomize.md).

## Validation

Locally you can validate that the Kubernetes manifests render and pass schema validation:

```bash
task k8s:test
```
