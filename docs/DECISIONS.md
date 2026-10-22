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

## D-009 — SDDM theme: Noctalia theme with Astra-owned art

The owner chose the `sddm-noctalia-theme` over the active astronaut theme. The
theme is a GPLv3 git clone at `/usr/share/sddm/themes/sddm-noctalia-theme`,
upstream `https://github.com/ClementFombonne/sddm-noctalia-theme.git`, commit
`92bf8e6ff35be19b50b60a38e0f3d6e38e1c66e1`.

The package will:

- pin that commit and ship the GPLv3 license;
- keep the Tabler icon font (MIT, separate license file);
- remove the bundled wallpaper `Assets/Wallpaper/noctalia.png` and the
  screenshot asset, whose provenance is not clear, and install an original
  AstraOS wallpaper at the same path or patch `Commons/Settings.conf` to the
  Astra wallpaper;
- change `fontFamily="Roboto"` to a font the distribution ships (`Noto Sans`)
  unless `ttf-roboto` is added;
- install `/etc/sddm.conf.d/astra.conf` selecting `noctalia-sddm`.

The theme code is redistributable under GPLv3; the removed assets are not
shipped.

**Superseded on 2026-10-20.** The Noctalia SDDM theme rendered incorrectly on
the live ISO, so the owner requested the astronaut theme instead. The package
now pins `keyitdev/sddm-astronaut-theme` at commit
`abb3163c724935af888ba5ea9ac0c4f22afd8048`, ships only the upstream GPL code,
components and icons, removes the unrelated backgrounds, previews, install
helper and bundled fonts, and uses the original AstraOS wallpaper and Adwaita
Sans. `THIRD_PARTY.md` records the narrower asset set.

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

## D-018 — Stable channel: two tracks, OS on GitHub

The owner wants two independent update tracks:

1. **OS track** — the AstraOS base, desktop, drivers, services and `[astra]`
   packages. GitHub hosts the signed `stable.json` and the small `[astra]`
   package artifacts. Arch base packages come from a date-pinned Arch Linux
   Archive; GitHub is not used as a full Arch mirror.
2. **App track** — application updates, using actual upstream stable releases
   rather than beta/nightly builds. The owner's goal is that a buggy app update
   cannot destabilize the OS. The mechanism is deferred (D-026).

The proposed OS shape is
`{ "snapshot": "YYYY/MM/DD", "astra_repo": "...", "notes": "...",
"requires_manual": [] }`, signed with the `astra-keyring` key. The `[astra]`
repository is versioned in lockstep with the snapshot. Directly mixing another
distribution's binary packages into an Arch base is not proposed because of
glibc/ABI and package-manager conflicts.

## D-019 — Steam is approved; gamemode and mangohud are not

The audit found no Steam package or game data. The owner approved Steam for
the installed system. Steam pulls the 32-bit graphics stack and requires the
`multilib` repository. The installer must enable `[multilib]`, and the offline
repository must contain the full multilib closure. `gamemode`, `lib32-gamemode`,
`mangohud` and `lib32-mangohud` remain out of v1 because the owner asked for
Steam only.

Steam is target-only. The live ISO omits it to keep the image smaller; the
installed system includes it (owner-confirmed 2026-10-19).

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

**Addendum 2026-10-21:** the owner explicitly approved the ISO build. The build
was run with `ASTRA_ISO_APPROVED=1`; the resulting image and its verification
are recorded in `docs/BUILD.md` and the final report.

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
selected free sectors, and then compares every original entry, filesystem UUID
and the first-MiB hash after the change. A checksum of the whole GPT table cannot be compared
because adding a partition legitimately changes it. Loopback tests also place a
known pattern inside a dummy existing partition and verify it after the
installer runs; verifying an installed system in QEMU remains a separate test.
No real block device is used in tests.

## D-025 — Gate outcome: approved with changes

The owner approved the Phase 0 include/exclude list with these changes:

- Steam is included for the installed system.
- GIMP is excluded.
- The Noctalia SDDM theme is used with Astra-owned art.
- The current wallpaper is replaced by an original AstraOS wallpaper.
- `linux-lts` is omitted for v1.
- The logo direction is an original geometric star plus wordmark.
- The stable channel is split into OS and app tracks (D-018).
- Privileged work should be unblocked with passwordless sudo for the
  workspace (D-032).

All other proposed inclusions and exclusions stand.

## D-026 — App update track is deferred

The owner chose to decide the app update mechanism later. The OS track is
defined; the app track remains a design placeholder. This does not block
package scaffolding, the installer, or the OS build. Before AstraUpdate is
implemented, the owner must choose between:

1. upstream stable releases built by AstraOS into a signed `[astra-apps]`
   repository, compatibility-gated against the OS snapshot (recommended);
2. Flatpak sandboxed apps for the optional app layer;
3. another distribution's binary packages via containers, which is not native
   and not fully offline by default.

The default app set remains native Arch packages from the pinned OS snapshot
until that decision is made.

## D-027 — GIMP is excluded from v1

The owner excluded GIMP. The approved app set is loupe, pavucontrol, Papers,
GNOME Calculator, GNOME Text Editor and GNOME Disk Utility, plus the other
already-approved apps. No image editor is shipped by default.

## D-028 — Original AstraOS branding

