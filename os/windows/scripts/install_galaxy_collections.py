"""Download and install Ansible Galaxy collections on Windows without requiring
the Ansible CLI (which doesn't support Windows as a control node).

Reads collections from ansible/requirements.yml and installs them to the default
collections path (~/.ansible/collections/ansible_collections/).

Usage: py scripts/install_galaxy_collections.py
"""
import json
import os
import shutil
import sys
import tarfile
import tempfile
import urllib.request

try:
    import yaml
except ImportError:
    sys.exit("ERROR: PyYAML is required. Install with: py -m pip install pyyaml")

GALAXY_API = "https://galaxy.ansible.com"
COLLECTIONS_PATH = os.path.join(os.path.expanduser("~"), ".ansible", "collections", "ansible_collections")


def get_latest_version(namespace, name):
    """Get the latest version download URL from Galaxy API."""
    url = f"{GALAXY_API}/api/v3/plugin/ansible/content/published/collections/index/{namespace}/{name}/"
    with urllib.request.urlopen(url) as resp:
        data = json.loads(resp.read())
    version_href = data["highest_version"]["href"]

    with urllib.request.urlopen(f"{GALAXY_API}{version_href}") as resp:
        version_data = json.loads(resp.read())
    return version_data["version"], version_data["download_url"]


def install_collection(namespace, name, version_spec=None):
    """Download and install a single collection from Galaxy."""
    dest_dir = os.path.join(COLLECTIONS_PATH, namespace, name)

    version, download_url = get_latest_version(namespace, name)

    if os.path.isdir(dest_dir):
        manifest = os.path.join(dest_dir, "MANIFEST.json")
        if os.path.exists(manifest):
            with open(manifest) as f:
                installed = json.load(f).get("collection_info", {}).get("version", "")
            if installed == version:
                print(f"  ✅ {namespace}.{name} {version} (already installed)")
                return

    print(f"  📥 {namespace}.{name} {version}...")

    with tempfile.TemporaryDirectory() as tmpdir:
        tarball_path = os.path.join(tmpdir, "collection.tar.gz")
        urllib.request.urlretrieve(download_url, tarball_path)

        with tarfile.open(tarball_path, "r:gz") as tar:
            tar.extractall(tmpdir)

        # The tarball extracts to {namespace}-{name}-{version}/
        extracted = os.path.join(tmpdir, f"{namespace}-{name}-{version}")
        if not os.path.isdir(extracted):
            # Try finding the extracted directory
            dirs = [d for d in os.listdir(tmpdir) if os.path.isdir(os.path.join(tmpdir, d))]
            if dirs:
                extracted = os.path.join(tmpdir, dirs[0])
            else:
                sys.exit(f"ERROR: Could not find extracted collection in {tmpdir}")

        if os.path.exists(dest_dir):
            shutil.rmtree(dest_dir)
        os.makedirs(os.path.dirname(dest_dir), exist_ok=True)
        shutil.copytree(extracted, dest_dir)

    print(f"  ✅ {namespace}.{name} {version}")


def main():
    req_file = os.path.join(os.path.dirname(__file__), "..", "..", "..", "ansible", "requirements.yml")
    req_file = os.path.normpath(req_file)

    if not os.path.exists(req_file):
        sys.exit(f"ERROR: Requirements file not found: {req_file}")

    with open(req_file) as f:
        reqs = yaml.safe_load(f)

    collections = reqs.get("collections", [])
    if not collections:
        print("No collections to install.")
        return

    os.makedirs(COLLECTIONS_PATH, exist_ok=True)

    print(f"Installing {len(collections)} collection(s)...")
    for coll in collections:
        name = coll if isinstance(coll, str) else coll["name"]
        version_spec = None if isinstance(coll, str) else coll.get("version")
        namespace, coll_name = name.split(".")
        install_collection(namespace, coll_name, version_spec)

    print("✅ All collections installed")


if __name__ == "__main__":
    main()
