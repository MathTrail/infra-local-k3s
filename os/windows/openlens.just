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

[windows]
lens:
    start "" "$LOCALAPPDATA/Programs/OpenLens/OpenLens.exe"
