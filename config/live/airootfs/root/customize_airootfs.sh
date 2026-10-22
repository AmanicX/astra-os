#!/usr/bin/env bash
# AstraOS live-session setup. Runs inside the airootfs chroot after packages
# are installed and before the squashfs image is created.
set -Eeuo pipefail

live_user="astra"

# The live ISO boots straight into a real desktop session. Create the account
# here so /etc/skel (shipped by astra-desktop-config) is applied exactly once.
if ! id -u "${live_user}" >/dev/null 2>&1; then
	useradd \
		--create-home \
		--user-group \
		--groups wheel,video,render,input,audio,storage,optical,network,power \
		--shell /bin/zsh \
		"${live_user}"
fi

# Live-only credentials. Autologin is enabled below; the password matters only
# for the lock screen and for a tty fallback. Documented in README.md.
printf '%s:%s\n' "${live_user}" "${live_user}" | chpasswd

install -d -m 0755 /etc/sudoers.d
printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "${live_user}" \
	>/etc/sudoers.d/10-astra-live
chmod 0440 /etc/sudoers.d/10-astra-live

# Replace the installer copies from the prebuilt astra-installer package with
# the sources staged by build-iso.sh.  mkarchiso copies a custom airootfs before
# pacstrap, so these cannot be overlaid directly without file conflicts.
if [[ -d /root/astra-installer-overlay ]]; then
	cp -a /root/astra-installer-overlay/. /
	rm -rf /root/astra-installer-overlay
fi

# Seed the pinned LazyVim tree into a writable location. lazy.lua does the same
# on first launch for any newly created user, but doing it here keeps startup
# instant on the live image.
if [[ -d /usr/share/astra/nvim/lazy ]]; then
	install -d -o "${live_user}" -g "${live_user}" \
		"/home/${live_user}/.local/share/nvim"
	rm -rf "/home/${live_user}/.local/share/nvim/lazy"
	cp -a /usr/share/astra/nvim/lazy \
		"/home/${live_user}/.local/share/nvim/lazy"
	chown -R "${live_user}:${live_user}" \
		"/home/${live_user}/.local/share/nvim"
fi

# Graphical target plus the desktop and network services.
systemctl set-default graphical.target
systemctl enable sddm.service
systemctl enable NetworkManager.service
systemctl enable iwd.service
systemctl enable bluetooth.service
systemctl enable power-profiles-daemon.service
systemctl enable getty@tty2.service
# Keep a serial login available for headless installs and for rescue work.
systemctl enable serial-getty@ttyS0.service

# NetworkManager owns link management in the desktop session. The archiso
# networkd default would compete with it. Keep systemd-resolved: the releng
# image points /etc/resolv.conf at its stub, and NetworkManager feeds it DNS.
systemctl disable systemd-networkd.service systemd-networkd.socket \
	systemd-networkd-wait-online.service 2>/dev/null || true
systemctl disable getty@tty1.service 2>/dev/null || true
rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf

# Use iwd as NetworkManager's Wi-Fi backend so iwctl and the Noctalia network
# panel control the same device.
install -d -m 0755 /etc/NetworkManager/conf.d
cat >/etc/NetworkManager/conf.d/20-astra-iwd.conf <<'EOF'
[device]
wifi.backend=iwd
EOF

# The archiso demo automation only runs from a root tty login. AstraOS logs in
# graphically, so remove the dead script instead of leaving a confusing hook.
rm -f /root/.automated_script.sh /root/.zlogin

# Make the bundled local repository available to pacman and the installer.
if ! grep -q '^\[astra-local\]' /etc/pacman.conf; then
	cat >>/etc/pacman.conf <<'EOF'

[astra-local]
SigLevel = Optional TrustAll
Server = file:///usr/share/astra/repo/$arch
EOF
fi

# Sanity checks: fail the ISO build instead of shipping a broken live session.
command -v niri >/dev/null || {
	echo "niri is missing" >&2
	exit 1
}
command -v noctalia >/dev/null || {
	echo "noctalia is missing" >&2
	exit 1
}
command -v sddm >/dev/null || {
	echo "sddm is missing" >&2
	exit 1
}
command -v iwctl >/dev/null || {
	echo "iwctl is missing" >&2
	exit 1
}
[[ -f /usr/share/wayland-sessions/niri.desktop ]] ||
	{
		echo "niri.desktop session file is missing" >&2
		exit 1
	}
