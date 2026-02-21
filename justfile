# K3d cluster management commands for MathTrail development

set shell := ["bash", "-c"]

# Import OS-specific recipes: _install-node, _install-k3d, install-lens, lens
# Each recipe uses [linux]/[windows]/[macos] attributes — only matching OS is active
import "os/linux.just"
import "os/windows.just"
import "os/macos.just"

# Cluster configuration
CLUSTER_NAME := "mathtrail-dev"
REGISTRY_NAME := "mathtrail-registry"
REGISTRY_PORT := "5050"
K3D_PORT_HTTP := "80:80@loadbalancer"
K3D_PORT_HTTPS := "443:443@loadbalancer"
ARC_NAMESPACE := "arc-systems"
ARC_RUNNERS_NAMESPACE := "arc-runners"

# Full setup: install tools + create cluster
setup: install install-lens create

# Install prerequisites (Docker check is shared, rest is OS-specific)
install: _install-node _install-k3d _install-buildah _install-ansible
    @echo "✅ All prerequisites installed"

# Create k3d development cluster
create:
    #!/bin/bash
    set -e
    CLUSTER_NAME="{{ CLUSTER_NAME }}"
    REGISTRY_NAME="{{ REGISTRY_NAME }}"
    REGISTRY_PORT="{{ REGISTRY_PORT }}"
    REGISTRY_FULL="k3d-${REGISTRY_NAME}:${REGISTRY_PORT}"

    if k3d cluster list | grep -q "${CLUSTER_NAME}"; then
        if ! kubectl cluster-info --context k3d-${CLUSTER_NAME} &>/dev/null 2>&1; then
            echo "⚠️  Cluster is in bad state, removing..."
            just delete
        else
            echo "✅ Cluster '${CLUSTER_NAME}' already exists and healthy"
            exit 0
        fi
    fi

    # Create registry (idempotent)
    if k3d registry list | grep -q "k3d-${REGISTRY_NAME}"; then
        echo "✅ Registry already exists"
    else
        echo "Creating registry on port ${REGISTRY_PORT}..."
        k3d registry create "$REGISTRY_NAME" --port "$REGISTRY_PORT"
    fi

    echo "Creating k3d cluster '${CLUSTER_NAME}'..."
    k3d cluster create "${CLUSTER_NAME}" \
        --servers 1 \
        --agents 2 \
        --port "{{ K3D_PORT_HTTP }}" \
        --port "{{ K3D_PORT_HTTPS }}" \
        --registry-use "$REGISTRY_FULL" \
        --registry-config "{{ justfile_directory() }}/registries.yaml" \
        --k3s-arg "--tls-san=host.docker.internal@server:0" \
        --wait \
        --timeout 120s

    echo "✅ Cluster created"
    just kubeconfig

# Delete cluster and registry
delete:
    #!/bin/bash
    set -e
    CLUSTER_NAME="{{ CLUSTER_NAME }}"
    REGISTRY_NAME="{{ REGISTRY_NAME }}"
    if k3d cluster list | grep -q "${CLUSTER_NAME}"; then
        k3d cluster delete "${CLUSTER_NAME}" --all
        echo "✅ Cluster deleted"
    else
        echo "⚠️  Cluster does not exist"
    fi
    k3d registry delete "k3d-${REGISTRY_NAME}" 2>/dev/null && echo "✅ Registry deleted" || true

# Start cluster
start:
    #!/bin/bash
    set -e
    if ! k3d cluster list | grep -q "{{ CLUSTER_NAME }}"; then
        echo "❌ Cluster does not exist. Run 'just create' first"
        exit 1
    fi
    k3d cluster start {{ CLUSTER_NAME }}
    echo "✅ Cluster started"
    just kubeconfig

# Stop cluster
stop:
    k3d cluster stop {{ CLUSTER_NAME }}

