"""Helpers for scripts/update.py."""

import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path

import yaml

BASE_URL = "https://cdn.lolka.app/electron"
METADATA_URL = f"{BASE_URL}/latest-linux.yml"
SOURCES = Path(__file__).resolve().parent.parent / "sources.json"


def fetch_metadata():
    """Return the latest version, Linux x86_64 artifact and its SRI hash."""
    with urllib.request.urlopen(METADATA_URL, timeout=60) as response:
        meta = yaml.safe_load(response.read())

    try:
        version = meta["version"]
        artifact = meta["path"]
        # The top-level sha512 is the hash of `path`, base64-encoded, which is
        # exactly the payload of an SRI hash.
        hash_ = f"sha512-{meta['sha512']}"
    except (TypeError, KeyError):
        sys.exit(f"unexpected metadata from {METADATA_URL}")
    if not artifact.endswith(".deb"):
        sys.exit(f"unexpected artifact in metadata: {artifact}")
    return version, artifact, hash_


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
