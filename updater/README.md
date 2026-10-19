# updater

Planned layout:

```
updater/
├── astra-update           # CLI
├── gui/                   # GTK4 + libadwaita application
├── polkit/                # policy file and privileged helper
├── systemd/               # astra-update.timer and service
└── config/                # /etc/astra/updater.conf defaults
```

Design is in `docs/UPDATER.md`. The updater follows the stable channel, never
runs the GUI as root, and performs privileged package operations through a
polkit-checked helper.
