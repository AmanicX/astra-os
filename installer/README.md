# installer

Planned layout:

```
installer/
├── astra-install          # entry point
├── lib/
│   ├── ui.sh              # gum screens, header, back navigation
│   ├── state.sh           # answers, JSON persistence, logging
│   ├── storage.sh         # GPT, free-space selection, Btrfs subvolumes
│   ├── hw.sh              # data-driven hardware/driver selection
│   ├── pacstrap.sh        # offline install and chroot configuration
│   └── post.sh            # identity, services, snapshots, reboot offer
└── tests/
    ├── fixtures/          # lspci, disk and answers fixtures
    └── e2e/               # QEMU/OVMF end-to-end scripts
```

The prompt order and storage rules are fixed in `docs/INSTALLER.md`. The
installer writes nothing to a disk until the final confirmation screen.
