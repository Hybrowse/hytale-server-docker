# Kubernetes Deployments

This directory contains Kubernetes deployment configurations for the Hytale server using both Kustomize and Helm.

## Directory Structure

```
k8s/
├── kustomize/
│   ├── base/                  # Base Kustomize configuration
│   └── overlays/
│       ├── development/       # Dev environment overlay
│       └── production/        # Production environment overlay
└── helm/
    └── hytale-server/         # Helm chart
```

## Prerequisites

- Kubernetes cluster (v1.20+)
- `kubectl` configured to access your cluster
- For Kustomize: `kubectl` with built-in Kustomize support (v1.14+)
- For Helm: Helm 3.x installed

## Option 1: Deploy with Kustomize

Kustomize provides a template-free way to customize Kubernetes configurations.

### Deploy Development Environment

```bash
kubectl apply -k k8s/kustomize/overlays/development
```

### Deploy Production Environment

```bash
kubectl apply -k k8s/kustomize/overlays/production
```

### View Generated Configuration

```bash
kubectl kustomize k8s/kustomize/overlays/production
```

### Customize

Edit the overlay files to customize your deployment:

- **Development**: `k8s/kustomize/overlays/development/`
- **Production**: `k8s/kustomize/overlays/production/`

Common customizations:
- Resource limits/requests
- Environment variables
- Storage size
- Service type

### Uninstall

```bash
kubectl delete -k k8s/kustomize/overlays/production
```

## Option 2: Deploy with Helm

Helm provides a more flexible templating system with values.yaml configuration.

### Install

```bash
# Install with default values
helm install hytale-server k8s/helm/hytale-server

# Install with custom values
helm install hytale-server k8s/helm/hytale-server -f my-values.yaml

# Install in a specific namespace
helm install hytale-server k8s/helm/hytale-server --namespace hytale --create-namespace
```

### Upgrade

```bash
helm upgrade hytale-server k8s/helm/hytale-server
```

### Uninstall

```bash
helm uninstall hytale-server
```

### Configuration

The Helm chart can be configured via `values.yaml`. See the [values.yaml](helm/hytale-server/values.yaml) file for all available options.

#### Common Configurations

**Change resources:**

```yaml
resources:
  requests:
    memory: "8Gi"
    cpu: "4000m"
  limits:
    memory: "16Gi"
    cpu: "8000m"
```

**Enable backups:**

```yaml
hytale:
  backup:
    enabled: true
    frequencyMinutes: 60
    maxCount: 10
```

**Configure CurseForge mods:**

```yaml
curseforge:
  enabled: true
  apiKey: "your-api-key"
  mods:
    - "advanced-item-info"
    - "project-id:12345"
  autoUpdate: true
  releaseChannel: "release"
```

**Use NodePort service:**

```yaml
service:
  type: NodePort
```

**Use existing PVC:**

```yaml
persistence:
  enabled: true
  existingClaim: "my-existing-pvc"
```

### Helm Values Examples

Create a custom `values.yaml` file:

**Development Environment:**

```yaml
# dev-values.yaml
jvm:
  xms: "2G"
  xmx: "4G"

resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"

hytale:
  authMode: "offline"
  disableSentry: true
  autoUpdate: false

persistence:
  size: 10Gi
```

```bash
helm install hytale-dev k8s/helm/hytale-server -f dev-values.yaml
```

**Production Environment:**

```yaml
# prod-values.yaml
jvm:
  xms: "4G"
  xmx: "8G"

resources:
  requests:
    memory: "8Gi"
    cpu: "4000m"
  limits:
    memory: "16Gi"
    cpu: "8000m"

hytale:
  authMode: "authenticated"
  autoUpdate: true
  backup:
    enabled: true
    frequencyMinutes: 60
    maxCount: 24

persistence:
  size: 50Gi
  storageClass: "fast-ssd"

service:
  type: LoadBalancer
  externalTrafficPolicy: Local
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```

```bash
helm install hytale-prod k8s/helm/hytale-server -f prod-values.yaml --namespace hytale-prod --create-namespace
```

## Post-Deployment Steps

### 1. Watch Deployment

```bash
kubectl get pods -n hytale -w
```

### 2. View Logs

```bash
kubectl logs -n hytale -f deployment/hytale-server
```

### 3. First-Time Downloader Authentication

On first run, watch the logs for the downloader authorization URL and device code:

```bash
kubectl logs -n hytale -f deployment/hytale-server
```

Open the URL in your browser and enter the device code.

### 4. Server Authentication (Required)

After the server starts, you must authenticate it:

```bash
# Attach to the server console
kubectl attach -n hytale -it deployment/hytale-server

# In the console, run:
/auth persistence Encrypted
/auth login device

# Follow the URL + device code shown
# If multiple profiles are shown:
/auth select <number>

# Detach: Ctrl-p then Ctrl-q
```

