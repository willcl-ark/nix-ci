{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    { nixpkgs, disko, ... }:
    let
      x86_64 = "x86_64-linux";

      mkRunner =
        {
          name,
          arch,
          hardware,
        }:
        nixpkgs.lib.nixosSystem {
          system = arch;
          modules = [
            disko.nixosModules.disko
            ./runner.nix
            # Import the specified hardware configuration
            (./hardware + "/${hardware}.nix")
          ];
        };
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
      nixosConfigurations = {
        # runners with different hardware
        runner01 = mkRunner {
          name = "r01";
          arch = x86_64;
          hardware = "hetzner_ax52";
        };
        runner02 = mkRunner {
          name = "r02";
          arch = x86_64;
          hardware = "hetzner_cx22";
        };
      };
    };
}
