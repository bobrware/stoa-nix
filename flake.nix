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

    sha256 = "69d30e24b4d2e27934806140b271491f9a8df09eb7ba0a34242f678256ad820e";
  in
    flake-utils.lib.eachSystem [platform] (system: let
      pkgs = import nixpkgs {
        inherit system;
      };
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

      stoa = pkgs.appimageTools.wrapType2 {
        inherit pname version;
        src = appImage;
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
