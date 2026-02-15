[linux]
_install-buildah:
    #!/bin/bash
    if command -v buildah &>/dev/null; then
        echo "✅ Buildah $(buildah --version | head -1)"
    else
        echo "📥 Installing Buildah..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq buildah
    fi

[linux]
_build-runner:
    #!/bin/bash
    set -e
    REGISTRY="k3d-mathtrail-registry.localhost:5050"
    IMAGE="${REGISTRY}/ci-runner"
    TAG="latest"
    buildah bud -t "${IMAGE}:${TAG}" "{{ justfile_directory() }}/runner"
    buildah push --tls-verify=false "${IMAGE}:${TAG}"
    echo "✅ Runner image ready"
