[windows]
_install-ansible:
    #!/bin/bash
    set -e
    if command -v ansible-playbook &>/dev/null; then
        echo "✅ Ansible already installed"
    else
        echo "📥 Installing Ansible..."
        py -m pip install --user ansible
        # Add Python user scripts to PATH for this session
        PYSCRIPTS="$(py -c "import sysconfig; print(sysconfig.get_path('scripts', 'nt_user'))" 2>/dev/null)"
        if [ -n "$PYSCRIPTS" ]; then
            export PATH="$(cygpath "$PYSCRIPTS"):$PATH"
        fi
    fi
    echo "📦 Installing Ansible collections..."
    # Ansible CLI doesn't support Windows — download collections via Galaxy REST API
    py "{{ justfile_directory() }}/os/windows/scripts/install_galaxy_collections.py"
    echo "✅ Ansible dependencies installed"
