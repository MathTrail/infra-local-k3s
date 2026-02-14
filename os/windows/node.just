[windows]
_install-node:
    #!/bin/bash
    if command -v node &>/dev/null; then
        echo "✅ Node.js $(node --version)"
    else
        echo "📥 Installing Node.js..."
        winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements || true
    fi
