"""Helpers for scripts/update.py."""

import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path

METADATA_URL = "https://updates.lolka.app/desktop/linux/latest"
SOURCES = Path(__file__).resolve().parent.parent / "sources.json"


def fetch_metadata():
    """Return the latest version, Linux x86_64 deb URL and its SRI hash."""
    with urllib.request.urlopen(METADATA_URL, timeout=60) as response:
        meta = json.loads(response.read())

    try:
        version = meta["version"]
        artifact = next(f for f in meta["files"] if f["name"].endswith(".deb"))
        url = artifact["url"]
        # The sha512 is the base64-encoded hash of the artifact, which is
        # exactly the payload of an SRI hash.
        hash_ = f"sha512-{artifact['sha512']}"
    except (TypeError, KeyError, StopIteration):
        sys.exit(f"unexpected metadata from {METADATA_URL}")
    if not url.startswith("https://"):
        sys.exit(f"unexpected artifact URL in metadata: {url}")
    return version, url, hash_


def prefetch(url):
    """Download the artifact and return the SRI hash computed by Nix."""
    result = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", url],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)["hash"]


def read_sources():
    """Return the current sources.json contents and the version it pins."""
    text = SOURCES.read_text()
    return text, json.loads(text).get("version")


def render_sources(version, url, hash_):
    """Render sources.json with a single x86_64-linux entry."""
    sources = {"version": version, "x86_64-linux": {"url": url, "hash": hash_}}
    return json.dumps(sources, indent=2) + "\n"


def write_sources(text):
    SOURCES.write_text(text)


def set_action_output(version):
    """Expose the version to later GitHub Actions steps, if running in CI."""
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a") as file:
            file.write(f"version={version}\n")
