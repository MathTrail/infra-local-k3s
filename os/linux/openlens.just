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
    # Install pod menu extension
    LENS_EXT_DIR="$HOME/.k8slens/extensions"
    EXT_DIR="$LENS_EXT_DIR/openlens-node-pod-menu"
    if [ -f "$EXT_DIR/package.json" ]; then
        echo "✅ Pod menu extension already installed"
    else
        echo "📥 Installing OpenLens pod menu extension..."
        rm -rf "$LENS_EXT_DIR/node_modules" "$LENS_EXT_DIR/package.json" "$LENS_EXT_DIR/package-lock.json"
        mkdir -p "$EXT_DIR"
        TMP_DIR=$(mktemp -d)
        npm install --prefix "$TMP_DIR" @alebcay/openlens-node-pod-menu
        cp -r "$TMP_DIR/node_modules/@alebcay/openlens-node-pod-menu/"* "$EXT_DIR/"
        rm -rf "$TMP_DIR"
        echo "✅ Pod menu extension installed (restart OpenLens to activate)"
    fi

[linux]
lens:
    open-lens &>/dev/null &
