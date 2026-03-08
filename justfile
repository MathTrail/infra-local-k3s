# K3d cluster management commands for MathTrail development

set shell := ["bash", "-c"]

CLUSTER_NAME := "mathtrail-dev"
ARC_NAMESPACE := "arc-systems"
ARC_RUNNERS_NAMESPACE := "arc-runners"

# Full setup: install tools + create cluster
setup: install create

# Install prerequisites via Ansible (k3d, Node.js, Buildah, OpenLens + Helm, kubectl from mathtrail.infra)
install:
    ansible-galaxy collection install -r ansible/requirements.yml --force
    ansible-playbook -i ansible/inventory/local.yml playbooks/install.yml --ask-become-pass

# Create k3d cluster + registry (idempotent)
create:
    ansible-playbook -i ansible/inventory/local.yml playbooks/create-cluster.yml

# Delete cluster and registry
delete:
    ansible-playbook -i ansible/inventory/local.yml playbooks/delete-cluster.yml

# Start a stopped cluster
start:
    #!/bin/bash
    set -e
    if ! k3d cluster list | grep -q "{{ CLUSTER_NAME }}"; then
        echo "Cluster does not exist. Run 'just create' first"
        exit 1
    fi
    k3d cluster start {{ CLUSTER_NAME }}

# Stop a running cluster
stop:
    k3d cluster stop {{ CLUSTER_NAME }}

# Verify cluster health
status:
    #!/bin/bash
    k3d cluster list
    echo ""
    kubectl cluster-info --context k3d-{{ CLUSTER_NAME }} 2>/dev/null || echo "Cluster not accessible"

# Remove stopped containers + dangling images
clean:
    #!/bin/bash
    STOPPED=$(docker ps -aq -f status=exited)
    [ -n "$STOPPED" ] && docker rm $STOPPED 2>/dev/null || true
    DANGLING=$(docker images -q -f dangling=true)
    [ -n "$DANGLING" ] && docker rmi $DANGLING 2>/dev/null || true

# ── CI Runner Image ─────────────────────────────────────────────────────────

# Build and push the CI runner image to k3d registry
build-runner:
    cd runner && just push

# ── GitHub Actions Runner Controller (ARC) ──────────────────────────────────

# Install GitHub Actions Runner Controller (ARC) via Ansible
install-arc:
    #!/bin/bash
    set -e
    if [ ! -f .env ]; then
        echo "Missing .env file. Copy from .env.example and fill in GitHub App credentials"
        exit 1
    fi
    set -a; source .env; set +a
    ansible-playbook -i ansible/inventory/local.yml playbooks/install-arc.yml

# Remove ARC from cluster
delete-arc:
    ansible-playbook -i ansible/inventory/local.yml playbooks/uninstall-arc.yml

# Show ARC controller pods, runner pods, AutoScalingRunnerSet
arc-status:
    #!/bin/bash
    echo "ARC Controller:"
    kubectl get pods -n {{ ARC_NAMESPACE }} 2>/dev/null || echo "  Not deployed"
    echo ""
    echo "Runner Pods:"
    kubectl get pods -n {{ ARC_RUNNERS_NAMESPACE }} 2>/dev/null || echo "  No active runners"
    echo ""
    echo "AutoScalingRunnerSet:"
    kubectl get autoscalingrunnersets -n {{ ARC_RUNNERS_NAMESPACE }} 2>/dev/null || echo "  Not configured"
