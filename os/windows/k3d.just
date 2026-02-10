[windows]
_install-k3d:
    #!/bin/bash
    if command -v k3d &>/dev/null; then
        echo "✅ k3d $(k3d --version | head -1)"
    else
        echo "📥 Installing k3d..."
        curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    fi
