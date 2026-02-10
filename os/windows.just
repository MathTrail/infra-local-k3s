# Windows-specific commands (Git Bash / MSYS2)

[windows]
install:
    #!/bin/bash
    set -e
    echo "📋 Checking prerequisites..."
    command -v docker &>/dev/null || { echo "❌ Install Docker Desktop first"; exit 1; }
    echo "✅ Docker"

    if command -v node &>/dev/null; then
        echo "✅ Node.js $(node --version)"
    else
        echo "📥 Installing Node.js..."
        winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements || true
    fi

    if command -v k3d &>/dev/null; then
        echo "✅ k3d $(k3d --version | head -1)"
    else
        echo "📥 Installing k3d..."
        curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    fi

    echo "✅ All prerequisites installed"

[windows]
install-lens:
    #!/bin/bash
    set -e
    LENS_EXE="$LOCALAPPDATA/Programs/OpenLens/OpenLens.exe"
    if [ -f "$LENS_EXE" ]; then
        echo "✅ OpenLens is already installed"
    else
        echo "📥 Installing OpenLens via winget..."
        winget install --id MuhammedKalkan.OpenLens --accept-source-agreements --accept-package-agreements || true
        echo "✅ OpenLens installed"
    fi

    just _install-lens-extension

[windows]
lens:
    start "" "$LOCALAPPDATA/Programs/OpenLens/OpenLens.exe"
