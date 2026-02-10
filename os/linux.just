# Linux-specific commands

[linux]
install:
    #!/bin/bash
    set -e
    echo "📋 Checking prerequisites..."
    command -v docker &>/dev/null || { echo "❌ Install Docker first"; exit 1; }
    echo "✅ Docker"

    if command -v node &>/dev/null; then
        echo "✅ Node.js $(node --version)"
    else
        echo "📥 Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    if command -v k3d &>/dev/null; then
        echo "✅ k3d $(k3d --version | head -1)"
    else
        echo "📥 Installing k3d..."
        curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    fi

    if command -v just &>/dev/null; then
        echo "✅ just $(just --version)"
    else
        echo "📥 Installing just..."
        curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
    fi

    echo "✅ All prerequisites installed"

[linux]
install-lens:
    #!/bin/bash
    set -e
    if command -v open-lens &>/dev/null; then
        echo "✅ OpenLens is already installed"
    else
        echo "📥 Installing OpenLens..."
        ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
        DEB_URL=$(curl -s https://api.github.com/repos/MuhammedKalkan/OpenLens/releases/latest \
            | grep "browser_download_url.*${ARCH}\.deb" | head -1 | cut -d '"' -f 4)
        if [ -z "$DEB_URL" ]; then
            echo "❌ Could not find .deb for $ARCH"
            echo "   Download from: https://github.com/MuhammedKalkan/OpenLens/releases"
            exit 1
        fi
        curl -fSL "$DEB_URL" -o /tmp/openlens.deb
        sudo dpkg -i /tmp/openlens.deb || sudo apt-get install -f -y
        rm -f /tmp/openlens.deb
        echo "✅ OpenLens installed"
    fi

    just _install-lens-extension

[linux]
lens:
    open-lens &>/dev/null &
