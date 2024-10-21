{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.sops-nix.url = "github:Mic92/sops-nix";

  outputs =
    {
      nixpkgs,
      disko,
      sops-nix,
      ...
    }:

    let
      # Systems we have a devShell for
      supportedSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: (forSystem system f));

      forSystem =
        system: f:
        f rec {
          inherit system;
          pkgs = import nixpkgs { inherit system; };
        };

      x86_64 = "x86_64-linux";

      # From https://github.com/bitcoin/bitcoin/blob/e8f72aefd20049eac81b150e7f0d33709acd18ed/.cirrus.yml#L15-L18
      # The following specific types should exist, with the following requirements:
      # - small: For an x86_64 machine, with at least 2 vCPUs and 8 GB of memory.
      # - medium: For an x86_64 machine, with at least 4 vCPUs and 16 GB of memory.
      # - arm64: For an aarch64 machine, with at least 2 vCPUs and 8 GB of memory.
      runnerType = {
        small = "small";
        medium = "medium";
        arm64 = "arm64";
      };

      mkRunner =
        name: type: arch:
        nixpkgs.lib.nixosSystem {
          system = arch;
          modules = [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            ./runner.nix
            {
              config._module.args = {
                inherit name arch type;
              };
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        runner01 = mkRunner "runner01" runnerType.small x86_64;
        runner02 = mkRunner "runner02" runnerType.medium x86_64;
      };

      # a shell with all needed tools
      # run with `nix develop`
      devShells = forAllSystems (
        { system, pkgs, ... }:
        {
          default = pkgs.mkShell {
            sopsPGPKeyDirs = [ "${toString ./.}/sops/pubkeys" ];
            buildInputs = [
              pkgs.nixos-rebuild
              pkgs.nixfmt-rfc-style
              pkgs.nixos-anywhere
              (pkgs.callPackage sops-nix { }).sops-import-keys-hook
            ];
          };
        }
      );

    };
}
