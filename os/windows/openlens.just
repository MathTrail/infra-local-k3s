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