### 5. Get Server Address

**For LoadBalancer:**

```bash
kubectl get svc -n hytale hytale-server
```

Look for the `EXTERNAL-IP` column.

**For NodePort:**

```bash
kubectl get svc -n hytale hytale-server -o jsonpath='{.spec.ports[0].nodePort}'
```

Connect using: `<node-ip>:<node-port>`

## Storage Considerations

### Persistent Volume

The server data is stored in a PersistentVolumeClaim (PVC). Ensure your cluster has a storage provisioner configured.

**Recommended storage sizes:**
- Development: 10-20 GB
- Production: 50-100 GB

### Storage Class

Specify a storage class for better performance:

**Kustomize:** Edit `persistentvolumeclaim.yaml`

```yaml
spec:
  storageClassName: fast-ssd
```

**Helm:**

```yaml
persistence:
  storageClass: "fast-ssd"
```

### Backup Strategy

1. **Enable built-in backups** (recommended):

```yaml
hytale:
  backup:
    enabled: true
    frequencyMinutes: 60
    maxCount: 24
```

2. **Snapshot the PVC** using your cloud provider's snapshot features

3. **Use Velero** for cluster-level backups

## Network Configuration

### UDP Protocol

Hytale uses **QUIC over UDP** on port 5520. Ensure your cluster and cloud provider support UDP LoadBalancer services.

### Cloud Provider Notes

**AWS:**
- Use Network Load Balancer (NLB):
  ```yaml
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
  ```

**Azure:**
- Standard Load Balancer supports UDP

**GCP:**
- Network Load Balancer supports UDP

**DigitalOcean:**
- Load Balancer supports UDP

### NodePort Alternative

If LoadBalancer is not available:

```yaml
service:
  type: NodePort
```

## Security

### Run as Non-Root

Both configurations run the container as user `1000:1000` (non-root).

### Secrets Management

**Never commit secrets to Git!**

**Helm - Using Kubernetes Secrets:**

```bash
# Create secret separately
kubectl create secret generic hytale-secrets \
  --from-literal=curseforge-api-key="your-api-key" \
  -n hytale

# Reference in values.yaml
curseforge:
  enabled: true
  apiKeySecret:
    name: hytale-secrets
    key: curseforge-api-key
```

**Sealed Secrets / External Secrets:**

For production, use:
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- Cloud provider secret managers (AWS Secrets Manager, Azure Key Vault, GCP Secret Manager)

## Monitoring & Observability

### View Logs

```bash
# Follow logs
kubectl logs -n hytale -f deployment/hytale-server

# View last 100 lines
kubectl logs -n hytale deployment/hytale-server --tail=100
```

### Resource Usage

```bash
kubectl top pod -n hytale
```

### Events

```bash
kubectl get events -n hytale --sort-by='.lastTimestamp'
```

## Troubleshooting

### Pod Not Starting

```bash
kubectl describe pod -n hytale <pod-name>
kubectl logs -n hytale <pod-name>
```

### Storage Issues

```bash
kubectl get pvc -n hytale
kubectl describe pvc -n hytale hytale-server-data
```

### Service Not Accessible

```bash
kubectl get svc -n hytale
kubectl describe svc -n hytale hytale-server
```

### Authentication Issues

See the main [troubleshooting guide](../docs/image/troubleshooting.md).

## Advanced Topics

### Multi-Server Deployment

To run multiple Hytale servers in the same cluster:

```bash
# Install multiple releases with different names
helm install hytale-server1 k8s/helm/hytale-server -f server1-values.yaml
helm install hytale-server2 k8s/helm/hytale-server -f server2-values.yaml
```

### StatefulSet (Alternative)

For more predictable pod naming and ordered deployments, consider converting to StatefulSet.

### Resource Limits

Always set resource limits to prevent resource exhaustion:

```yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "2000m"
  limits:
    memory: "8Gi"
    cpu: "4000m"
```

### Affinity Rules

Pin pods to specific nodes:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-type
          operator: In
          values:
          - game-server
```

## CI/CD Integration

### GitOps with ArgoCD

```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hytale-server
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: HEAD
    path: k8s/helm/hytale-server
  destination:
    server: https://kubernetes.default.svc
    namespace: hytale
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Flux CD

```yaml
# helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: hytale-server
  namespace: hytale
spec:
  interval: 5m
  chart:
    spec:
      chart: ./k8s/helm/hytale-server
      sourceRef:
        kind: GitRepository
        name: hytale-server-repo
  values:
    # Your values here
```

## References

- [Main Documentation](../docs/image/README.md)
- [Quickstart Guide](../docs/image/quickstart.md)
- [Configuration Guide](../docs/image/configuration.md)
- [Troubleshooting](../docs/image/troubleshooting.md)
