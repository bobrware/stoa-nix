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
  }:
    flake-utils.lib.eachSystem ["x86_64-linux"] (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        version = "v0.1.0"; # Set version here or pass as override
      in {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "stoa";
          inherit version;

          src = pkgs.fetchurl {
            url = "https://stoa.gg/downloads/${version}/${system}/stoa.AppImage";
            sha256 = ""; # TODO: Set correct hash
          };

          appImageContents = pkgs.appimageTools.extractType2 {inherit (self.packages.${system}.default) src;};

          nativeBuildInputs = with pkgs; [makeWrapper];

          unpackPhase = ''
            cp ${self.packages.${system}.default.src} ./stoa.AppImage
            chmod +x ./stoa.AppImage
            ${pkgs.appimageTools.extractType2 {inherit (self.packages.${system}.default) src;}}/AppRun --appimage-extract
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp squashfs-root/stoa $out/bin/stoa
            chmod +x $out/bin/stoa
          '';

          meta = with pkgs.lib; {
            description = "Stoa desktop application";
            platforms = ["x86_64-linux"];
          };
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/stoa";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            self.packages.${system}.default
          ];
        };
      }
    );
}
