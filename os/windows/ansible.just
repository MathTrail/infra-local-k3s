[windows]
_install-ansible:
    #!/bin/bash
    set -e
    echo "📦 Installing Ansible collections..."
    # Ansible CLI doesn't support Windows — download collections via Galaxy REST API
    py "{{ justfile_directory() }}/os/windows/scripts/install_galaxy_collections.py"
    echo "✅ Ansible dependencies installed"

# On Windows, ansible-playbook doesn't work (no POSIX support).
# Route install/uninstall to native bash scripts that use kubectl + helm directly.
[windows]
_ansible-playbook *ARGS:
    #!/bin/bash
    set -e
    PLAYBOOK="{{ ARGS }}"
    case "$PLAYBOOK" in
        *uninstall-arc.yml)
            bash "{{ justfile_directory() }}/os/windows/scripts/uninstall-arc.sh"
            ;;
        *install-arc.yml)
            bash "{{ justfile_directory() }}/os/windows/scripts/install-arc.sh"
            ;;
        *)
            echo "❌ Unsupported playbook on Windows: $PLAYBOOK"
            echo "   Ansible doesn't support Windows as a control node."
            exit 1
            ;;
    esac
