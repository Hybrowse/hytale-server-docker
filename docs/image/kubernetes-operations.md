# Kubernetes operations

Use this page after [installing the chart](kubernetes.md) or choosing a [Kustomize overlay](kustomize.md). Keep your namespace and release name consistent across commands.

## Important: server files and persistence

The container expects its data under `/data`:

- `/data/Assets.zip`
- `/data/server/HytaleServer.jar`

Whether you persist `/data` depends on your operation model:

- If you want the server files, mods, backups, and generated state to survive restarts, use a PVC.
- If you want fully ephemeral nodes and sync state elsewhere (e.g. an external backup/sync process), you can run without a PVC.

If you enable auto-download (`HYTALE_AUTO_DOWNLOAD=true`), the server files can be downloaded at runtime into `/data`.

Note: We intentionally do not enable a read-only root filesystem by default. The official server workflow can require writing a machine-id (and while the image has workarounds, a strictly read-only root filesystem can still be surprising operationally).

### Recommended production patterns for server files

For non-interactive Kubernetes operations, prefer one of these:

- Keep `HYTALE_AUTO_DOWNLOAD=true` and mount a downloader credentials secret as `HYTALE_DOWNLOADER_CREDENTIALS_SRC`.
- Set `HYTALE_AUTO_DOWNLOAD=false` and provision `/data/Assets.zip` + `/data/server/` before container startup (for example with an init container).

Why this matters: Session Token Broker runs later in startup. If auto-download is still waiting for first-time auth (or fails), broker logs/calls are not reached yet.


## First startup and profile selection

For the following examples, run commands in the server namespace (`kubectl -n <namespace>`).
The examples live in the source repository; download them or run Helm from a checkout.
For example, install the published image with the first-start values file:

```bash
helm upgrade --install hytale ./deploy/helm/hytale-server \
  -f deploy/helm/hytale-server/examples/first-start.yaml
kubectl get pods -l app.kubernetes.io/instance=hytale
kubectl logs -f <pod> -c hytale-server
```

There are two independent logins: the downloader login before Java starts, then
Hytale's server login, which the image starts automatically on a fresh installation.
Both URLs/codes appear in the logs. If Hytale lists several profiles:

```bash
kubectl exec <pod> -c hytale-server -- hytale-cli auth select <name-or-number>
kubectl exec <pod> -c hytale-server -- hytale-cli auth status
```

No terminal attachment or `stdin`/`tty` setting is needed. Use `hytale-cli auth login`
to start a login manually. `HYTALE_AUTO_AUTH=false` opts out. Stored credentials,
broker authentication and supplied server tokens skip automatic server login.
Keep the whole PVC, including `server/auth.enc`, server configuration and `.machine-id`.
A new Pod can reuse that login when it mounts the same data. With `emptyDir`, Pod
replacement loses this data. Readiness does not prove that OAuth login succeeded.

