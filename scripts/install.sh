set -e

echo "testing that we can ssh into $1.."
ssh $1 -C "echo 'we can ssh into $1'"

nixos-anywhere --flake .#$1 root@$1 --build-on-remote --copy-host-keys --phases kexec,disko,install,reboot

echo ""
echo "Waiting for the host to come back online after reboot.."
sleep 30

ssh $1 -C "NIX_PATH=nixpkgs=channel:nixos-unstable nix-shell -p ssh-to-age --run 'echo "" && echo "host age pubkey:" && cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'"

echo ""
echo "Host is deployed. Now set up the secrets and then run re-deploy the host."
