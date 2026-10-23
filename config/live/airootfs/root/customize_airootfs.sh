#!/usr/bin/env bash
# AstraOS live-session setup. Runs inside the airootfs chroot after packages
# are installed and before the squashfs image is created.
#
# The live image is deliberately not a normal user session: it logs root in on
# tty1, starts niri + Noctalia directly, and opens the installer. SDDM is target
# only and must not appear here.
set -Eeuo pipefail

# Sensible fallback credentials for tty2/serial rescue. tty1 uses autologin.
if ! id -u astra >/dev/null 2>&1; then
	# Keep a non-root account for testing the target user flow without adding a
	# second desktop session.
	useradd --create-home --user-group --shell /bin/zsh astra
fi
printf 'astra:astra\n' | chpasswd
printf 'root:astra\n' | chpasswd

# Root desktop configuration comes from the same skel as installed users. The
# live session then gets the installer autostart appended below.
install -d -m 0700 /root
cp -a /etc/skel/. /root/
chown -R root:root /root
if [[ -f /root/.config/niri/config.kdl ]] &&
	! grep -q 'astra-installer' /root/.config/niri/config.kdl; then
	cat >>/root/.config/niri/config.kdl <<'EOF'

// AstraOS live session: window rule to maximize the terminal installer window.
window-rule {
	match app-id="astra-installer"
	open-maximized true
}

// AstraOS live session: open the installer once the desktop is ready.
spawn-at-startup "kitty" "--class" "astra-installer" "astra-install"
EOF
fi

# Root shell entry point. Only tty1 starts the graphical session; other ttys
# stay available for rescue work.  Root's login shell is zsh, so we write
# .zprofile (zsh ignores .bash_profile).
cat >/root/.zprofile <<'EOF'
if [[ -z ${WAYLAND_DISPLAY:-} && $(tty 2>/dev/null) == /dev/tty1 ]]; then
	exec niri --session
fi
EOF
chmod 0644 /root/.zprofile
cp -a /root/.zprofile /root/.bash_profile
install -d -m 0755 /etc/profile.d
cp -a /root/.zprofile /etc/profile.d/99-astra-live.sh

# Replace the installer copies from the prebuilt astra-installer package with
# the sources staged by build-iso.sh. mkarchiso copies a custom airootfs before
# pacstrap, so these cannot be overlaid directly without file conflicts.
if [[ -d /root/astra-installer-overlay ]]; then
	cp -a /root/astra-installer-overlay/. /
	rm -rf /root/astra-installer-overlay
	chmod 0755 /usr/bin/astra-* /usr/lib/astra/installer/pending-packages.sh /usr/lib/astra/installer/astra-engine 2>/dev/null || true
fi

# Seed the pinned LazyVim tree into a writable location. lazy.lua does the same
# on first launch for any newly created user, but doing it here keeps startup
# instant on the live image.
if [[ -d /usr/share/astra/nvim/lazy ]]; then
	install -d -o root -g root /root/.local/share/nvim
	rm -rf /root/.local/share/nvim/lazy
	cp -a /usr/share/astra/nvim/lazy /root/.local/share/nvim/lazy
fi

# Root autologin on tty1. The bash profile above starts niri-session.
install -d -m 0755 /etc/systemd/system/getty@tty1.service.d
cat >/etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin root --noclear %I 38400 linux
EOF

# Graphical target is not used: getty@tty1 owns the display. Keep a serial and
# tty2 login for diagnostics.
systemctl set-default multi-user.target
systemctl enable getty@tty1.service
systemctl enable getty@tty2.service
systemctl enable serial-getty@ttyS0.service
systemctl enable NetworkManager.service
systemctl enable iwd.service
systemctl enable bluetooth.service
systemctl enable power-profiles-daemon.service
systemctl disable sddm.service 2>/dev/null || true

# NetworkManager owns link management in the desktop session. The archiso
# networkd default would compete with it. Keep systemd-resolved: the releng
# image points /etc/resolv.conf at its stub, and NetworkManager feeds it DNS.
systemctl disable systemd-networkd.service systemd-networkd.socket \
	systemd-networkd-wait-online.service 2>/dev/null || true
rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf.orig

# Use iwd as NetworkManager's Wi-Fi backend so iwctl and the Noctalia network
# panel control the same device.
install -d -m 0755 /etc/NetworkManager/conf.d
cat >/etc/NetworkManager/conf.d/20-astra-iwd.conf <<'EOF'
[device]
wifi.backend=iwd
EOF

# The archiso demo automation only runs from a root tty login. AstraOS owns the
# tty1 startup, so remove the dead hook.
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
command -v niri-session >/dev/null || {
	echo "niri-session is missing" >&2
	exit 1
}
command -v noctalia >/dev/null || {
	echo "noctalia is missing" >&2
	exit 1
}
command -v astra-install >/dev/null || {
	echo "astra-install is missing" >&2
	exit 1
}
command -v iwctl >/dev/null || {
	echo "iwctl is missing" >&2
	exit 1
}
[[ -f /usr/share/wayland-sessions/niri.desktop ]] || {
	echo "niri.desktop session file is missing" >&2
	exit 1
}
if command -v sddm >/dev/null 2>&1; then
	echo "sddm must not be installed in the live image" >&2
	exit 1
fi
