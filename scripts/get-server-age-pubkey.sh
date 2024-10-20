set -e

echo "getting an age pubkey from server '$1'"
ssh $1 -C "nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'"
