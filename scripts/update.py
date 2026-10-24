#!/usr/bin/env python3
"""Update sources.json from the upstream electron-updater metadata."""

import argparse

from utils import (
    BASE_URL,
    fetch_metadata,
    prefetch,
    read_sources,
    render_sources,
    set_action_output,
    write_sources,
)


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-f", "--force",
        action="store_true",
        help="rewrite sources.json even if the version is already up to date",
    )
    parser.add_argument(
        "--nix-hash",
        action="store_true",
        help="compute the hash with nix instead of using the sha512 from the metadata",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    version, artifact, metadata_hash = fetch_metadata()
    old_text, old_version = read_sources()

    if version == old_version and not args.force:
        print(f"up to date: {version}")
        return

    url = f"{BASE_URL}/{artifact}"
    hash_ = prefetch(url) if args.nix_hash else metadata_hash
    new_text = render_sources(version, url, hash_)
    changed = new_text != old_text

    write_sources(new_text)
    if not changed:
        print(f"up to date: {version}")
        return

    if version == old_version:
        print(f"refreshed: {version}")
    else:
        print(f"updated: {old_version} -> {version}")
    set_action_output(version)


if __name__ == "__main__":
    main()
