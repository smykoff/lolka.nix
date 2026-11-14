English | [Русский](README.ru.md)

# lolka.nix

Nix flake that packages [Lolka](https://lolka.app), a chat and voice app.

The package repackages the official prebuilt `.deb` announced by the upstream
release feed at `https://updates.lolka.app/desktop/linux/latest`. There are no
public sources, so building from source in the Nix sandbox is not an option.

## Supported platforms

| System         | Status  |
|----------------|---------|
| `x86_64-linux` | tested  |

Upstream only ships Linux x86_64 packages, so no other systems are exposed.

## Usage

Flakes must be enabled.

Run without installing:

```sh
nix run github:smykoff/lolka.nix
```

Install into the user profile:

```sh
nix profile install github:smykoff/lolka.nix
```

To bump the pinned `nixpkgs` in a local checkout:

```sh
nix flake update
```

### NixOS (flakes)

```nix
{
  inputs.lolka.url = "github:smykoff/lolka.nix";

  outputs = { nixpkgs, lolka, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            lolka.packages.${pkgs.system}.default
          ];
        })
      ];
    };
  };
}
```

Or via the overlay:

```nix
nixpkgs.overlays = [ lolka.overlays.default ];
environment.systemPackages = [ pkgs.lolka ];
```

## Notes

- Libraries are resolved via `RPATH` set by `autoPatchelfHook`. The wrapper does
  not set `LD_LIBRARY_PATH` on purpose: it would leak into child processes such as
  `xdg-open` → `gio` → browser and make them load the flake's glibc instead of
  their own.
- External links (including the browser login flow) are opened through
  `xdg-open`; `glib` is in the wrapper `PATH` so that `xdg-open` can use
  `gio open` under GNOME/Wayland.
- The bundle ships its own Qt 6, FFmpeg, ICU and ONNX Runtime libraries. Only
  the system libraries they link against are taken from nixpkgs via
  `autoPatchelfHook`; `$ORIGIN` runpaths are kept so the app and its plugins can
  still find the bundled ones.
- The `.desktop` file and hicolor icons are installed under `$out/share`, and the
  `Exec` line is rewritten to the wrapped `lolka` binary (upstream uses
  `lolka-x`). The file also registers the `x-scheme-handler/lolka` MIME type, so
  `lolka://` links (used by the browser login callback) open the app; this needs
  a desktop environment with MIME handler support.
- `$out/opt/lolka-x/package-type` is left in place: it tells the app which
  update channel it was installed from.

## Updating

Versions and hashes live in `sources.json`. Regenerate it with:

```sh
python3 scripts/update.py

# Force-updates the hashes even if the version did not change
python3 scripts/update.py --force

# Uses nix store prefetch-file to generate the hash
python3 scripts/update.py --nix-hash
```
