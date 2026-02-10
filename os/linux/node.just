[linux]
_install-node:
    #!/bin/bash
    if command -v node &>/dev/null; then
        echo "✅ Node.js $(node --version)"
    else
        echo "📥 Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
