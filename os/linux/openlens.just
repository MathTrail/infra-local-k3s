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
