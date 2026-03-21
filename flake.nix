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
    version = "v0.0.2";
    platform = "x86_64-linux";
    enableEglWorkarounds = false;
    appName = "Stoa";
    startupWMClass = "stoa";
    categories = "Utility;";

    sha256 = "69d30e24b4d2e27934806140b271491f9a8df09eb7ba0a34242f678256ad820e";
  in
    flake-utils.lib.eachSystem [platform] (system: let
      pkgs = import nixpkgs {
        inherit system;
      };

      # Extra runtime libraries that frequently help Tauri AppImages behave on NixOS.
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

      stoa = pkgs.appimageTools.wrapAppImage {
        inherit pname version;
        src = appImageContents;
        extraPkgs = _: tauriLibs;
        profile = pkgs.lib.optionalString enableEglWorkarounds ''
          # Work around WebKitGTK/EGL initialization failures seen in Tauri AppImages.
          # export WEBKIT_DISABLE_DMABUF_RENDERER="''${WEBKIT_DISABLE_DMABUF_RENDERER:-1}"
          # export WEBKIT_DISABLE_COMPOSITING_MODE="''${WEBKIT_DISABLE_COMPOSITING_MODE:-1}"
        '';

        extraInstallCommands = ''
                    mkdir -p "$out/share/applications" "$out/share/icons/hicolor"

                    desktop_source="$(find ${appImageContents} -type f -name '*.desktop' | head -n 1 || true)"
                    if [ -n "$desktop_source" ]; then
                      echo "Using desktop source metadata from: $desktop_source"
                    fi

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
