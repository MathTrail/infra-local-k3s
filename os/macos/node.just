[macos]
_install-node:
    #!/bin/bash
    if command -v node &>/dev/null; then
        echo "✅ Node.js $(node --version)"
    else
        brew install node
    fi
