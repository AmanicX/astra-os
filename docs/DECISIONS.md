# AstraOS Decisions

Every entry is a choice that is not obvious from the build brief, with the
reason and the verification status. Superseded decisions remain for history.

## D-001 — Repository path

Use `~/astraos` as required by the build brief. The directory is a git
repository. The working directory for this session is the owner's home, but
all project files live under `~/astraos`.

## D-002 — UEFI only, no LUKS in v1

v1 installs only on UEFI systems. The installer exits with an explicit message
on a BIOS/MBR boot. The storage code keeps a narrow interface so LUKS can be
added later without rewriting the pipeline. This follows the brief.

## D-003 — `/boot` inside Btrfs, ESP at `/boot/efi`

The EFI system partition is 1 GiB FAT32 mounted at `/boot/efi`. Kernels and
initramfs images live in the Btrfs root at `/boot`, so snapshots cover them.
GRUB reads the kernel from Btrfs. This is a deliberate trade-off: snapshot
rollback covers kernels, at the cost of needing GRUB Btrfs support and a
correct `grub-install --efi-directory=/boot/efi`. It will be validated in
QEMU before release.

## D-004 — Noctalia and Quickshell come from the official repositories

The audited system has `noctalia 5.3.0-1` and `quickshell 0.3.2-1` from
`extra`, not an AUR git clone. The build will pin the repository snapshot used
for the ISO. No AUR build is needed for Noctalia. Noctalia's license is MIT;
Quickshell's is LGPL-3.0-only.

## D-005 — No separate polkit authentication agent

Noctalia 5.3.0 contains an internal polkit agent (`PolkitAgent`,
`notifications.internal.polkit-agent`). The audited niri config does not spawn
`polkit-gnome` or another agent. The target will ship `polkit` as a dependency
of the desktop stack and rely on Noctalia's agent. If a clean-skel test shows
authentication prompts do not appear, `polkit-gnome` will be added and the
decision revisited.

## D-006 — Mesa packaging in the 2026 snapshot

Current Mesa provides `libva-mesa-driver`; the separate `libva-mesa-driver`
package no longer exists in the Arch package API. `mesa-vdpau` and
`lib32-mesa-vdpau` are also absent from current repositories. The AMD/Intel
driver manifests therefore use `mesa` plus the vendor Vulkan package, and
`libva`/`libva-utils` for VA-API tooling. VDPAU is not assumed. This was
verified against `packages/search/json` and `pacman -Si mesa`.

## D-007 — `1_shell` is the Oh My Posh theme, not a shell or plugin

`~/.config/ohmyposh/1_shell.omp.json` is byte-identical (SHA-256) to the
upstream Oh My Posh theme `themes/1_shell.omp.json`. It is MIT-licensed.
`~/.zshrc` loads it through `oh-my-posh init zsh --config`. No other `1_shell`
component exists in the audited config, `~/.local/share`, or `/opt`.

## D-008 — Oh My Posh is packaged, not hand-installed

The audited host has a manual binary in `~/.local/bin/oh-my-posh` (31.8.0).
The target will install a pinned package from the offline repository
(`oh-my-posh-bin` 31.8.0 is available in the AUR and matches the audited
binary version). The build will pin and verify the source. First-run update
notices and telemetry must be disabled in the shipped environment.

## D-009 — SDDM theme is an open licensing question

Two third-party SDDM themes are installed:

- `sddm-astronaut-theme`, active in `/etc/sddm.conf`, GPL-3.0-or-later code.
  Its README states that many wallpapers and fonts were copied from unknown
  original creators. Those assets are **not cleared for redistribution**.
- `sddm-noctalia-theme`, installed but not active, GPLv3. It includes a
  bundled wallpaper and a Tabler icon font with a separate license file.

No theme will be copied into the repository until the owner chooses one and
confirms asset rights. The default engineering recommendation is the
Noctalia theme because it matches the desktop and has a clearer provenance,
but the active theme is the astronaut theme.

## D-010 — Scrub-check identity handling

The repository must not contain the owner's username, hostname, home path or
email. The scanner therefore derives identities at runtime from:

1. `ASTRA_SCRUB_IDENTITIES` (space-separated), or
2. `ASTRA_SCRUB_IDENTITIES_FILE` (default
   `$XDG_CONFIG_HOME/astra/scrub-identities`), or
3. the current login, `/etc/hostname`, and `$HOME`, excluding generic build
   identities (`root`, `builder`, `astra`, `liveuser`).

The identity file is intentionally outside git. CI must provide it. The ISO
scan is scoped to Astra-owned paths (`/etc/skel`, `/etc/astra`,
`/usr/share/astra`, `/usr/local`, Astra package files and the installer log
copy). A full ISO scan would match upstream package metadata and license
files, which are not personal data; `--full` is available for exhaustive
investigation.

## D-011 — No personal file is copied before the gate

Phase 0 produces only manifests, documentation and the scrub script. The
actual configs are copied or rewritten in later phases, after owner approval,
and are de-personalized on the way in.

## D-012 — Build host cannot currently run privileged phases

`sudo` requires a password. `qemu-system-x86_64`, OVMF, GRUB, snapper, gum and
shellcheck are absent. `/dev/kvm` exists, but `losetup` is denied. Phase 0 is
read-only, so this is not a violation. Phases that need package installation,
loop mounts or QEMU are blocked until the owner provides a non-interactive
privileged path. The agent will not ask for the password.

