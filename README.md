English | [Русский](README.ru.md)

# lolka.nix

Nix flake that packages [Lolka](https://lolka.app), an Electron voice chat and
screen sharing app.

The package repackages the official prebuilt `.deb` from
`https://storage.yandexcloud.net/lolka-electron/releases`. There are no public
sources, so building from source in the Nix sandbox is not an option.

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
- `chrome-sandbox` is removed from the bundle: a copy in the Nix store cannot be
  setuid root, so Chromium falls back to the user-namespace sandbox. If the app
  still fails to start, add `--no-sandbox` to the wrapper flags in `package.nix`.
- Native Node addons for Windows and macOS are shipped in the archive as is.
  `autoPatchelfIgnoreMissingDeps = [ "*" ]` keeps `autoPatchelfHook` from failing
  on them; the tradeoff is that genuinely missing Linux libraries are not
  reported either, so check `nix log` if the app cannot load a module.
- The `.desktop` file and hicolor icons are installed under `$out/share`, and the
  `Exec` line is rewritten to the wrapped `lolka` binary. The file also registers
  the `x-scheme-handler/lolka` MIME type, so `lolka://` links (used by the
  browser login callback) open the app; this needs a desktop environment with
  MIME handler support.
- The app runs an update check against `https://cdn.lolka.app/electron` at startup
  and only creates the main window once the check finishes (successfully or with
  an error). `resources/package-type` must stay in place: it selects the deb
  updater. If it is removed, the app falls back to `AppImageUpdater`, which does
  nothing without `APPIMAGE` set, and the splash screen hangs forever.

## Updating

Versions and hashes live in `sources.json`. Regenerate it with:

```sh
bash scripts/update.sh
```

The script reads `latest-linux.yml` from the upstream release bucket, prefetches
the new `.deb` and rewrites `sources.json`. A scheduled GitHub Actions workflow
(`.github/workflows/update.yml`) runs it daily, builds the package and commits
the result.
