# macOS-specific commands

[macos]
install:
    #!/bin/bash
    set -e
    echo "📋 Checking prerequisites..."
    command -v docker &>/dev/null || { echo "❌ Install Docker Desktop first"; exit 1; }
    echo "✅ Docker"

    command -v node &>/dev/null || brew install node
    echo "✅ Node.js $(node --version)"

    command -v k3d &>/dev/null || brew install k3d
    echo "✅ k3d"

    command -v just &>/dev/null || brew install just
    echo "✅ just"

    echo "✅ All prerequisites installed"

[macos]
install-lens:
    #!/bin/bash
    set -e
    if brew list --cask openlens &>/dev/null; then
        echo "✅ OpenLens is already installed"
    else
        echo "📥 Installing OpenLens via Homebrew..."
        brew install --cask openlens
        echo "✅ OpenLens installed"
    fi

    just _install-lens-extension

[macos]
lens:
    open -a OpenLens