The owner chose an original geometric star plus wordmark and an original
wallpaper. No third-party wallpaper or logo asset is shipped. Branding work is
Phase 5; the final assets must be authored in-repo or generated from
owner-approved source files, with a license recorded in `THIRD_PARTY.md`.

## D-029 — `linux-lts` is omitted from v1

The owner chose to omit `linux-lts`. The default `linux` kernel is the only
kernel installed. `manifests/kernel-lts.txt` stays as a documented option but
is not part of the v1 repository or ISO closure. NVIDIA DKMS for a second
kernel is therefore not required in v1.

## D-030 — Manifests are repository payload, not one install list

The manifest files describe packages that must be available in the offline
repository. They are not a single package list to install everywhere:

- **Target install**: base + desktop + detected driver set + apps + fonts +
  `astra-*`.
- **Live ISO**: base + desktop + curated apps + ISO-only tools. Steam is
  target-only to keep the live image smaller. Proprietary NVIDIA drivers are
  target-only; the live session uses `amdgpu`/`i915`/`xe`/`nouveau`.
- **Repository payload**: both AMD and Intel sets, both NVIDIA branches,
  VMware/VirtualBox guest tools and conditional packages, so the installer can
  work offline on different hardware.

The build scripts will implement these three selections explicitly rather
than installing every manifest line. This distinction is a prerequisite for
computing the repository closure correctly.

## D-031 — Multilib is enabled because Steam is included

Steam is a 32-bit application and depends on the multilib stack. The target
`pacman.conf` will enable `[multilib]`, and the offline repository build will
include multilib packages. The installer must fail with a clear message if the
multilib repository payload is missing.

## D-032 — Passwordless sudo is requested but not yet active

The owner selected passwordless sudo for the workspace. The agent must not ask
for or store the password. The owner will install a sudoers rule themselves.
Until `sudo -n true` succeeds, package installation, loop devices, chroots and
QEMU tests remain blocked. The exact sudoers scope is still to be agreed; a
broad `NOPASSWD: ALL` for the login user is the simplest option but is a real
security trade-off.

## D-033 — The offline guarantee is removed (2026-10-22)

The owner no longer requires the ISO, installer or installed system to work
without a network. Network access at runtime is acceptable. Builds may fetch
packages, fonts, themes and app assets when needed, and the installer may use
online package sources.

This supersedes the offline-first parts of D-001, D-017, D-019, D-023, D-030,
D-031 and the old README claims. The local repository may still be used as a
build cache, but it is no longer a product requirement and should be removed
from the live image when the installer stops depending on it. No silent
downloads or unlicensed assets are allowed; explicit user actions and recorded
licenses still apply.

## D-034 — SilentSDDM with an easy theme switcher

The installed system uses SilentSDDM instead of the earlier
Astronaut/Noctalia SDDM theme. This supersedes the SDDM-theme parts of D-009
and D-025. SilentSDDM is GPL-3.0; its license, any bundled fonts/backgrounds
and the upstream commit must be recorded in `THIRD_PARTY.md`.

The system ships a small command, `astra-sddm-theme`, to list, switch and show
the current SilentSDDM preset. Each preset has its own associated AstraOS
wallpaper. The default is a static image background from
`/usr/share/backgrounds/astraos/`, not an animated background. The SDDM
configuration lives in `/etc/sddm.conf.d/astra.conf`; the theme preset is
selected through the theme's `ConfigFile=configs/<name>.conf` mechanism.

SDDM and the theme are installed on the target and remain out of the live
image. The live image must use root autologin into niri, not a display manager.

## D-035 — Wallpaper sourcing: few original, licensed imports

The default original wallpaper is replaced by a curated set. Keep a small
number of original/generated AstraOS wallpapers and import similar
space/astronomy images from permissively licensed sources (NASA public-domain
media, ESA/Webb under their stated terms, CC0 or CC-BY Wikimedia Commons).
Verify every license, color-grade for the AstraOS palette, and record the
source URL, author, license and modifications in `THIRD_PARTY.md`.

This supersedes the "no third-party wallpaper" rule in D-028 for the Phase 3
wallpaper set. No unlicensed or unverifiable wallpaper is shipped. The
installer, GRUB, Limine, SDDM and Plymouth artwork derive from the approved
set.

## D-036 — Installer UI is tested in WSL first

Before the full QEMU/OVMF matrix, the Rust/Tauri installer is built and run as
a normal app inside the WSL Arch environment, with the mock backend and the
real core where possible. Once it launches, navigates and renders correctly
there, it is tested against QEMU disk images. QEMU remains the only place where
the storage engine and bootloader installation may touch a disk.

## D-037 — Minimum storage is 35 GiB total

The installer requires at least **35 GiB total** for a new installation:
1 GiB ESP plus 34 GiB Btrfs root. This replaces the earlier 25 GiB total /
24 GiB root threshold. Existing code that still says 25/24 must be updated
before it is treated as verified.

## D-038 — One brand identity source

`config/brand.toml` is the single source for the product name, long name, id,
ISO label prefix, website and tagline. `scripts/lib/brand.sh` reads it, and
`scripts/rebrand-archiso.sh` applies the boot-menu names. New installer,
updater, bootloader and theme work must read the same file or a derived
installed copy. The wordmark is mixed-case `Astra` + `OS`; the star mark is
unchanged.
