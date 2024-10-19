{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    { nixpkgs, disko, ... }:

    let
      x86_64 = "x86_64-linux";

      mkRunner =
        name: arch:
        nixpkgs.lib.nixosSystem {
          system = arch;
          modules = [
            disko.nixosModules.disko
            ./runner.nix
          ];
        };
    in
    {
      nixosConfigurations = {
        runner01 = mkRunner "r01" x86_64;
      };
    };
}
