# Kustomize

Choose an overlay deliberately: the base and development overlay use disposable data, while production adds persistence and network restrictions.


Kustomize manifests live in `deploy/kustomize`.

### Base

`deploy/kustomize/base` is intentionally minimal and uses an `emptyDir` for `/data`.

```bash
kustomize build deploy/kustomize/base | kubectl apply -f -
```

Alternatively, if you prefer using kubectl's built-in kustomize support:

```bash
kubectl kustomize deploy/kustomize/base | kubectl apply -f -
```

The base pins image `hybrowse/hytale-server:1.2.0`. To select a different image,
use an `images` override in your own overlay; do not rely on cached `latest` tags.
The development overlay uses `Always`, but still resolves the pinned version.
Temporary extraction files use disk-backed `emptyDir`, not RAM. Account for
node ephemeral-storage capacity as well as PVC space.

### Overlays

- `deploy/kustomize/overlays/development`: enables auto-download and uses `imagePullPolicy: Always`
- `deploy/kustomize/overlays/production`: enables a 20Gi PVC, PDB, NetworkPolicy, backups and readiness checks
- `deploy/kustomize/overlays/probes`: readiness checks without startup/liveness restart deadlines

```bash
kustomize build deploy/kustomize/overlays/development | kubectl apply -f -
```

With kubectl:

```bash
kubectl kustomize deploy/kustomize/overlays/development | kubectl apply -f -
```

```bash
kustomize build deploy/kustomize/overlays/production | kubectl apply -f -
```

With kubectl:

```bash
kubectl kustomize deploy/kustomize/overlays/production | kubectl apply -f -
```



## Validation

Locally you can validate that the Kubernetes manifests render and pass schema validation:

```bash
task k8s:test
```



Read [Kubernetes operations](kubernetes-operations.md) for login, updates, probes and PVC migrations.
