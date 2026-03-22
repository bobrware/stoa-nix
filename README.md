# stoa-nix

Nix flake for installing [Stoa](https://stoa.gg) on NixOS.

## Installation

### Add the flake input

Add `stoa-nix` to your `flake.nix` inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    stoa.url = "github:bobrware/stoa-nix";
    stoa.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, ... }@inputs: {
    nixosConfigurations.yourhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            inputs.stoa.packages.x86_64-linux.stoa
          ];
        })
      ];
    };
  };
}
```

### Home Manager

If you use Home Manager as a flake module:

```nix
{ pkgs, inputs, ... }: {
  home.packages = [
    inputs.stoa.packages.x86_64-linux.stoa
  ];
}
```

### Try it without installing

```sh
nix run github:bobrware/stoa-nix
```

## Updating

The flake automatically tracks new Stoa releases via a GitHub Actions workflow that updates the AppImage hash on each release.

To manually update your lock file:

```sh
nix flake update stoa-nix
```
