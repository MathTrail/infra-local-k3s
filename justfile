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
CI_NAMESPACE := "mathtrail-ci"

# Full setup: install tools + create cluster
setup: install install-lens create

# Install prerequisites (Docker check is shared, rest is OS-specific)
install: _check-docker _install-node _install-k3d
    @echo "✅ All prerequisites installed"

_check-docker:
    #!/bin/bash
    command -v docker &>/dev/null || { echo "❌ Docker is required. Install Docker Desktop first"; exit 1; }
    echo "✅ Docker"

# Install OpenLens pod menu extension (shared helper, called from OS-specific install-lens)
_install-lens-extension:
    #!/bin/bash
    set -e
    LENS_EXT_DIR="$HOME/.k8slens/extensions"
    EXT_DIR="$LENS_EXT_DIR/openlens-node-pod-menu"
    if [ -f "$EXT_DIR/package.json" ]; then
        echo "✅ Pod menu extension already installed"
    else
        echo "📥 Installing OpenLens pod menu extension..."
        rm -rf "$LENS_EXT_DIR/node_modules" "$LENS_EXT_DIR/package.json" "$LENS_EXT_DIR/package-lock.json"
        mkdir -p "$EXT_DIR"
        TMP_DIR=$(mktemp -d)
        npm install --prefix "$TMP_DIR" @alebcay/openlens-node-pod-menu
        cp -r "$TMP_DIR/node_modules/@alebcay/openlens-node-pod-menu/"* "$EXT_DIR/"
        rm -rf "$TMP_DIR"
        echo "✅ Pod menu extension installed (restart OpenLens to activate)"
    fi

# Create k3d development cluster
create:
    #!/bin/bash
    set -e
    CLUSTER_NAME="{{ CLUSTER_NAME }}"
    REGISTRY_NAME="{{ REGISTRY_NAME }}"
    REGISTRY_PORT="{{ REGISTRY_PORT }}"
    REGISTRY_FULL="k3d-${REGISTRY_NAME}:${REGISTRY_PORT}"

    if k3d cluster list | grep -q "$CLUSTER_NAME"; then
        if ! kubectl cluster-info --context k3d-$CLUSTER_NAME &>/dev/null 2>&1; then
            echo "⚠️  Cluster is in bad state, removing..."
            just delete
        else
            echo "✅ Cluster '$CLUSTER_NAME' already exists and healthy"
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

    echo "Creating k3d cluster '$CLUSTER_NAME'..."
    k3d cluster create "$CLUSTER_NAME" \
        --servers 1 \
        --agents 2 \
        --port "{{ K3D_PORT_HTTP }}" \
        --port "{{ K3D_PORT_HTTPS }}" \
        --registry-use "$REGISTRY_FULL" \
        --registry-config "{{ justfile_directory() }}/registries.yaml" \
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
    if k3d cluster list | grep -q "$CLUSTER_NAME"; then
        k3d cluster delete "$CLUSTER_NAME" --all
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
    k3d kubeconfig get {{ CLUSTER_NAME }} > ~/.kube/k3d-{{ CLUSTER_NAME }}.yaml
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

# ── GitHub Runner ────────────────────────────────────────────────────────────

# Build and push the CI runner image to k3d registry
build-runner:
    #!/bin/bash
    set -e
    REGISTRY="k3d-mathtrail-registry.localhost:5050"
    IMAGE="${REGISTRY}/ci-runner"
    TAG="latest"
    docker build -t "${IMAGE}:${TAG}" "{{ justfile_directory() }}/runner"
    docker push "${IMAGE}:${TAG}"
    echo "✅ Runner image ready"

# Deploy GitHub self-hosted runner to the cluster
deploy-runner:
    #!/bin/bash
    set -e

    # Load environment
    if [ -f .env ]; then
        set -a
        source .env
        set +a
    else
        echo "❌ Missing .env file. Copy from .env.example and add token:"
        echo "   cp .env.example .env"
        echo "   # Edit .env and set GITHUB_RUNNER_TOKEN"
        exit 1
    fi

    if [ -z "$GITHUB_RUNNER_TOKEN" ]; then
        echo "❌ GITHUB_RUNNER_TOKEN not set in .env"
        exit 1
    fi

    echo "🚀 Deploying GitHub runner..."
    kubectl create namespace {{ CI_NAMESPACE }} 2>/dev/null || true
    helm upgrade --install github-runner ../charts/charts/github-runner \
        --namespace {{ CI_NAMESPACE }} \
        --values values/github-runner-values.yaml \
        --set github.runnerToken="$GITHUB_RUNNER_TOKEN" \
        --wait

    echo ""
    echo "✅ GitHub runner deployed!"

# Remove GitHub runner from the cluster
uninstall-runner:
    #!/bin/bash
    set -e
    echo "🗑️  Removing GitHub runner..."
    helm uninstall github-runner -n {{ CI_NAMESPACE }} 2>/dev/null || true
    kubectl delete namespace {{ CI_NAMESPACE }} --ignore-not-found 2>/dev/null || true
    echo "✅ Runner removed"

# Show GitHub runner status
runner-status:
    #!/bin/bash
    echo "📊 GitHub runner status:"
    kubectl get pods -n {{ CI_NAMESPACE }} -l app.kubernetes.io/name=github-runner 2>/dev/null || echo "  Not deployed"
