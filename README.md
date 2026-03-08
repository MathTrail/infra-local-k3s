# MathTrail Local K3d Infrastructure

Local Kubernetes cluster setup using K3d for MathTrail development.

## Quick Start

```bash
just setup        # install tools + create cluster
```

Or step by step:

```bash
just install      # install k3d, Node.js, Buildah, OpenLens (+ Helm, kubectl) via Ansible
just create       # create k3d cluster with registry
just status       # verify cluster health
```

## Cluster Configuration

`just create` provisions a K3d cluster with:

- **1 server** node (control plane) + **2 agent** nodes (workers)
- Container registry at `k3d-mathtrail-registry.localhost:5050`
- Port forwarding: HTTP (80), HTTPS (443)
- Kubeconfig merged into `~/.kube/config`

## Cluster Commands

| Command | Description |
|---------|-------------|
| `just setup` | Full setup: install tools + create cluster |
| `just install` | Install prerequisites via Ansible |
| `just create` | Create cluster + registry (idempotent) |
| `just delete` | Delete cluster and registry |
| `just start` | Start a stopped cluster |
| `just stop` | Stop running cluster |
| `just status` | Show cluster info |
| `just clean` | Remove stopped containers and dangling images |

## Container Registry

The cluster includes a local Docker registry:

| Context | URL |
|---------|-----|
| From host | `k3d-mathtrail-registry.localhost:5050` |
| Inside cluster | `k3d-mathtrail-registry:5000` |

Push images from the host (example using Buildah):

```bash
buildah bud -t k3d-mathtrail-registry.localhost:5050/myapp:latest .
buildah push --tls-verify=false k3d-mathtrail-registry.localhost:5050/myapp:latest
```

In Kubernetes manifests, reference images as:

```yaml
image: k3d-mathtrail-registry.localhost:5050/myapp:latest
```

## CI Runner Image

The `runner/` directory contains a custom GitHub Actions runner image with the full CI toolchain:
Go, kubectl, Helm, Skaffold, Buildah, BuildKit, esbuild, golangci-lint, Just.

```bash
just build-runner   # build and push runner image to k3d registry
```

The image is based on `ghcr.io/actions/actions-runner` and is used by ARC runner pods (see below).

## GitHub Actions Runner Controller (ARC)

Self-hosted GitHub Actions runners are deployed via the official [Actions Runner Controller](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller) (ARC), managed with Ansible.

ARC provides auto-scaling ephemeral runners authenticated via a GitHub App.

### Prerequisites

1. Create a GitHub App at `https://github.com/organizations/MathTrail/settings/apps/new` with permissions:
   - Repository: **Actions** (R/W), **Administration** (R/W), **Metadata** (Read)
   - Organization: **Self-hosted runners** (R/W)

2. Install the app to the MathTrail organization and note the **Installation ID** from the URL.

3. Generate a private key (`.pem` file) from the app settings and save it as `.github-app-private-key.pem` in the project root.

4. Configure credentials:

   ```bash
   cp .env.example .env
   # Edit .env with your App ID, Installation ID, and path to .pem file
   ```

### Deploy

```bash
just setup          # install tools + create cluster (if not done already)
just build-runner   # build custom runner image
just install-arc    # deploy ARC controller + runner scale set
```

This creates:
- **arc-systems** namespace — ARC controller
- **arc-runners** namespace — runner pods (auto-scaled 1-5)

Runners use the custom image with a BuildKit sidecar for container builds.

### ARC Commands

| Command | Description |
|---------|-------------|
| `just install-arc` | Deploy ARC controller and runner scale set |
| `just delete-arc` | Remove ARC from cluster |
| `just arc-status` | Show controller, runner pods, and scaling status |
| `just build-runner` | Build and push the CI runner image |

### Runner Labels

Workflows target these runners with:

```yaml
runs-on: mathtrail-runners
```

## DevContainer Integration

All MathTrail repos use DevContainers that connect to this cluster via mounted kubeconfig.

Mount the kubeconfig in `devcontainer.json`:

```jsonc
{
  "mounts": [
    "source=${localEnv:HOME}/.kube,target=/home/vscode/.kube,type=bind,readonly"
  ],
  "remoteEnv": {
    "KUBECONFIG": "/home/vscode/.kube/k3d-mathtrail-dev.yaml"
  }
}
```

Verify from inside the DevContainer:

```bash
kubectl get nodes
helm list -A
```

## Architecture

```
Host Machine
├── Docker Engine
│   └── K3d Cluster (mathtrail-dev)
│       ├── Server Node (control plane)
│       ├── Agent Node 1
│       ├── Agent Node 2
│       └── Registry (k3d-mathtrail-registry:5050)
│
├── DevContainers (access cluster via kubeconfig)
│   ├── mentor-api
│   ├── mathtrail (orchestrator)
│   └── ...
│
└── ARC (GitHub Actions Runner Controller)
    ├── arc-systems    → controller pod
    └── arc-runners    → ephemeral runner pods + BuildKit sidecars
```

## Troubleshooting

**Cluster creation fails:**

```bash
just delete && just create
```

**Port conflicts** (80/443 in use): edit port settings in `ansible/group_vars/all.yml`:

```yaml
k3d_port_http: "8080:80@loadbalancer"
k3d_port_https: "8443:443@loadbalancer"
```

**ARC controller not starting:** check logs:

```bash
kubectl logs -n arc-systems -l app.kubernetes.io/name=gha-runner-scale-set-controller
```

**Runners not scaling:** verify the AutoScalingRunnerSet and workflow labels match:

```bash
kubectl describe autoscalingrunnersets -n arc-runners
```

**Remove ARC completely:**

```bash
just delete-arc
```
