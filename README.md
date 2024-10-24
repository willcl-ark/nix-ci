# Example Nix deployment for Bitcoin Core CI

## Administrator prerequisites

An administrator wishing to make this deployment will require a local installation of the [`Nix`](https://nixos.org/download/) (top of page) package manager installed on their host system.

## Available Hardware Configurations

Currently supported hardware types:
- Hetzner ax52 (dual disk configuration)
- Hetzner cx22 (single disk configuration)

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
    $ nix-shell -p nixos-anywhere
    [nix-shell:~/]$ nixos-anywhere --flake .#runnerXX root@<ip address>
    ```

3. Deploy the CIRRUS_WORKER_TOKEN via an "impure" rebuild (which can read env vars):
    ```bash
    $ nix-shell -p nixos-rebuild
    [nix-shell:~/]$ CIRRUS_WORKER_TOKEN="your_token" nixos-rebuild switch --flake .#runnerXX --target-host root@<ip address> --impure --show-trace
    ```

## Update an existing runner

To update an existing runner with a new config is the same as step 3. above:

```bash
$ nix-shell -p nixos-rebuild
[nix-shell:~/]$ CIRRUS_WORKER_TOKEN="your_token" nixos-rebuild switch --flake .#runnerXX --target-host root@<ip address> --impure --show-trace
```

## Adding New Hardware Configurations

To add support for new hardware:

1. Create a new hardware configuration file in *hardware/* directory
2. Configure the worker settings (`name`, `cpu`, `ram`) for Cirrus CI labeling
3. Configure the disk layout and hardware-specific settings
4. Reference the new hardware config in your runner configuration in `flake.nix`

## To-do

- [x] Deploy the cirrus worker token to */etc/cirrus/worker.env*
- [ ] (optional) setup a global shared `remote_dir` for `ccache`