## D-013 — Verify package names against the sync database and upstream APIs

On 2026-10-19 the full manifest set was checked with `pacman -Si`: 158 of 166
names resolved from the official repositories, and the remaining 8 resolved
through the AUR RPC. There were no unresolved names. Earlier spot checks had
reported some standard packages as missing while `pacman -Ss` and the Arch
package API showed them, so the local database alone is not treated as
infallible. The Arch package API and AUR RPC remain cross-checks. The ISO build
will still use a single pinned Arch Linux Archive date and a fresh sync
database, and the manifest check will be repeated at build time.

## D-014 — Noctalia runtime settings live in state, not config

Noctalia's live settings are in `~/.local/state/noctalia/settings.toml`, not
under `~/.config/noctalia`. The shipped default must therefore seed a
sanitized state file (or use Noctalia's supported defaults mechanism) in
addition to `noctalia-integration.toml`. The current state file contains a
location string, a monitor name and an absolute wallpaper path; none of those
will be shipped as-is.

## D-015 — Keybind overlay data is generated, not shipped

`~/.config/quickshell/keybinds/keybinds.json` contains a hard-coded home path
and is derived from `~/.config/niri/keybinds.kdl`. The package will ship the
parser and QML, generate the JSON at build/first-login time, and write it to a
user-writable location. The shipped config will not contain the audited
absolute path.

## D-016 — Offline Neovim is pre-baked and update checks are disabled

The LazyVim lockfile pins 33 plugins. The ISO build will install them and the
treesitter parsers/Mason tools into the skel data directories. The shipped
`lazy.lua` will set `checker.enabled = false` so Neovim does not make network
requests at first launch. This is a deliberate change from the audited config.

## D-017 — opencode MCP configuration must be offline-safe

The audited `opencode.json` starts Playwright through
`npx -y @playwright/mcp@latest`, which downloads at runtime. That is
incompatible with the offline-first rule. The shipped config will either pin
and vendor the MCP package or omit the MCP server until an offline package is
available. The audited `service.json` contains a credential and is excluded.

## D-018 — Stable channel design is pending owner approval

The proposed default is a signed `stable.json` hosted in a GitHub repository,
with clients pinned to
`https://archive.archlinux.org/repos/YYYY/MM/DD/$repo/os/$arch` and an
`[astra]` repository versioned in lockstep. The Arch Archive is not a
mass-distribution CDN; the long-term path is an AstraOS-hosted snapshot
mirror. The owner must choose between the default and self-hosting.

## D-019 — Steam is not installed on the audited host

The build brief lists Steam as a baseline app, but the audit found no Steam
package or game data. Adding it materially changes ISO size and the 32-bit
graphics closure. It is proposed for approval rather than assumed.

## D-020 — The audit host is AMD-only

The audited laptop has an AMD Ryzen 5 3500U and Radeon Vega graphics, no NVIDIA
GPU. AMD packages are the only hardware path that can be verified on this
machine. Intel and NVIDIA paths will be implemented from fixtures and tested
in QEMU; real NVIDIA/Intel hardware verification remains an owner task in
`docs/HARDWARE-TEST.md`. Intel driver packages found on the host are treated as
repository payload, not as installed defaults for this machine.

## D-021 — No ISO build until the owner says so

The owner has explicitly paused ISO builds. `scripts/build-iso.sh` may be
written and dry-run reviewed, and inputs may be fetched or verified, but no ISO
may be produced until the owner gives an explicit go-ahead. The same caution
applies to repository builds that consume large disk or download subjects:
report the plan and wait.

## D-022 — GRUB is the target bootloader

The audit host uses systemd-boot, but the target will install GRUB. GRUB is
needed for `grub-btrfs` snapshot entries, `os-prober` dual-boot detection and a
single boot menu for both. The host's systemd-boot configuration is not copied
or modified. The target keeps the 1 GiB ESP at `/boot/efi` and kernels in the
Btrfs `/boot` (D-003). `grub-install --efi-directory=/boot/efi` and snapshot
booting will be validated in QEMU before release.

## D-023 — ISO-only packages are a separate manifest

`manifests/iso.txt` holds tools that the live environment needs but the
installed system does not: `arch-install-scripts`, `gum`, `parted`,
`gptfdisk`, `jq`, `pciutils`, `usbutils` and `nano`. The live ISO also gets the
union of the target manifests, so the desktop shown live is the installed
desktop. `astra-installer` is built into the local repository and included in
the ISO, but it is not a dependency of `astra-meta` and is not installed on the
target by default.

## D-024 — Dual-boot safety is guaranteed by construction, then verified

"Existing partitions untouched" means no write is issued to an existing
partition. The installer will never run `wipefs`, `mkfs`, `sgdisk -Z`,
`parted mklabel` or any write against an existing partition. It records every
existing GPT entry (number, start, end, type GUID, unique GUID, name and
filesystem UUID), writes a backup of the GPT table, creates entries only in
selected free sectors, and then compares every original entry and filesystem
UUID after the change. A checksum of the whole GPT table cannot be compared
because adding a partition legitimately changes it. QEMU dual-boot tests will
also place a known pattern inside a dummy existing partition and verify it
after the install. No real block device is used in tests.
