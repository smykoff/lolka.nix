{ lib
, stdenv
, fetchurl
, makeWrapper
, autoPatchelfHook
, dpkg
, wrapGAppsHook3
  # Runtime libraries (Linux).
, alsa-lib, at-spi2-atk, at-spi2-core, cairo, cups, dbus, expat
, fontconfig, freetype, gdk-pixbuf, glib, gsettings-desktop-schemas, gtk3, libappindicator-gtk3
, libdrm, libgbm, libGL, libnotify, libpulseaudio, libsecret
, libxkbcommon, nspr, nss, pango, pipewire, systemd
, libx11, libxcb, libxcomposite, libxdamage, libxext, libxfixes
, libxrandr, libxrender, libxtst, libXScrnSaver, libuuid, xz
, libdbusmenu
  # Small tools the launcher expects to find on PATH. `glib` from the runtime
  # deps provides `gio`, which xdg-open uses under GNOME.
, coreutils, gnugrep, gnused, which, xdg-utils
}:

let
  inherit (stdenv.hostPlatform) system;

  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  platformSrc = sources.${system}
    or (throw "lolka: unsupported system ${system}");

  runtimeLibs = [
    alsa-lib at-spi2-atk at-spi2-core cairo cups dbus expat
    fontconfig freetype gdk-pixbuf glib gtk3 libappindicator-gtk3
    libdrm libgbm libGL libnotify libpulseaudio libsecret
    libxkbcommon nspr nss pango pipewire systemd
    libx11 libxcb libxcomposite libxdamage libxext libxfixes
    libxrandr libxrender libxtst libXScrnSaver libuuid xz
    libdbusmenu
  ];
in
stdenv.mkDerivation {
  pname = "lolka";
  version = sources.version;

  src = fetchurl { inherit (platformSrc) url hash; };

  nativeBuildInputs = [ dpkg makeWrapper wrapGAppsHook3 autoPatchelfHook ];

  buildInputs = runtimeLibs ++ [ gsettings-desktop-schemas stdenv.cc.cc.lib ];

  # The bundle ships native Node addons built for Windows and macOS.
  autoPatchelfIgnoreMissingDeps = [ "*" ];

  # ANGLE dlopens the system EGL by soname (libEGL.so.1) instead of linking it,
  # so autoPatchelf cannot discover it. Advertise libglvnd in every RUNPATH.
  appendRunpaths = [ "${lib.getLib libGL}/lib" ];

  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    mkdir src
    dpkg-deb --fsys-tarfile "$src" | tar -x -C src
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt $out/bin $out/share
    cp -a src/opt/Lolka $out/opt/Lolka

    cp -a src/usr/share/applications $out/share/
    cp -a src/usr/share/icons $out/share/

    # The in-store copy is not setuid root, so Chromium refuses to use it.
    # Removing it makes Electron fall back to the user-namespace sandbox.
    rm -f $out/opt/Lolka/chrome-sandbox

    # Keep resources/package-type: it selects the deb updater at startup.
    # Without it the app picks AppImageUpdater, which no-ops when APPIMAGE is
    # unset, and the splash screen never hands over to the main window.

    makeWrapper $out/opt/Lolka/lolka $out/bin/lolka \
      --prefix PATH : ${lib.makeBinPath [ coreutils gnugrep gnused which xdg-utils glib ]}

    # No LD_LIBRARY_PATH here on purpose. autoPatchelfHook already set RPATH on
    # every bundled ELF, and leaking LD_LIBRARY_PATH would break child processes
    # such as xdg-open -> gio -> browser, which would pick up our glibc instead
    # of their own.

    substituteInPlace $out/share/applications/lolka.desktop \
      --replace-fail "Exec=/opt/Lolka/lolka" "Exec=lolka"

    runHook postInstall
  '';

  meta = {
    description = "Voice chat and screen sharing application";
    homepage = "https://lolka.app";
    platforms = [ "x86_64-linux" ];
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "lolka";
  };
}
