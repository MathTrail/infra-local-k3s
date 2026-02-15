FROM ghcr.io/actions/actions-runner:2.331.0

# ── Install system dependencies ──────────────────────────────────────────────
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl git unzip ca-certificates jq \
    && rm -rf /var/lib/apt/lists/*

# ── Just ─────────────────────────────────────────────────────────────────────
ARG JUST_VERSION=1.46.0
RUN curl -sSfL https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz \
    | tar xz -C /usr/local/bin just

# ── kubectl ──────────────────────────────────────────────────────────────────
ARG KUBECTL_VERSION=1.35.1
RUN curl -LO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && install kubectl /usr/local/bin/kubectl \
    && rm kubectl

# ── Go ──────────────────────────────────────────────────────────────────
ARG GO_VERSION=1.25.7
RUN curl -LO "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    && tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz" \
    && rm "go${GO_VERSION}.linux-amd64.tar.gz"
ENV PATH="/usr/local/go/bin:${PATH}"

# ── Buildah (rootless container builds) ───────────────────────────────────────
# Pin Buildah from upstream (distro package may be older)
ARG BUILDAH_VERSION=1.43.0
RUN apt-get update && apt-get install -y --no-install-recommends \
        fuse-overlayfs slirp4netns uidmap \
    && curl -sSfL "https://github.com/containers/buildah/releases/download/v${BUILDAH_VERSION}/buildah-v${BUILDAH_VERSION}.linux-amd64.tar.gz" \
        | tar xz -C /usr/local/bin \
    && rm -rf /var/lib/apt/lists/*

# Configure Buildah for rootless operation
RUN mkdir -p /etc/containers && \
    echo '[storage]'                          >  /etc/containers/storage.conf && \
    echo 'driver = "overlay"'                 >> /etc/containers/storage.conf && \
    echo '[storage.options.overlay]'           >> /etc/containers/storage.conf && \
    echo 'mount_program = "/usr/bin/fuse-overlayfs"' >> /etc/containers/storage.conf && \
    echo ''                                   >  /etc/containers/registries.conf && \
    echo '[[registry]]'                       >> /etc/containers/registries.conf && \
    echo 'location = "k3d-mathtrail-registry.localhost:5050"' >> /etc/containers/registries.conf && \
    echo 'insecure = true'                    >> /etc/containers/registries.conf

# ── BuildKit CLI (buildctl — talks to buildkitd sidecar in K3s) ───────────────
ARG BUILDKIT_VERSION=0.27.1
RUN curl -sSfL "https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VERSION}/buildkit-v${BUILDKIT_VERSION}.linux-amd64.tar.gz" \
    | tar xz -C /usr/local/bin --strip-components=1 bin/buildctl

# Point buildctl to the buildkitd sidecar by default
ENV BUILDKIT_HOST="tcp://localhost:1234"

# ── golangci-lint ────────────────────────────────────────────────────────────
ARG GOLANGCI_LINT_VERSION=2.9.0
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/refs/tags/v${GOLANGCI_LINT_VERSION}/install.sh \
    | sh -s -- -b /usr/local/bin v${GOLANGCI_LINT_VERSION}

# ── Back to runner user ──────────────────────────────────────────────────────
USER runner
