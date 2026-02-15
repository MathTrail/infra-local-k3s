FROM ghcr.io/actions/actions-runner:2.331.0

# ── Install system dependencies ──────────────────────────────────────────────
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl git unzip ca-certificates jq \
    && rm -rf /var/lib/apt/lists/*

# ── Just ─────────────────────────────────────────────────────────────────────
ARG JUST_VERSION=1.34.1
RUN curl -sSfL https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz \
    | tar xz -C /usr/local/bin just

# ── kubectl ──────────────────────────────────────────────────────────────────
ARG KUBECTL_VERSION=1.31.7
RUN curl -LO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && install kubectl /usr/local/bin/kubectl \
    && rm kubectl

# ── Go ──────────────────────────────────────────────────────────────────
ARG GO_VERSION=1.25.7
RUN curl -LO "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    && tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz" \
    && rm "go${GO_VERSION}.linux-amd64.tar.gz"
ENV PATH="/usr/local/go/bin:${PATH}"

# ── Docker CLI (client only) ─────────────────────────────────────────────────
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-27.5.1.tgz \
    | tar xz --strip-components=1 -C /usr/local/bin docker/docker

# ── golangci-lint ────────────────────────────────────────────────────────────
ARG GOLANGCI_LINT_VERSION=1.61.0
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/refs/tags/v${GOLANGCI_LINT_VERSION}/install.sh \
    | sh -s -- -b /usr/local/bin v${GOLANGCI_LINT_VERSION}

# ── Back to runner user ──────────────────────────────────────────────────────
USER runner
