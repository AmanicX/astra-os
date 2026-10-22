# AstraOS installer

The installer has two layers:

- `src-tauri/` — the Rust/Tauri GUI. It is the normal live-session installer.
- `astra-engine` — the privileged, non-interactive Bash engine. It parses a
  mode-0600 JSON plan, validates it, and only then calls the tested storage and
  `pacstrap` code in `../packages/astra-installer/lib/`.

The old `astra-install` TUI remains in `../packages/astra-installer/` as a
recovery fallback. The live ISO autostarts `astra-installer-gui`; SDDM is not
present in the live image.

## Safety model

1. The GUI reads `lsblk` and probes hardware. Planning never writes to a disk.
2. The Rust planner checks the 35 GiB total / 34 GiB root floor, the live
   medium, GPT requirements, and the selected partitions.
3. The final **Install AstraOS** button is the only action that starts the
   engine. The plan is written to `/run/astra-install/plan.json` with mode 0600.
4. The engine reads and immediately deletes that file, validates every field
   again, and then runs the storage and target-install functions.
5. Passwords travel only in that file and in the target's mode-0600
   `/tmp/astra-env`; they are never written to `answers.json` or the log.

The engine has no interactive fallback. A missing tool, invalid answer, or
failed package is a hard error with a log path.

## Build and test

```bash
# From the repository root
./scripts/build-installer.sh --check   # cargo tests, no binary copy
./scripts/build-installer.sh --build   # release binary -> packages/astra-installer
```

The binary is built without Node or a frontend bundler. `src-tauri/ui/` is
plain HTML/CSS/JS and is embedded by `tauri-build`.

Headless CLI tests use the same Rust validation and the same engine:

```bash
./installer/src-tauri/target/release/astra-installer --plan-json plan.json
./installer/src-tauri/target/release/astra-installer --install-json plan.json
```

Example `plan.json` for a whole-disk QEMU test:

```json
{
  "storage_mode": "whole",
  "disk": "/dev/vda",
  "esp_mode": "new",
  "esp_part": "",
  "root_part": "",
  "esp_mount": "/boot/efi",
  "premounted_root": "",
  "free_start": 0,
  "free_end": 0,
  "hostname": "astraos",
  "timezone": "UTC",
  "locale": "en_US.UTF-8",
  "kb_layout": "us",
  "user_name": "astra",
  "user_sudo": "passwordless",
  "user_password": "change-me-now",
  "root_password": "change-me-now",
  "extra_packages": "",
  "mirror_source": "ala",
  "mirror_region": "Worldwide",
  "driver_manifests": "",
  "confirmed": true
}
```

Never point `disk` at a real host disk during testing. Use a QEMU image file.

## Layout

```text
installer/
├── src-tauri/
│   ├── src/main.rs     # Tauri commands, discovery, process supervision
│   ├── src/plan.rs     # pure storage plan + Rust unit tests
│   ├── tauri.conf.json
│   └── ui/             # embedded frontend
└── README.md
```

The privileged implementation lives in
`packages/astra-installer/astra-engine` and `packages/astra-installer/lib/`.
