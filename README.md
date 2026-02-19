# MathTrail Local K3d Infrastructure

Local Kubernetes cluster setup using K3d for MathTrail development.

## Quick Start

```bash
just setup        # install tools + create cluster + install OpenLens
```

Or step by step:

```bash
just install      # install prerequisites (k3d, Node.js, Buildah)
just create       # create k3d cluster with registry
just kubeconfig   # save kubeconfig to ~/.kube/
just status       # verify cluster health
```

## Cluster Configuration

`just create` provisions a K3d cluster with:

- **1 server** node (control plane) + **2 agent** nodes (workers)
- Container registry at `k3d-mathtrail-registry.localhost:5050`
- Port forwarding: HTTP (80), HTTPS (443)
- Kubeconfig at `~/.kube/k3d-mathtrail-dev.yaml`

## Cluster Commands

| Command | Description |
|---------|-------------|
| `just create` | Create cluster + registry (idempotent) |
| `just delete` | Delete cluster and registry |
| `just start` | Start a stopped cluster |
| `just stop` | Stop running cluster |
| `just status` | Show cluster info |
| `just kubeconfig` | Regenerate and merge kubeconfig |
| `just clean` | Remove stopped containers and dangling images |
| `just install-lens` | Install OpenLens Kubernetes IDE |
| `just lens` | Launch OpenLens |

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

1. Ansible and required Galaxy collections are installed automatically as part of `just install`. If you skipped the full install, run it now:

   ```bash
   just install
   ```

2. Create a GitHub App at `https://github.com/organizations/MathTrail/settings/apps/new` with permissions:
   - Repository: **Actions** (R/W), **Administration** (R/W), **Metadata** (Read)
   - Organization: **Self-hosted runners** (R/W)

3. Install the app to the MathTrail organization and note the **Installation ID** from the URL.

4. Generate a private key (`.pem` file) from the app settings and save it as `.github-app-private-key.pem` in the project root.

5. Configure credentials:

   ```bash
   cp .env.example .env
   # Edit .env with your App ID, Installation ID, and path to .pem file
   ```

### Deploy

```bash
just install        # installs all prerequisites including Ansible (if not done already)
just build-runner   # build custom runner image (if not done already)
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

### Host Setup

Ensure the cluster is running and kubeconfig is generated:

```bash
just create
just kubeconfig
```

### DevContainer Configuration

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
├── Docker Desktop / Docker Engine
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

**Port conflicts** (80/443 in use): edit `justfile` variables:

```
K3D_PORT_HTTP := "8080:80@loadbalancer"
K3D_PORT_HTTPS := "8443:443@loadbalancer"
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
