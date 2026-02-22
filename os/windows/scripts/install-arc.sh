#!/bin/bash
# Windows-native equivalent of: ansible-playbook playbooks/install-arc.yml
# Ansible doesn't support Windows as a control node, so this script replicates
# the Ansible role using kubectl and helm directly.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Required for older versions of Helm that treat OCI as experimental
export HELM_EXPERIMENTAL_OCI=1

# Load .env if present (credentials)
if [ -f "$ROOT_DIR/.env" ]; then
    set -a
    source "$ROOT_DIR/.env"
    set +a
fi

# ── Load configuration (mirrors ansible/group_vars/all.yml) ─────────────────

KUBECONFIG="${HOME}/.kube/k3d-mathtrail-dev.yaml"
CONTEXT="k3d-mathtrail-dev"

ARC_NAMESPACE="arc-systems"
ARC_RUNNERS_NAMESPACE="arc-runners"

GITHUB_CONFIG_URL="https://github.com/MathTrail"
RUNNER_IMAGE_REPOSITORY="k3d-mathtrail-registry.localhost:5050/ci-runner"
RUNNER_IMAGE_TAG="latest"
RUNNER_SCALE_SET_NAME="mathtrail-runners"
RUNNER_MIN_REPLICAS=1
RUNNER_MAX_REPLICAS=5

BUILDKIT_ENABLED=true
BUILDKIT_IMAGE="moby/buildkit:v0.27.1-rootless"
BUILDKIT_PORT=1234
BUILDKIT_CACHE_SIZE="10Gi"
BUILDKIT_INSECURE_REGISTRIES=("k3d-mathtrail-registry:5000")

ARC_CONTROLLER_CHART="oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller"
ARC_CONTROLLER_VERSION="0.10.1"
ARC_RUNNER_SET_CHART="oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"
ARC_RUNNER_SET_VERSION="0.10.1"

KC="kubectl --kubeconfig=$KUBECONFIG --context=$CONTEXT"

# ── Validate credentials ────────────────────────────────────────────────────

if [ -z "$GITHUB_APP_ID" ] || [ -z "$GITHUB_APP_INSTALLATION_ID" ] || [ -z "$GITHUB_APP_PRIVATE_KEY_PATH" ]; then
    echo "❌ GitHub App credentials not set"
    echo "   Required: GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID, GITHUB_APP_PRIVATE_KEY_PATH"
    exit 1
fi

if [ ! -f "$GITHUB_APP_PRIVATE_KEY_PATH" ]; then
    echo "❌ GitHub App private key not found at: $GITHUB_APP_PRIVATE_KEY_PATH"
    exit 1
fi

# ── Prerequisites ───────────────────────────────────────────────────────────

echo "📦 Creating namespaces..."
$KC create namespace "$ARC_NAMESPACE" --dry-run=client -o yaml | $KC apply -f -
$KC create namespace "$ARC_RUNNERS_NAMESPACE" --dry-run=client -o yaml | $KC apply -f -

echo "🔑 Creating GitHub App credentials secret..."
PRIVATE_KEY_CONTENT=$(cat "$GITHUB_APP_PRIVATE_KEY_PATH")
$KC create secret generic github-app-credentials \
    --namespace="$ARC_RUNNERS_NAMESPACE" \
    --from-literal="github_app_id=$GITHUB_APP_ID" \
    --from-literal="github_app_installation_id=$GITHUB_APP_INSTALLATION_ID" \
    --from-literal="github_app_private_key=$PRIVATE_KEY_CONTENT" \
    --dry-run=client -o yaml | $KC apply -f -

