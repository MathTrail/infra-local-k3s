[linux]
_install-ansible:
    #!/bin/bash
    set -e
    if command -v ansible &>/dev/null; then
        echo "✅ Ansible already installed"
    else
        echo "📥 Installing Ansible..."
        pip3 install --user ansible
    fi
    echo "📦 Installing Ansible collections..."
    ansible-galaxy collection install -r ansible/requirements.yml --force
    echo "✅ Ansible dependencies installed"
