#!/usr/bin/env bash
# Install packages that were queued during the offline install.
set -Eeuo pipefail

QUEUE_FILE="/var/lib/astra/pending-packages"
LOG="/var/log/astra-pending-packages.log"

if [[ ! -f "$QUEUE_FILE" ]]; then
	exit 0
fi

echo "Installing pending packages from offline install..." > "$LOG"
while IFS= read -r pkg; do
	echo "Installing $pkg..." >> "$LOG"
	pacman -S --noconfirm --needed "$pkg" >> "$LOG" 2>&1 || echo "Failed to install $pkg" >> "$LOG"
done < "$QUEUE_FILE"

rm -f "$QUEUE_FILE"