echo "🔐 Creating RBAC for runner service account..."
$KC apply -f - <<RBAC_EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: arc-runner-sa
  namespace: ${ARC_RUNNERS_NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: arc-runner-cluster-role
rules:
  - apiGroups: [""]
    resources: ["namespaces", "pods", "services", "configmaps", "secrets", "persistentvolumeclaims", "serviceaccounts"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "replicasets", "daemonsets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses", "networkpolicies"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  # PodDisruptionBudgets (Helm charts like PostgreSQL create PDBs)
  - apiGroups: ["policy"]
    resources: ["poddisruptionbudgets"]
    verbs: ["create", "delete", "get", "list", "watch", "patch", "update"]
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["dapr.io"]
    resources: ["components", "configurations", "subscriptions", "resiliencies", "httpendpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["external-secrets.io"]
    resources: ["externalsecrets", "clustersecretstores", "secretstores"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: arc-runner-cluster-role-binding
subjects:
  - kind: ServiceAccount
    name: arc-runner-sa
    namespace: ${ARC_RUNNERS_NAMESPACE}
roleRef:
  kind: ClusterRole
  name: arc-runner-cluster-role
  apiGroup: rbac.authorization.k8s.io
RBAC_EOF

if [ "$BUILDKIT_ENABLED" = true ]; then
    echo "🔧 Creating BuildKit configuration ConfigMap..."
    BUILDKITD_TOML=""
    for registry in "${BUILDKIT_INSECURE_REGISTRIES[@]}"; do
        BUILDKITD_TOML+="[registry.\"${registry}\"]
  http = true
  insecure = true
"
    done
    $KC create configmap buildkitd-config \
        --namespace="$ARC_RUNNERS_NAMESPACE" \
        --from-literal="buildkitd.toml=$BUILDKITD_TOML" \
        --dry-run=client -o yaml | $KC apply -f -
fi

# ── Install ARC Controller ─────────────────────────────────────────────────

echo "🎮 Installing ARC controller..."

# Generate controller values
CONTROLLER_VALUES=$(cat <<'EOF'
replicaCount: 1
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
log:
  level: info
  format: json
serviceAccount:
  create: true
  name: arc-controller
metrics:
  controllerManagerAddr: ":8080"
  listenerAddr: ":8080"
  listenerEndpoint: "/metrics"
EOF
)

CONTROLLER_VALUES_FILE=$(mktemp)
echo "$CONTROLLER_VALUES" > "$CONTROLLER_VALUES_FILE"

helm upgrade --install arc-controller "$ARC_CONTROLLER_CHART" \
    --version "$ARC_CONTROLLER_VERSION" \
    --namespace "$ARC_NAMESPACE" \
    --kubeconfig "$KUBECONFIG" \
    --kube-context "$CONTEXT" \
    --values "$CONTROLLER_VALUES_FILE" \
    --wait --timeout 300s

rm -f "$CONTROLLER_VALUES_FILE"

echo "⏳ Waiting for ARC controller to be ready..."
DEPLOY_NAME=$($KC get deployments -n "$ARC_NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$DEPLOY_NAME" ]; then
    $KC rollout status deployment/"$DEPLOY_NAME" -n "$ARC_NAMESPACE" --timeout=300s
else
    echo "⚠️  No deployment found, waiting for pods..."
    $KC wait --for=condition=ready pod -n "$ARC_NAMESPACE" --all --timeout=300s
fi

# ── Install ARC Runner Scale Set ────────────────────────────────────────────

echo "🏃 Installing ARC runner scale set..."

# Generate runner values
RUNNER_VALUES_FILE=$(mktemp)
cat > "$RUNNER_VALUES_FILE" <<REOF
githubConfigUrl: "${GITHUB_CONFIG_URL}"
githubConfigSecret: github-app-credentials
runnerScaleSetName: "${RUNNER_SCALE_SET_NAME}"
minRunners: ${RUNNER_MIN_REPLICAS}
maxRunners: ${RUNNER_MAX_REPLICAS}
containerMode:
  type: ""
template:
  metadata:
    labels:
      app: github-runner
      runner-set: "${RUNNER_SCALE_SET_NAME}"
  spec:
    serviceAccountName: arc-runner-sa
    containers:
      - name: runner
        image: "${RUNNER_IMAGE_REPOSITORY}:${RUNNER_IMAGE_TAG}"
        imagePullPolicy: Always
        env:
          - name: BUILDKIT_HOST
            value: "tcp://localhost:${BUILDKIT_PORT}"
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "2"
            memory: "2Gi"
        volumeMounts:
          - name: work
            mountPath: /runner/_work
$(if [ "$BUILDKIT_ENABLED" = true ]; then cat <<BEOF
      - name: buildkitd
        image: "${BUILDKIT_IMAGE}"
        imagePullPolicy: IfNotPresent
        args:
          - --addr
          - "tcp://0.0.0.0:${BUILDKIT_PORT}"
          - --oci-worker-no-process-sandbox
          - --config
          - /etc/buildkit/buildkitd.toml
        securityContext:
          runAsUser: 1000
          runAsGroup: 1000
          seccompProfile:
            type: Unconfined
        ports:
          - containerPort: ${BUILDKIT_PORT}
            protocol: TCP
        readinessProbe:
          exec:
            command:
              - buildctl
              - --addr
              - "tcp://localhost:${BUILDKIT_PORT}"
              - debug
              - workers
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          requests:
            cpu: "250m"
            memory: "512Mi"
          limits:
            cpu: "2"
            memory: "4Gi"
        volumeMounts:
          - name: buildkit-cache
            mountPath: /home/user/.local/share/buildkit
          - name: buildkitd-config
            mountPath: /etc/buildkit
            readOnly: true
BEOF
fi)
    volumes:
      - name: work
        emptyDir: {}
$(if [ "$BUILDKIT_ENABLED" = true ]; then cat <<BEOF
      - name: buildkit-cache
        emptyDir:
          sizeLimit: "${BUILDKIT_CACHE_SIZE}"
      - name: buildkitd-config
        configMap:
          name: buildkitd-config
BEOF
fi)
controllerServiceAccount:
  name: arc-controller
  namespace: "${ARC_NAMESPACE}"
REOF

helm upgrade --install "$RUNNER_SCALE_SET_NAME" "$ARC_RUNNER_SET_CHART" \
    --version "$ARC_RUNNER_SET_VERSION" \
    --namespace "$ARC_RUNNERS_NAMESPACE" \
    --kubeconfig "$KUBECONFIG" \
    --kube-context "$CONTEXT" \
    --values "$RUNNER_VALUES_FILE" \
    --wait --timeout 300s

rm -f "$RUNNER_VALUES_FILE"

echo "✅ Runner scale set '${RUNNER_SCALE_SET_NAME}' installed in namespace '${ARC_RUNNERS_NAMESPACE}'"
