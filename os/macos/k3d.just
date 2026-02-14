[macos]
_install-k3d:
    #!/bin/bash
    if command -v k3d &>/dev/null; then
        echo "✅ k3d $(k3d --version | head -1)"
    else
        brew install k3d
    fi
