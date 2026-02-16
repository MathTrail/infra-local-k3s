#!/bin/bash
# Windows-native equivalent of: ansible-playbook playbooks/uninstall-arc.yml
# Ansible doesn't support Windows as a control node, so this script replicates
# the Ansible role using kubectl and helm directly.
set -e

# Required for older versions of Helm that treat OCI as experimental
export HELM_EXPERIMENTAL_OCI=1

# ── Load configuration (mirrors ansible/group_vars/all.yml) ─────────────────

KUBECONFIG="${HOME}/.kube/k3d-mathtrail-dev.yaml"
CONTEXT="k3d-mathtrail-dev"

ARC_NAMESPACE="arc-systems"
ARC_RUNNERS_NAMESPACE="arc-runners"
RUNNER_SCALE_SET_NAME="mathtrail-runners"

KC="kubectl --kubeconfig=$KUBECONFIG --context=$CONTEXT"

# ── Uninstall ARC Runner Scale Set ──────────────────────────────────────────

echo "🗑️  Uninstalling ARC runner scale set..."
helm uninstall "$RUNNER_SCALE_SET_NAME" \
    --namespace "$ARC_RUNNERS_NAMESPACE" \
    --kubeconfig "$KUBECONFIG" \
    --kube-context "$CONTEXT" \
    --wait 2>/dev/null || echo "  ⚠️  Runner scale set not found (already removed)"

# ── Uninstall ARC Controller ───────────────────────────────────────────────

echo "🗑️  Uninstalling ARC controller..."
helm uninstall arc-controller \
    --namespace "$ARC_NAMESPACE" \
    --kubeconfig "$KUBECONFIG" \
    --kube-context "$CONTEXT" \
    --wait 2>/dev/null || echo "  ⚠️  Controller not found (already removed)"

# ── Delete Namespaces ──────────────────────────────────────────────────────

echo "🗑️  Deleting namespaces..."
$KC delete namespace "$ARC_RUNNERS_NAMESPACE" --wait=true 2>/dev/null || echo "  ⚠️  Namespace $ARC_RUNNERS_NAMESPACE not found"
$KC delete namespace "$ARC_NAMESPACE" --wait=true 2>/dev/null || echo "  ⚠️  Namespace $ARC_NAMESPACE not found"

echo "✅ ARC uninstalled"
