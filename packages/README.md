# packages

AstraOS-owned PKGBUILDs live here. Planned packages:

| Package | Purpose |
|---|---|
| `astra-branding` | `os-release`, logo, fastfetch config, wallpapers, GRUB/Plymouth tweaks |
| `astra-desktop-config` | niri, Noctalia, kitty, zsh, Neovim, mpv, btop, GTK/dconf defaults |
| `astra-sddm-theme` | chosen SDDM theme plus `/etc/sddm.conf.d/astra.conf` |
| `astra-keybinds` | keybind overlay generator, QML and toggle script |
| `astra-installer` | `astra-install` and its libraries |
| `astra-updater` | `astra-update`, GUI, polkit policy and systemd units |
| `astra-keyring` | project signing key |
| `astra-meta` | depends on the complete desktop |

No PKGBUILD is written before the Phase 0 gate is approved. Package naming and
file layouts follow Arch packaging conventions; every package is built in a
clean chroot and signed with the Astra key.
