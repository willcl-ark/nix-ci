# Example Nix deployment for Bitcoin Core CI

## Administrator prerequisites

An administrator wishing to make this deployment will require a local installation of the [`Nix`](https://nixos.org/download/) (top of page) package manager installed on their host system.

## Provision a new runner

(Most) hosting providers do not yet provide hosts with [NixOS](https://nixos.org/download/) (bottom of page) available as an OS.
Therefore the first step is to register a new runner and install NixOS onto it, for which we use [`nixos-anywhere`](https://github.com/nix-community/nixos-anywhere).

1. Add the new runner in *flake.nix* (e.g. copy `runner01`)
2. Deploy NixOS onto the host `nixos-anywhere` and deploy its configuration:

    ```bash
    $ nix-shell -p nixos-anywhere
    [nix-shell:~/]$ nixos-anywhere --flake .#runnerXX root@<ip address>
    ```

## Update an existing runner

To update `runner01`:

```bash
$ nix-shell -p nixos-rebuild
[nix-shell:~/]$ nixos-rebuild switch --flake .#runner01 --target-host root@<ip address> --show-trace
```

## To-do

- Deploy the cirrus worker token to */etc/cirrus/worker.env*
- Setup a global shared `remote_dir` for `ccache`.