# Cluster status
status:
    #!/bin/bash
    k3d cluster list
    echo ""
    kubectl cluster-info --context k3d-{{ CLUSTER_NAME }} 2>/dev/null || echo "⚠️  Cluster not accessible"

# Get and merge kubeconfig
kubeconfig:
    #!/bin/bash
    set -e
    mkdir -p ~/.kube
    k3d kubeconfig get {{ CLUSTER_NAME }} \
        | sed 's|https://0\.0\.0\.0:|https://host.docker.internal:|g' \
        > ~/.kube/k3d-{{ CLUSTER_NAME }}.yaml
    chmod 600 ~/.kube/k3d-{{ CLUSTER_NAME }}.yaml 2>/dev/null || true
    k3d kubeconfig merge {{ CLUSTER_NAME }} --kubeconfig-merge-default
    echo "✅ Kubeconfig saved and merged into ~/.kube/config"

# Clean up Docker resources
clean:
    #!/bin/bash
    echo "🧹 Cleaning up..."
    STOPPED=$(docker ps -aq -f status=exited)
    [ -n "$STOPPED" ] && docker rm $STOPPED 2>/dev/null || true
    DANGLING=$(docker images -q -f dangling=true)
    [ -n "$DANGLING" ] && docker rmi $DANGLING 2>/dev/null || true
    echo "✅ Cleanup complete"

# ── Platform Environment ─────────────────────────────────────────────────────

# Pull platform-env image and verify it's available for runner builds
pull-platform-env:
    docker pull ghcr.io/mathtrail/platform-env:1
    @echo "✅ platform-env image pulled"

# ── CI Runner Image ─────────────────────────────────────────────────────────

# Build and push the CI runner image to k3d registry
build-runner: _build-runner

# ── GitHub Actions Runner Controller (ARC) ──────────────────────────────────

# Install GitHub Actions Runner Controller (ARC) via Ansible
install-arc:
    #!/bin/bash
    set -e
    if [ ! -f .env ]; then
        echo "❌ Missing .env file. Copy from .env.example:"
        echo "   cp .env.example .env"
        echo "   # Set GitHub App credentials"
        exit 1
    fi
    set -a
    source .env
    set +a
    if [ -z "$GITHUB_APP_ID" ] || [ -z "$GITHUB_APP_INSTALLATION_ID" ] || [ -z "$GITHUB_APP_PRIVATE_KEY_PATH" ]; then
        echo "❌ GitHub App credentials not set in .env"
        echo "   Required: GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID, GITHUB_APP_PRIVATE_KEY_PATH"
        exit 1
    fi
    if [ ! -f "$GITHUB_APP_PRIVATE_KEY_PATH" ]; then
        echo "❌ GitHub App private key not found at: $GITHUB_APP_PRIVATE_KEY_PATH"
        exit 1
    fi
    echo "🚀 Installing GitHub Actions Runner Controller (ARC)..."
    just _ansible-playbook ansible/playbooks/install-arc.yml
    echo ""
    echo "✅ ARC installed! Verify with: just arc-status"

# Delete GitHub Actions Runner Controller (ARC)
delete-arc:
    #!/bin/bash
    set -e
    echo "🗑️  Uninstalling ARC..."
    just _ansible-playbook ansible/playbooks/uninstall-arc.yml
    echo "✅ ARC uninstalled"

# Show ARC runner and controller status
arc-status:
    #!/bin/bash
    echo "📊 ARC Controller:"
    kubectl get pods -n {{ ARC_NAMESPACE }} 2>/dev/null || echo "  Not deployed"
    echo ""
    echo "📊 Runner Pods:"
    kubectl get pods -n {{ ARC_RUNNERS_NAMESPACE }} 2>/dev/null || echo "  No active runners"
    echo ""
    echo "📊 AutoScalingRunnerSet:"
    kubectl get autoscalingrunnersets -n {{ ARC_RUNNERS_NAMESPACE }} 2>/dev/null || echo "  Not configured"
