#!/usr/bin/env bash
# Prepare the imported AstraOS WSL instance for installer verification.
# Run as root inside WSL:
#   wsl -d AstraOS -- bash /mnt/d/backup-linux/astraos/tests/wsl-setup.sh
set -euo pipefail

user=astra
logdir=/home/${user}/astraos-tests
log=${logdir}/wsl-setup.log

if ! id "$user" >/dev/null 2>&1; then
	useradd -m -G wheel -s /bin/bash "$user"
fi
printf '%s:%s\n' "$user" "$user" | chpasswd

install -d -m 0755 /etc/sudoers.d
printf '%%wheel ALL=(ALL:ALL) ALL\n' >/etc/sudoers.d/10-astra
chmod 0440 /etc/sudoers.d/10-astra

install -d -o "$user" -g "$user" -m 0755 "$logdir"
cat >/etc/wsl.conf <<'EOF'
[user]
default=astra
EOF

exec > >(tee -a "$log") 2>&1
printf 'AstraOS WSL setup: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
id "$user"
printf 'log directory: %s\n' "$logdir"
