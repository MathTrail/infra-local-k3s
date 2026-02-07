# MathTrail Infrastructure Local K3d

Local Kubernetes cluster setup using K3d for MathTrail development environment.

## Overview

This repository manages a local K3d (K3s in Docker) cluster that serves as the local development Kubernetes environment for MathTrail. The cluster can be created and managed from your host machine, and DevContainers across the workspace can deploy services to it using Helm.

## Quick Start

### 1. Install K3d

```bash
cd mathtrail-infrastructure-local-k3d
just install
```

### 2. Create Development Cluster

```bash
just create
```

This creates a K3d cluster with:
- 1 server node (control plane)
- 2 agent nodes (workers)
- Built-in container registry for image caching (automatically managed by K3d)
- Port forwarding for HTTP/HTTPS traffic

### 3. Get Kubeconfig

```bash
just kubeconfig
```

This saves the cluster configuration to `~/.kube/k3d-mathtrail-dev.yaml` and makes it accessible to DevContainers.

### 4. Verify Cluster

```bash
just status
```

### 5. Deploy Infrastructure Services

> **Note:** Run these commands inside a DevContainer that has `helm` and `kubectl` configured with access to the cluster (see [DevContainer Integration](#devcontainer-integration) below).

```bash
cd infra
just deploy
```

This deploys the infrastructure used in local development to the cluster using Helm charts from the MathTrail charts repository.

### 6. Remove Infrastructure Services

To tear down all deployed infrastructure services, run inside the DevContainer:

```bash
cd infra
just uninstall
```

This removes all local infrastructure from the cluster.

## DevContainer Integration

### For Helm Deployments from DevContainer

To deploy services from other DevContainers (like `mathtrail-mentor`):

#### 1. Host Machine Setup

First, ensure the cluster is running and kubeconfig is available:

```bash
# In mathtrail-infrastructure-local-k3d directory
just create          # Create cluster once
just kubeconfig      # Generate kubeconfig file
```

#### 2. DevContainer Configuration

Update your DevContainer's `devcontainer.json` to mount the kubeconfig:

```jsonc
{
    "features": {
        "ghcr.io/devcontainers/features/kubectl:1.29.0": {},
        "ghcr.io/devcontainers/features/helm:3.14.0": {}
        // ... other features
    },
    "mounts": [
        "source=${localEnv:HOME}/.kube,target=/root/.kube,type=bind,readonly"
    ],
    "remoteEnv": {
        "KUBECONFIG": "/root/.kube/k3d-mathtrail-dev.yaml"
    }
}
```

#### 3. Verify Access from DevContainer

Inside the DevContainer:

```bash
kubectl cluster-info
kubectl get nodes
helm list
```

### Deploying Applications

Example deployment from mathtrail-mentor DevContainer:

```bash
# Inside DevContainer
helm upgrade --install mathtrail-mentor ./helm/mathtrail-mentor \
    --values ./helm/mathtrail-mentor/values.yaml \
    --kubeconfig /root/.kube/k3d-mathtrail-dev.yaml
```

## Architecture

```
Host Machine
├── Docker Desktop / Docker Engine
│   └── K3d Cluster (mathtrail-dev)
│       ├── Server Node (Control Plane)
│       ├── Agent Node 1
│       ├── Agent Node 2
│       ├── Local Registry (port 5000)
│       └── Ingress Controller
│
└── DevContainers
    ├── mathtrail-mentor
    ├── mathtrail-ui-web
    └── mathtrail-ui-chatgpt
    (All can access cluster via kubeconfig)
```

## Networking

### Port Forwarding

The cluster exposes:
- **HTTP**: localhost:80 → cluster ingress
- **HTTPS**: localhost:443 → cluster ingress
- **Registry**: localhost:5000 → local Docker registry

### DevContainer to Host Cluster Communication

- On Linux: Direct access via Docker network
- On macOS/Windows: Access via `host.docker.internal` or Docker Desktop networking
- Kubeconfig provides necessary connection details

## Container Image Registry

The K3d cluster includes a built-in Docker registry that is automatically managed. This registry is accessible from within the cluster at:

**Registry URL (inside cluster)**: `k3d-registry.localhost:5000`

**Push images from host:**

```bash
# Build image locally
docker build -t myapp:latest .

# Tag for registry (using docker.io registry for host access)
docker tag myapp:latest localhost:5555/myapp:latest

# Push to registry
docker push localhost:5555/myapp:latest

# Use in Kubernetes manifests (from inside cluster)
# image: k3d-registry.localhost:5000/myapp:latest
```

Note: The registry is internal to the cluster and accessible via DNS name from pods. External tagging uses the cluster's mapped ports.

## Troubleshooting

### Cluster creation fails

If `just create` fails with errors about registry nodes or bad state:

```bash
# Completely reset the cluster (removes old containers, networks, volumes)
just delete
just create
```

**Default ports:**
- **HTTP**: 80 (via ingress)
- **HTTPS**: 443 (via ingress)
- **Registry**: Built-in to K3d cluster (no external port needed)

If ports 80 or 443 are already in use, modify them in the `justfile`:

```bash
K3D_PORT_HTTP := "8080:80@loadbalancer"    # Use 8080 instead of 80
K3D_PORT_HTTPS := "8443:443@loadbalancer"  # Use 8443 instead of 443
```

## Performance Considerations

- **Memory**: Default K3d cluster uses ~1-2GB. Monitor Docker Desktop resources.
- **Disk space**: Container images can use several GB. Clean up with `docker system prune`.
- **CPU**: Typically requires 2+ CPU cores.

## Additional Resources

- [K3d Documentation](https://k3d.io/latest/)
- [K3s Documentation](https://docs.k3s.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
