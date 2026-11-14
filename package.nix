{ lib
, stdenv
, fetchurl
, makeWrapper
, autoPatchelfHook
, dpkg
, wrapGAppsHook3
  # Runtime libraries (Linux).
, at-spi2-atk, brotli, bzip2, cairo, dbus, fontconfig, freetype
, gdk-pixbuf, glib, gsettings-desktop-schemas, gtk3, harfbuzz
, libdrm, libgbm, libGL, libkrb5, libpulseaudio
, libx11, libxcb, libxcb-cursor, libxcb-image, libxcb-keysyms
, libxcb-render-util, libxcb-util, libxcb-wm
, libxcomposite, libxdamage, libxext, libxfixes, libxi
, libxkbcommon, libxrandr, libxtst
, openssl, pango, wayland, zlib, zstd
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
    at-spi2-atk brotli bzip2 cairo dbus fontconfig freetype
    gdk-pixbuf glib gtk3 harfbuzz
    libdrm libgbm libGL libkrb5 libpulseaudio
    libx11 libxcb libxcb-cursor libxcb-image libxcb-keysyms
    libxcb-render-util libxcb-util libxcb-wm
    libxcomposite libxdamage libxext libxfixes libxi
    libxkbcommon libxrandr libxtst
    openssl pango wayland zlib zstd
  ];
in
stdenv.mkDerivation {
  pname = "lolka";
  version = sources.version;

  src = fetchurl { inherit (platformSrc) url hash; };

  nativeBuildInputs = [ dpkg makeWrapper wrapGAppsHook3 autoPatchelfHook ];

  buildInputs = runtimeLibs ++ [ gsettings-desktop-schemas stdenv.cc.cc.lib ];

  # Qt and the multimedia stack are bundled. Keep $ORIGIN entries so the app
  # and its plugins can reach the bundled libraries; libglvnd is dlopened by
  # ANGLE and OpenSSL is dlopened by the Qt TLS backend and the FFmpeg stubs,
  # so autoPatchelf cannot discover either one on its own.
  appendRunpaths = [
    "$ORIGIN" "$ORIGIN/../lib" "$ORIGIN/../../lib"
    "${lib.getLib libGL}/lib"
    "${lib.getLib openssl}/lib"
  ];

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
    cp -a src/opt/lolka-x $out/opt/lolka-x

    cp -a src/usr/share/applications $out/share/
    cp -a src/usr/share/icons $out/share/

    # `package-type` tells the app which update channel it was installed from.
    # Keep the bundled copy at $out/opt/lolka-x/package-type.

    makeWrapper $out/opt/lolka-x/bin/lolka-x $out/bin/lolka \
      --prefix PATH : ${lib.makeBinPath [ coreutils gnugrep gnused which xdg-utils glib ]}

    # No LD_LIBRARY_PATH here on purpose. autoPatchelfHook already set RPATH on
    # every bundled ELF, and leaking LD_LIBRARY_PATH would break child processes
    # such as xdg-open -> gio -> browser, which would pick up our glibc instead
    # of their own.

    substituteInPlace $out/share/applications/app.lolka.desktop.qt.desktop \
      --replace-fail "Exec=lolka-x" "Exec=lolka"

    runHook postInstall
  '';

  meta = {
    description = "Chat and voice with friends";
    homepage = "https://lolka.app";
    platforms = [ "x86_64-linux" ];
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "lolka";
  };
}
