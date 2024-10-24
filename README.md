# Example Nix deployment for Bitcoin Core CI

## Administrator prerequisites

An administrator wishing to make this deployment will require a local installation of the [`Nix`](https://nixos.org/download/) (top of page) package manager installed on their host system.

## Available Hardware Configurations

Currently supported hardware types:
- Hetzner AX52 (dual disk configuration)
- Hetzner AX22 (single disk configuration)

## Provision a new runner

(Most) hosting providers do not yet provide hosts with [NixOS](https://nixos.org/download/) (bottom of page) as an OS.
Therefore the first step is to register a new runner and install NixOS onto it, for which we use [`nixos-anywhere`](https://github.com/nix-community/nixos-anywhere).

1. Add the new runner in *flake.nix* with the appropriate hardware configuration:
    ```nix
    runner03 = mkRunner {
      name = "r03";
      arch = x86_64;
      hardware = "hetzner_ax52";  # or "hetzner_ax22" depending on your hardware
    };
    ```

2. Deploy NixOS onto the host using `nixos-anywhere`:
    ```bash
    $ nix run github:nix-community/nixos-anywhere -- --flake .#runnerXX root@<ip address>
    ```

## Update an existing runner

To update an existing runner:
```bash
$ nix run nixpkgs#nixos-rebuild -- switch --flake .#runner01 --target-host root@<ip address> --show-trace
```

## Adding New Hardware Configurations

To add support for new hardware:

1. Create a new hardware configuration file in `hardware/` directory
2. Set the appropriate `hardware.workerType` for Cirrus CI labeling
3. Configure the disk layout and hardware-specific settings
4. Reference the new hardware config in your runner configuration in `flake.nix`

## To-do

- Deploy the cirrus worker token to */etc/cirrus/worker.env*
- (optional) setup a global shared `remote_dir` for `ccache`
