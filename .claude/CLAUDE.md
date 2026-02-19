# CLAUDE.md — infra-local-k3s

## Project Identity

**Repo:** `infra-local-k3s`  
**Purpose:** Provision and manage the local Kubernetes cluster (K3d) for MathTrail development.  
This repo must be set up **first** — all other MathTrail repos depend on the cluster it creates.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Cluster | [K3d](https://k3d.io) (K3s inside Docker) |
| Task runner | [Just](https://just.systems) |
| Container runtime | Docker Desktop / Docker Engine |
| CI runner management | Ansible + [ARC](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller) |
| Container builds | Buildah (host) + BuildKit sidecar (in-cluster) |

---

## Cluster Configuration

| Setting | Value |
|---------|-------|
| Cluster name | `mathtrail-dev` |
| K8s context | `k3d-mathtrail-dev` |
| Kubeconfig path | `~/.kube/k3d-mathtrail-dev.yaml` |
| Server nodes | 1 |
| Agent nodes | 2 |
| HTTP port | `80:80@loadbalancer` |
| HTTPS port | `443:443@loadbalancer` |
| Registry (host) | `k3d-mathtrail-registry.localhost:5050` |
| Registry (in-cluster) | `k3d-mathtrail-registry:5000` |

---

## Key Commands

```bash
# Full setup from scratch
just setup              # install tools + create cluster + install OpenLens

# Step by step
just install            # install k3d, Node.js, Buildah, Ansible + Galaxy collections
just create             # create k3d cluster + registry (idempotent)
just kubeconfig         # save and merge kubeconfig into ~/.kube/config
just status             # verify cluster health
just delete             # delete cluster and registry

# Cluster lifecycle
just start              # start a stopped cluster
just stop               # stop a running cluster
just clean              # remove stopped containers + dangling images

# CI runner image
just build-runner       # build and push ci-runner image to k3d registry

# GitHub Actions Runner Controller (ARC)
just install-arc        # deploy ARC controller + runner scale set via Ansible
just delete-arc         # remove ARC from cluster
just arc-status         # show controller pods, runner pods, AutoScalingRunnerSet
```

---

## File Structure

```
justfile                # main task runner (imports OS-specific recipes)
registries.yaml         # K3d registry mirror config
.env                    # GitHub App credentials (gitignored)
.env.example            # template for .env
.github-app-private-key.pem  # GitHub App private key (gitignored)

ansible/
  ansible.cfg
  requirements.yml                     # kubernetes.core collection
  group_vars/all.yml                   # ARC/runner Helm + k8s configuration
  inventory/local.yml
  playbooks/
    install-arc.yml
    uninstall-arc.yml
  roles/github_arc/                    # ARC controller + runner scale set role

os/                                    # OS-specific just recipes
  linux.just / macos.just / windows.just
  linux/ macos/ windows/
    ansible.just  buildah.just  k3d.just  node.just  openlens.just

runner/
  Dockerfile            # custom CI runner image (actions-runner base)
  justfile              # build/push helpers
```

---

## ARC Configuration (from `ansible/group_vars/all.yml`)

| Setting | Value |
|---------|-------|
| Controller namespace | `arc-systems` |
| Runner namespace | `arc-runners` |
| Runner image | `k3d-mathtrail-registry.localhost:5050/ci-runner:latest` |
| Scale set name | `mathtrail-runners` |
| Min replicas | 1 |
| Max replicas | 5 |
| ARC chart version | `0.10.1` |
| BuildKit sidecar | `moby/buildkit:v0.27.1-rootless` on port `1234` |
| BuildKit cache | `10Gi` |
| GitHub org URL | `https://github.com/MathTrail` |

Workflows target these runners with:
```yaml
runs-on: mathtrail-runners
```

---

## CI Runner Image (`runner/Dockerfile`)

Based on `ghcr.io/actions/actions-runner:2.331.0`. Includes:

| Tool | Version |
|------|---------|
| Go | 1.25.7 |
| kubectl | 1.35.1 |
| Helm | latest (script) |
| Just | 1.46.0 |
| Buildah | apt |
| BuildKit (buildctl) | 0.27.1 |
| Skaffold | 2.17.2 |
| esbuild | 0.27.3 |
| golangci-lint | 2.9.0 |

`BUILDKIT_HOST` defaults to `tcp://localhost:1234` (BuildKit sidecar in ARC pods).

---

## .env Credentials

Required for `just install-arc`:

```bash
GITHUB_APP_ID=<app-id>
GITHUB_APP_INSTALLATION_ID=<installation-id>
GITHUB_APP_PRIVATE_KEY_PATH=./.github-app-private-key.pem
```

Copy `.env.example` → `.env` and fill in values.

---

## DevContainer Integration

Mount kubeconfig so other MathTrail repos can access the cluster:

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

---

## Commit Convention

Use Conventional Commits scoped to `k3s`:

```
feat(k3s): add nginx ingress port forwarding
fix(k3s): correct registry mirror URL
chore(k3s): bump ARC chart to 0.10.1
```

---

## Verification Checklist

```bash
just status                                      # cluster running
kubectl get nodes                                # 3 nodes Ready (1 server + 2 agents)
kubectl get pods -A                              # all system pods Running
curl -s http://k3d-mathtrail-registry.localhost:5050/v2/  # registry responds
just arc-status                                  # ARC deployed (after install-arc)
```
