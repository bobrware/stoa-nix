{
  description = "Stoa desktop application";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }: let
    pname = "stoa";
    version = "v0.2.0";
    platform = "x86_64-linux";
    enableEglWorkarounds = true;
    appName = "Stoa";
    startupWMClass = "stoa";
    categories = "Utility;";

    sha256 = "334d78af8e6dd9ba247bd8e812da6d15cf6488c024cac37bb381abf0f63cb5bb";
  in
    flake-utils.lib.eachSystem [platform] (system: let
      pkgs = import nixpkgs {
        inherit system;
      };

      # Prefer system GTK/WebKit stack and keep bundled libs as fallback.
      # This mirrors the strategy that worked in dataflare-nixos-flake.
      tauriLibs = with pkgs; [
        webkitgtk_4_1
        gtk3
        cairo
        gdk-pixbuf
        glib
        dbus
        openssl
        librsvg
        libsoup_3
        libappindicator-gtk3
        libayatana-appindicator
        stdenv.cc.cc.lib
        alsa-lib
        gnutls
        zlib
        fontconfig
        freetype
        fribidi
        harfbuzz
        expat
        libdrm
        libva
        libGL
        libglvnd
        wayland
        libxkbcommon
        libx11
        libxcb
        libgpg-error
        util-linux
        e2fsprogs
      ];

      releaseVersion =
        if pkgs.lib.hasPrefix "v" version
        then version
        else "v${version}";

      appImage = pkgs.fetchurl {
        url = "https://s3.stoa.gg/stoa/releases/${releaseVersion}/${platform}/stoa.AppImage";
        sha256 =
          if sha256 == ""
          then pkgs.lib.fakeSha256
          else sha256;
      };

      appImageContents = pkgs.appimageTools.extract {
        inherit pname version;
        src = appImage;
      };

      stoa = pkgs.stdenv.mkDerivation {
        inherit pname version;
        src = appImage;

        dontUnpack = true;
        dontStrip = true;

        installPhase = ''
          runHook preInstall

          mkdir -p "$out/bin" "$out/lib/${pname}" "$out/share/applications" "$out/share/icons/hicolor"

          cp -a ${appImageContents}/usr "$out/lib/${pname}/"
          chmod -R u+w "$out/lib/${pname}/usr"

          desktop_source="$(find ${appImageContents} -type f -name '*.desktop' | head -n 1 || true)"
          app_exec=""
          if [ -n "$desktop_source" ]; then
            app_exec="$(awk -F= '$1 == "Exec" { print $2; exit }' "$desktop_source" | sed -E 's/[[:space:]]+%[A-Za-z]//g' | awk '{print $1}')"
          fi

          if [ -z "$app_exec" ] || [ ! -x "$out/lib/${pname}/usr/bin/$app_exec" ]; then
            app_exec="$(basename "$(find "$out/lib/${pname}/usr/bin" -maxdepth 1 -type f -executable | head -n 1)")"
          fi

          if [ -z "$app_exec" ] || [ ! -x "$out/lib/${pname}/usr/bin/$app_exec" ]; then
            echo "Could not determine executable for ${pname}" >&2
            exit 1
          fi

          cat > "$out/bin/${pname}" <<EOF
#!${pkgs.runtimeShell}
set -euo pipefail
export XDG_DATA_DIRS="$out/lib/${pname}/usr/share:/usr/share"
export GSETTINGS_SCHEMA_DIR="$out/lib/${pname}/usr/share/glib-2.0/schemas"
export GIO_EXTRA_MODULES="$out/lib/${pname}/usr/lib/x86_64-linux-gnu/gio/modules"
export GDK_PIXBUF_MODULE_FILE="$out/lib/${pname}/usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/2.10.0/loaders.cache"
export PATH="${pkgs.lib.makeBinPath [ pkgs.xdg-utils pkgs.desktop-file-utils ]}:/run/wrappers/bin:/run/current-system/sw/bin:/usr/bin:/bin"
export APPIMAGE="$out/lib/${pname}/usr/bin/$app_exec"
export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath tauriLibs}"
${pkgs.lib.optionalString enableEglWorkarounds ''
export WEBKIT_DISABLE_DMABUF_RENDERER="1"
export WEBKIT_DISABLE_COMPOSITING_MODE="1"
''}
exec "${pkgs.stdenv.cc.bintools.dynamicLinker}" --library-path "${pkgs.lib.makeLibraryPath tauriLibs}" "$out/lib/${pname}/usr/bin/$app_exec" "\$@"
EOF
          chmod +x "$out/bin/${pname}"

          cat > "$out/share/applications/${pname}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${appName}
Exec=${pname} %U
Icon=${pname}
Terminal=false
Categories=${categories}
StartupWMClass=${startupWMClass}
EOF

          icon_root="${appImageContents}/usr/share/icons/hicolor"
          icon_count=0
          if [ -d "$icon_root" ]; then
            while IFS= read -r -d $'\0' icon; do
              rel_dir="$(dirname "''${icon#"$icon_root"/}")"
              ext="''${icon##*.}"
              mkdir -p "$out/share/icons/hicolor/$rel_dir"
              cp "$icon" "$out/share/icons/hicolor/$rel_dir/${pname}.$ext"
              icon_count=$((icon_count + 1))
            done < <(find "$icon_root" -type f -path '*/apps/*' \( -name '*.png' -o -name '*.svg' -o -name '*.xpm' \) -print0)
          fi

          if [ "$icon_count" -eq 0 ]; then
            fallback_icon="$(find ${appImageContents} -maxdepth 1 -type f \( -name '*.png' -o -name '*.svg' -o -name '*.xpm' \) | head -n 1 || true)"
            if [ -n "$fallback_icon" ]; then
              ext="''${fallback_icon##*.}"
              mkdir -p "$out/share/icons/hicolor/256x256/apps"
              cp "$fallback_icon" "$out/share/icons/hicolor/256x256/apps/${pname}.$ext"
            fi
          fi

          runHook postInstall
        '';
      };
    in {
      packages.stoa = stoa;
      packages.default = stoa;

      apps.stoa = {
        type = "app";
        program = "${stoa}/bin/${pname}";
      };
      apps.default = self.apps.${system}.stoa;
    });
}
