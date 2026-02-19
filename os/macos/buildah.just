[macos]
_install-buildah:
    #!/bin/bash
    echo "ℹ️  Buildah is not available on macOS — Docker will be used for local builds"

[macos]
_build-runner:
    #!/bin/bash
    set -e
    REGISTRY="k3d-mathtrail-registry.localhost:5050"
    IMAGE="${REGISTRY}/ci-runner"
    TAG="latest"
    docker build -t "${IMAGE}:${TAG}" "{{ justfile_directory() }}/runner"
    docker push "${IMAGE}:${TAG}"
    echo "✅ Runner image ready"
