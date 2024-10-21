# Example Nix deployment for Bitcoin Core CI

## Administrator prerequisites

An administrator wishing to make this deployment will require a local
installation of the [`Nix`](https://nixos.org/download/) (top of page)
package manager installed on their host system.

Once nix is installed, you'll need to enable two experimental features.
The `nix-command` and the `flakes` feature. From there on, you can use
`nix develop` to spawn a shell with all needed dependencies. 

This repository contains an encrypted ssh config for the hosts.
Administrators can edit it with the following command:

```bash
$ sops sops/ssh-config
```

To create a local, decrypted copy use:

```bash
$ sops -d sops/ssh-config > bitcoin-core-ci-ssh.config
```

You can `Include` this config in your personal ssh config (usually in
`~/.ssh/config`) with the following:

```ssh-config
Include /path/to/bitcoin-core-ci-ssh.config
```

## Provision a new runner

(Most) hosting providers do not yet provide hosts with [NixOS](https://nixos.org/download/)
(bottom of page) available as an OS. Therefore the first step is to
register a new runner and install NixOS onto it, for which we use
[`nixos-anywhere`](https://github.com/nix-community/nixos-anywhere).

1. Add a new entry for the host to the encrypted ssh config by running:

   ```bash
   $ sops sops/ssh-config
   ```

   and then updating you local, decrypted copy of it with

   ```bash
   $ sops -d sops/ssh-config > bitcoin-core-ci-ssh.config
   ```

2. Add the new runner in `flake.nix` (e.g. copy `runner01`)
3. Install NixOS on the host with `nixos-anywhere`:

    ```bash
    $ nixos-anywhere --flake .#runnerXX root@runnerXX
    ```

4. Once `nixos-anywhere` finishes, the host will reboot into NixOS.
   However, the host does not have any secrets (e.g. `cirrus-token`)
   yet. To get the `age` pubkey of the runner, run:

    ```bash
    $ sh scripts/get-server-age-pubkey.sh runnerXX
    ```

   Add this pubkey (starting with `age1..`) to the `.sops.yaml` file
   under the `keys` section and create a new rule under the
   `creation_rules` section.

   Create a secrets file with `sops sops/runnerXX.yaml` and paste
   the following template.

   ```yaml
   cirrus.env: CIRRUS_TOKEN=<cirrus-token>
   ```

   Replace `<cirrus-token>` with a Cirrus CI persistent worker pool
   *Registration Token*. You can reuse the token from the other
   runners.

5. Add all new files (`git status`) to git and then redeploy `runnerXX`
   once.

   ```bash
   $ sh deploy.sh runnerXX
   ```

## Update an existing runner

To update, for example, runner `runner01`:

```bash
$ sh deploy.sh runner01
```

## To-do

- Setup a global shared `remote_dir` for `ccache`.
