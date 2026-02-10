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