The [broker values example](https://github.com/Hybrowse/hytale-server-docker/blob/main/deploy/helm/hytale-server/examples/broker.yaml)
shows separate existing Secrets for downloader credentials and the broker bearer
token. It deploys only the game server; deploy/authenticate the broker separately.
Create the referenced Secrets in the server namespace. Secret values are never
embedded in these examples. Do not put raw credentials in Helm `env` values.


## Probes during downloads and updates

Helm probes remain opt-in with `probes.enabled=true`. When enabled, the default
is readiness only; startup and liveness probes are disabled. Kustomize's `probes`
and `production` overlays use the same readiness-only policy.

A failed readiness check removes a Pod from Service endpoints without restarting
it. Our check verifies server files, the process and UDP listener; it does not
verify completed authentication or that a full world has loaded. A failed startup
or liveness probe can restart the container. Therefore avoid restart probes during
manual login, slow downloads and native in-process update handovers. The startup
probe runs only at container startup, so extending it does not protect later updates.

For fully provisioned deployments you may explicitly enable startup/liveness probes
and tune their thresholds. The optional startup default now allows 30 minutes
(`180 * 10s`); choose a budget based on your actual environment. Keep liveness
disabled for native updates unless you provide a check and budget that tolerate
archive verification, backups and the Java restart.

Temporary extraction files are disk-backed `emptyDir`. Plan node ephemeral-storage
capacity and limits for extracted server files; `resources` accepts Kubernetes
requests/limits including `ephemeral-storage`. The download archive and assets live
on `/data`. Using `tmp.emptyDir.medium=Memory` makes extraction count towards Pod
memory usage, which can cause an OOM on constrained Pods.


## Native Hytale updates on Kubernetes

The [native-update values example](https://github.com/Hybrowse/hytale-server-docker/blob/main/deploy/helm/hytale-server/examples/native-updates.yaml)
uses a 40Gi PVC, backups and readiness only:

```yaml
env:
  HYTALE_AUTO_DOWNLOAD: "true"
  HYTALE_AUTO_UPDATE: "false"
  HYTALE_NATIVE_UPDATES: "true"
  HYTALE_ENABLE_BACKUP: "true"
  HYTALE_BACKUP_ARCHIVE_MAX_COUNT: "3"
  ENABLE_AOT: "auto"
```

Use Hytale's direct OAuth login stored on the data volume. Broker session tokens
alone cannot check for or download native updates. Keep the standard writable
JAR/assets paths; do not mount individual server files read-only. The 40Gi example
is a starting point, not a capacity guarantee: account for worlds, mods, staged
assets, replacement copies and both server/update backups. Monitor free space.

```bash
kubectl exec <pod> -c hytale-server -- hytale-cli send "/update check"
kubectl exec <pod> -c hytale-server -- hytale-cli send "/update download"
# Check the logs and wait for the download to finish before applying:
kubectl exec <pod> -c hytale-server -- hytale-cli send "/update apply --confirm"
kubectl logs -f <pod> -c hytale-server
```

The container stays alive while its runner installs the staged package and starts
Java again. Readiness may become false during this period. Keep enough termination
grace for world saving and backups (the chart defaults to 120 seconds; measure your
own workload). If an installation is interrupted, the runner recovers its recorded
transaction on the next start. Do not manually remove that transaction directory.
The file-replacement recovery does not undo world/config migrations after a new
server has started. See the [update and rollback guide](upgrades.md).

Image upgrades and game updates are separate: select a new image tag through Helm
or your Kustomize overlay. With native game updates enabled, set
`HYTALE_AUTO_UPDATE=false` so startup downloads do not overwrite that installation.


## Renew an expired downloader login

Do not delete the PVC or the world directory. Downloader credentials are separate
from server authentication. If a read-only credentials Secret is configured,
replace it with a newly authenticated downloader credentials file, then recreate
the Pod; that Secret is copied to `/data` on startup. `subPath` Secret mounts do not
refresh in an existing container. Keep the Secret current as credentials rotate;
otherwise an old file can overwrite the renewed on-volume credentials next start.

If the login exists only on `/data`, use the recovery Job. It uses the standard
server file paths and may update the game files, so take a data backup first:

1. Record the server's replica count and data PVC name. Scale its StatefulSet or
   Deployment to zero and wait for all server Pods to terminate. Suspend any GitOps
   reconciliation/autoscaling that would recreate them. This avoids concurrent
   writes, even on storage that permits multiple mounts.
2. Copy [renew-downloader-login.yaml](https://github.com/Hybrowse/hytale-server-docker/blob/main/deploy/kubernetes/jobs/renew-downloader-login.yaml)
   and replace `REPLACE_WITH_SERVER_DATA_PVC` with that existing PVC. Use the same
   namespace and, if needed, node placement as the server volume. The Job uses the
   standard UID/GID 1000; mirror any custom data ownership settings from your server.
3. Run the Job and follow its device login:

```bash
kubectl apply -f renew-downloader-login.yaml
kubectl logs -f job/hytale-renew-downloader-login
kubectl wait --for=condition=complete job/hytale-renew-downloader-login --timeout=3600s
```

4. Only after successful completion, remove the Job and scale the server back to
   its recorded replica count. Resume reconciliation if you paused it.

The Job resets only downloader credentials and can download/update server files;
it does not start Java or remove worlds/server credentials. It has no automatic
retry loop and expires after completion. If it fails, inspect the logs before
retrying; remove the failed Job before creating it again. Do not mount the old
credentials Secret or combine credential seeding with reset mode.


## Upgrading existing Helm installations and PVCs

New claims default to 20Gi. This does **not** resize existing claims. Before an
upgrade, save `helm get values <release> --all` and inspect the current StatefulSet
`volumeClaimTemplates` and actual PVCs. Keep the existing template size in your
values during the Helm upgrade (for example `persistence.size=5Gi` for an old
installation); changing a StatefulSet claim template is rejected by Kubernetes.
Do not use `helm upgrade --force` or delete data volumes to work around this.
If your existing values enable startup/liveness probes, explicitly disable them
for manual login or native updates; keeping old values also keeps their old probe
settings. Choose the new readiness-only behavior deliberately.

If your StorageClass supports expansion, request a larger size on each existing
PVC separately and wait for expansion to finish. Some storage drivers require a
Pod restart for filesystem expansion. Back up the data before changes. The
StatefulSet's original template can remain smaller while an existing PVC is larger;
new replicas would still request the template size. Plan a separate controlled
StatefulSet migration if you need a new template size. Existing-claim mode lets
Helm reference a PVC managed outside the chart.

Persistent Deployment mode now uses `Recreate`, so a rollout stops the previous
Pod before starting its replacement. This causes downtime but avoids normal
rolling-update overlap against one world. It requires one replica. StatefulSets
with an explicitly shared `existingClaim` also require one replica; StatefulSets
with independent per-replica PVCs can still use multiple replicas. A PVC's
`ReadWriteOnce` access mode alone does not prevent two Pods on one node from writing
at once. During manual recovery or force deletion, wait for the previous process
to stop before allowing any replacement to access the same volume.

The single-Pod Kustomize production PDB uses `maxUnavailable: 0` and can block
voluntary eviction during node drains. Plan downtime or adjust the budget during
maintenance instead of force-deleting a running server.

Helm's NetworkPolicy, if enabled with its default empty egress rules, blocks
outbound traffic. Configure DNS, HTTPS access for Hytale/downloads and access to
your broker as needed. Kustomize's production policy currently allows all egress;
tighten it for your environment without blocking authentication or updates.


## What the manifest tests cover

`task k8s:test` renders both workload kinds, published-package version overrides,
first-start/native-update/broker values, existing and ephemeral volumes, secret
references, replica guards and every Kustomize overlay (including probes).
It checks Kubernetes schemas and specific safety properties, plus the recovery Job.
Tools run in pinned Docker images by default. For installed Helm, Kustomize and
kubeconform, use `K8S_TEST_TOOLS=local sh ci/test-k8s-manifests.sh` instead.
Python 3 with venv/pip is required; the script installs pinned PyYAML in a temporary
virtual environment and removes it afterwards.

These checks do not start a game server, sign in, mount a real PVC or validate
storage-driver/network behavior in your cluster. Validate those with a separate
test release and disposable data before updating production.
