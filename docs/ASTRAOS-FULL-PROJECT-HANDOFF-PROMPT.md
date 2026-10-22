# AstraOS — Full Project Handoff Prompt

> **Give this entire file to the new coding agent.** It is both the product
> specification and the handoff brief. The agent should read it fully before
> changing anything, then work autonomously until the acceptance criteria at
> the end are met.

**Project:** AstraOS — an Arch-based, UEFI-only Linux distribution built around
Niri and Noctalia v5.

**Project location (canonical):** `D:\backup-linux\astraos` on the current
Windows host, mounted in WSL as `/mnt/d/backup-linux/astraos`.

This is the owner's live checkout and will continue to be used after the
handoff. Do not move, rename, delete, or relocate it. Work in this checkout, and
copy it to the WSL ext4 build tree only when building the ISO.

**Reference build host:** WSL distribution `AstraOS` (Arch Linux), root build
tree at `/root/astraos-build`. The build tree is a disposable copy; the
canonical source remains `D:\backup-linux\astraos`.

**Handoff date:** 2026-10-22.

**Current state:** in progress. Phase 1 is committed; Phase 2/3 changes are in
the working tree; the Tauri frontend is missing; the final ISO has not been
rebuilt or tested. Details are in section 2. Do not treat the repository as a
finished release.

---

## 0. Your role and operating rules

You are the lead engineer taking AstraOS from its current partial state to a
verified, bootable release image.

Rules:

1. **Read the repository before editing.** Run `git status`, `git log`, inspect
   the working tree, and read the key files named in this document. There are
   substantial uncommitted changes. Do not delete or overwrite work you did not
   create.
2. **Work continuously.** Do not stop after each phase to ask for approval. The
   owner expects the installer, the live image, the installed system, and the
   VM tests to be finished and debugged. Report only when the project is
   complete, or when a genuine external blocker prevents progress.
3. **Never write to a real host disk.** This is absolute. Do not run `wipefs`,
   `sgdisk`, `sfdisk`, `cfdisk`, `mkfs`, `dd`, `parted`, `grub-install`, or the
   installer engine against `/dev/sd*`, `/dev/nvme*`, `/dev/vd*` on the host, or
   any other real block device. All destructive tests must use loopback image
   files under `/var/tmp` or a virtual disk inside QEMU. The QEMU guest disk is
   a file such as `astraos-test.qcow2`; the host disk is never a target.
4. **Test the Tauri UI in WSL first, then in QEMU.** A compile is not a test.
   Open the app, click through the wizard, verify the read-only storage plan,
   and confirm that nothing is written before the final Install action.
5. **Build the final ISO yourself and test it.** Do not stop at package builds
   or a screenshot of the live desktop. Boot the ISO under UEFI/OVMF, install
   to a 40 GiB virtual disk, boot the installed system, and verify SilentSDDM,
   the preset switcher, GRUB, and the desktop.
6. **Maintain AstraOS capitalization.** User-visible text is always `AstraOS`,
   never `ASTRAOS` and never `ASTRA OS`. Uppercase is allowed only for
   technical identifiers such as the ISO9660 label, package IDs, environment
   variables, and `archisobasedir=`-style boot tokens.
7. **Do not claim success without evidence.** Keep logs, screenshots, command
   output, and checksums. A passing build is not a passing install.
8. **Network access is allowed.** Offline installation is explicitly not a v1
   requirement. The build and installer may use the network.
9. **Preserve the existing architecture unless this document says otherwise.**
   The project already has a tested Bash installer library and a working live
   autologin path. Do not rewrite them from scratch without a concrete reason.

---

## 1. Product definition

AstraOS is a curated Arch-based distribution that ships a coherent Niri desktop
instead of a bare Arch install. It is design-driven, quiet, and reproducible.

### 1.1 Stack

| Layer | Choice |
|---|---|
| Base | Arch Linux, pinned to an Arch Linux Archive snapshot |
| Snapshot | `config/snapshot` currently `2026/10/18` |
| Compositor | Niri |
| Shell | Noctalia v5 |
| Terminal | Kitty, Zsh, Oh My Posh (`1_shell`), autosuggestions |
| Editor | Neovim with a pinned, pre-baked LazyVim tree |
| Boot | UEFI only, GRUB on the installed system, systemd-boot on the live ISO |
| Filesystem | Btrfs with `@`, `@home`, `@log`, `@pkg`, `@snapshots` |
| ESP | 1 GiB FAT32 at `/boot/efi` |
| Login | SilentSDDM with AstraOS presets and a switcher |
| Installer | Rust + Tauri 2 GUI over a non-interactive privileged Bash engine |
| Update client | `astra-update`, stable OS channel preview |

### 1.2 v1 scope

- UEFI systems only. Secure Boot and CSM/Legacy boot must be disabled.
- One Linux distribution on the target, or a free-space dual-boot install.
- No LUKS in v1. Keep the storage interface narrow so LUKS can be added later.
- No BIOS/MBR installs.
- No offline-install guarantee.
- No GIMP, no gaming overlays (`gamemode`, `mangohud`), no Linux LTS kernel in
  the default image.
- Steam is target-only when selected; it is not in the live image.
- The installed system must be the same desktop as the live session, not a
  mock-up.

### 1.3 Release posture

The repository is pre-release. The README and docs must say so until the final
ISO has passed the full QEMU test matrix. Do not label an untested image as
stable.

---

## 2. Current state of the repository

Read this section, then verify it against the actual tree.

### 2.1 Already present

- Phase 1 commit: `7ab15c1` — `Phase 1: rebrand AstraOS boot menus and wordmark`.
- Archiso build pipeline: `scripts/build-iso.sh`.
- Package repository builder: `scripts/build-repo.sh`.
- Boot-menu rebrander: `scripts/rebrand-archiso.sh`.
- Branding renderer and assets: `scripts/render-branding.sh`,
  `packages/astra-branding/`.
- Tested Bash installer library: `packages/astra-installer/lib/`.
- Interactive TUI fallback: `packages/astra-installer/astra-install`.
- Non-interactive engine: `packages/astra-installer/astra-engine`.
- Rust/Tauri scaffold: `installer/src-tauri/`.
- SilentSDDM package, presets, and switcher:
  `packages/astra-sddm-theme/`.
- Live-session customization:
  `config/live/airootfs/root/customize_airootfs.sh`.
- Live package exclusions: `manifests/live-exclude.txt`.
- A Phase 1 ISO was built earlier at
  `/root/astraos-build/out/astraos-2026.10.22-x86_64.iso` (about 3.4 GiB).
  **It predates all Phase 2/3 changes and must not be treated as the final
  image.**

### 2.2 Uncommitted Phase 2/3 work

The working tree contains, among other changes:

- `README.md` and `installer/README.md` updated for the new architecture.
- `scripts/build-installer.sh` added.
- Live overlay rewritten for root autologin, no SDDM, and installer autostart.
- Live SDDM config and live sudoers file removed.
- `manifests/live-exclude.txt` now excludes `astra-meta`,
  `astra-sddm-theme`, and `sddm`.
- `packages/astra-installer/PKGBUILD`, desktop file, `lib/common.sh`,
  `lib/install.sh`, and `lib/storage.sh` updated.
- `packages/astra-installer/astra-engine` added.
- `installer/src-tauri/` added: `Cargo.toml`, `build.rs`, `tauri.conf.json`,
  `src/main.rs`, `src/plan.rs`.
- `packages/astra-sddm-theme/` updated: PKGBUILD, `astra.conf`, switcher,
  preset generator, seven presets.
- Branding wallpapers added: original variants and NASA imports.
- `scripts/build-iso.sh` updated to require the Tauri binary and stage an
  installer overlay.

### 2.3 Missing or unfinished

- `installer/src-tauri/ui/` **does not exist**. The Tauri app cannot build
  until the frontend is created.
- No Rust/Tauri release binary has been built. `scripts/build-installer.sh`
  has not yet succeeded.
- No Tauri GUI test has been run in WSL.
- No final ISO has been rebuilt with Phase 2/3 changes.
- No QEMU/OVMF boot test of the new ISO has been run.
- No installed-system test has been run.
- `THIRD_PARTY.md` still has stale SDDM/theme rows and lacks final NASA image
  credits.
- `astra-sddm-theme` has not been built and validated as a package.
- `astra-engine` has not been exercised end-to-end.
- Tests and docs still need updates for no-SDDM live behavior and the Tauri
  installer.
- The Tauri Rust code is unverified. Expect compile errors, Tauri 2 API
  mismatches, and frontend integration bugs.

### 2.4 Host environment used so far

- Windows host; repository on `D:\backup-linux\astraos`.
- WSL distro `AstraOS` (Arch Linux).
- Source is accessed at `/mnt/d/backup-linux/astraos`.
- For ISO builds, copy the repository to an ext4 path such as
  `/root/astraos-build`. Do not build the ISO from `/mnt/d`; the Windows
  filesystem is too slow and has permission/line-ending problems.
- `rsync` is not installed in WSL. Use a `tar` pipeline for the copy.
- Rust, Cargo, GTK3, WebKitGTK 4.1, libsoup3, pkgconf, base-devel, and OpenSSL
  have been installed in the WSL environment, but the app has not been built.
- `qemu-system-x86_64` is installed; the OVMF firmware path must be located.
- Run privileged WSL commands as:
  `wsl -d AstraOS -u root -e bash -c "..."`.

---

## 3. Non-negotiable constraints

| # | Constraint | How to verify |
|---|---|---|
| 1 | User-visible name is `AstraOS` | `tests/branding-test.sh`; grep the UI, boot menus, docs |
| 2 | Never touch real host disks | Only loop devices / QEMU image files; inspect `lsblk` before any test |
| 3 | Minimum storage is 35 GiB total: 1 GiB ESP + 34 GiB root | Rust planner tests, Bash storage tests, GUI summary |
| 4 | UEFI only; no BIOS, no CSM, no Secure Boot path | QEMU/OVMF boot; engine `check_uefi` |
| 5 | Live image has no SDDM | `command -v sddm` fails in live chroot; manifest excludes |
| 6 | Live tty1 autologs root into Niri + Noctalia | Boot ISO and inspect tty1; check getty override |
| 7 | Installer opens automatically in the live session | Niri `spawn-at-startup`; screen after boot |
| 8 | Installed system uses SilentSDDM with AstraOS wallpaper | Boot installed disk; inspect greeter |
| 9 | Easy SilentSDDM preset switcher, each preset has a different wallpaper | `astra-sddm-theme list` / `set`; reboot greeter |
| 10 | Installer is Rust/Tauri with typed errors | `cargo test`; inspect `InstallerError` |
| 11 | Storage planning is read-only until final confirmation | GUI plan; engine deletes plan then writes; no format before confirm |
| 12 | Build/test network access is allowed; offline is not required | No offline claims in docs or tests |
| 13 | Tauri is tested in WSL first, then QEMU | WSL screenshots/logs, then VM |
| 14 | Final ISO is built and tested before reporting complete | Artifact checksum + QEMU install log |
| 15 | Product name comes from `config/brand.toml` | Build scripts call `brand_load`; no hard-coded product name |

### 3.1 Prohibited during development and testing

Never run any of these against a host block device:

```text
wipefs /dev/...
sgdisk /dev/...
sfdisk /dev/...
cfdisk /dev/...
parted /dev/...
mkfs.* /dev/...
dd if=... of=/dev/...
grub-install ... /dev/...
```

The installer necessarily uses `sgdisk`, `mkfs`, `mount`, and `grub-install`,
but only after the user confirms and only against the disk selected in the
plan. During automated tests, that disk must be a loop device backed by an
image file or a virtio disk inside a QEMU guest. Before launching a test,
print `lsblk -o NAME,SIZE,TYPE,MODEL` and verify the target.

### 3.2 Name and capitalization rules

- Product name: `AstraOS`.
- Long name: `Astra Linux` (descriptive, not the product wordmark).
- Identifier: `astraos`.
- ISO label prefix: `ASTRA` (technical uppercase, followed by date).
- Live label: `AstraOS Live` (mixed case).
- Never use `ASTRAOS` or `ASTRA OS` in user-visible text.
- Package names, paths, environment variables, and ISO labels may be
  lowercase or uppercase as technical identifiers.
- The wordmark is always mixed case: **Astra** + **OS**.

---

## 4. Branding specification

### 4.1 Single source of truth

`config/brand.toml` is authoritative:

```toml
name = "AstraOS"
long_name = "Astra Linux"
id = "astraos"
iso_label_prefix = "ASTRA"
website = "https://astraos.org"
tagline = "A calm, design-driven Linux system"
```

Build scripts read this through `scripts/lib/brand.sh`. Do not hard-code the
product name in boot entries, installer headers, documentation, or generated
artwork. If the name changes, it must change here and propagate.

### 4.2 Wordmark and lockup

Files:

- `packages/astra-branding/files/usr/share/astra/branding/astraos-wordmark.svg`
- `packages/astra-branding/files/usr/share/astra/branding/astraos-lockup.svg`
- `packages/astra-branding/files/usr/share/astra/branding/astraos-mark.svg`
- `packages/astra-branding/files/usr/share/astra/branding/astraos-logo.svg`

Specification:

- “Astra” in bold off-white `#E8EEF7`, font weight 700.
- “OS” in lighter cyan `#67E8F9`, font weight 300.
- Font stack: `Adwaita Sans, Noto Sans, sans-serif`.
- Thin teal underline: `#67E8F9`, stroke opacity `0.55`.
- Optional caption: `Astra Linux`, letter-spaced, subdued.
- Lockup includes the original geometric star mark: a four-point star with a
  thin orbital ring and a small gold center (`#D6B36A`).
- No third-party logo, no astronaut, no Arch Linux branding in the wordmark.

Regenerate assets with:

```bash
sudo ./scripts/render-branding.sh
```

### 4.3 Boot menus

`scripts/rebrand-archiso.sh` is the only boot-menu rebrand step. It is called
by `scripts/build-iso.sh` after copying the archiso releng profile.

It must:

- Replace visible “Arch Linux install medium” titles with `AstraOS Live`.
- Replace Memtest and UEFI Shell labels with AstraOS-branded text.
- Set `default=astraos` while preserving the entry filenames.
- Set `iso_name="astraos"`.
- Set `iso_publisher="AstraOS <https://astraos.org>"`.
- Set `iso_application="AstraOS Live Installer"`.
- Set the ISO label to `ASTRA_YYYYMM` (technical uppercase prefix).
- Preserve all functional tokens: `archisobasedir=`,
  `archisosearchuuid=`, `%ARCH%`, `%INSTALL_DIR%`, and the entry filenames.
- Fail closed if any visible Arch Linux install-medium title survives.
- Fail if `archisobasedir=` or `archisosearchuuid=` disappears.

The live ISO uses UEFI systemd-boot; the installed system uses UEFI GRUB. Both
are UEFI-only.

### 4.4 Boot entry checks

After rebranding, the build must still contain:

```text
archisobasedir=...
archisosearchuuid=...
```

Do not “clean up” those tokens. They are how the live medium finds its
squashfs image.

---

## 5. Architecture and repository map

```text
astraos/
├── config/
│   ├── brand.toml                 # single identity source
│   ├── snapshot                   # pinned Arch Linux Archive date
│   ├── pacman.conf.in             # snapshot + local repo template
│   └── live/airootfs/             # live-session overlay
├── manifests/                     # package/plugin lists
├── packages/
│   ├── astra-branding/            # logos, wallpapers, os-release, motd
│   ├── astra-desktop-config/      # skel, niri, Noctalia, Kitty, Neovim
│   ├── astra-installer/           # engine, TUI, shared installer libs
│   ├── astra-sddm-theme/          # SilentSDDM package + presets + switcher
│   ├── astra-keybinds/            # keybind overlay
│   ├── astra-keyring/             # package signing keyring
│   ├── astra-meta/                # target meta-package
│   ├── astra-updater/             # stable OS update client
│   └── ...
├── installer/
│   ├── src-tauri/
│   │   ├── src/main.rs            # Tauri commands, discovery, supervision
│   │   ├── src/plan.rs            # pure storage planner + unit tests
│   │   ├── ui/                    # plain HTML/CSS/JS frontend
│   │   ├── Cargo.toml
│   │   ├── build.rs
│   │   └── tauri.conf.json
│   └── README.md
├── scripts/
│   ├── build-repo.sh
│   ├── build-installer.sh
│   ├── build-iso.sh
│   ├── rebrand-archiso.sh
│   ├── prebake-nvim.sh
│   ├── render-branding.sh
│   ├── scrub-check.sh
│   └── lib/
├── tests/
│   ├── run-all.sh
│   ├── static-guards.sh
│   ├── branding-test.sh
│   ├── storage-loop-test.sh
│   ├── wizard-dry-run.sh
│   └── real-gum.sh
├── updater/
├── docs/
└── README.md
```

### 5.1 Runtime flow

```text
UEFI firmware
  -> systemd-boot (live ISO)
  -> archiso initramfs
  -> live root filesystem
  -> systemd multi-user.target
  -> getty@tty1 autologin as root
  -> /root/.bash_profile execs niri-session
  -> Niri + Noctalia
  -> spawn-at-startup "astra-installer-gui"
  -> Tauri wizard collects answers
  -> read-only Rust storage plan
  -> final Install confirmation
  -> astra-engine validates + writes
  -> pacstrap + target config + GRUB
  -> reboot
  -> UEFI GRUB
  -> SilentSDDM greeter
  -> user session Niri + Noctalia
```

---

## 6. Build pipeline

### 6.1 Host requirements

- Arch Linux host or WSL Arch distribution.
- `archiso`, `git`, `base-devel`, `rust`, `cargo`, `pkgconf`, `gtk3`,
  `webkit2gtk-4.1`, `libsoup3`, `openssl`.
- Root access for package builds and ISO creation.
- At least 30 GiB free space for the build tree and output.
- Network access while building and installing.

### 6.2 Pinned snapshot

`config/snapshot` contains a date such as `2026/10/18`. The build uses the Arch
Linux Archive, not current mirrors:

- `https://archive.archlinux.org/repos/YYYY/MM/DD/core/os/x86_64`
- `.../extra/os/x86_64`
- `.../multilib/os/x86_64`

The pacman template is `config/pacman.conf.in`. Both the build chroot and the
live environment use the same snapshot. Do not silently switch to current
mirrors.

### 6.3 Build the Astra package repository

```bash
sudo ./scripts/build-repo.sh --build
```

This builds every `packages/astra-*` package, fetches the pinned AUR sources,
places packages in `repo/x86_64`, and writes `astra-local.db.tar.gz`.

Notes:

- `makepkg` must not run as root; the script switches to the invoking user.
- Astra packages use `--nodeps` because some depend on packages that only exist
  in this repo.
- A failed package is currently logged and skipped; the final repository check
  fails if a required Astra payload package is missing.
- Do not use `--clean` unless you intend to rebuild everything.

### 6.4 Build the Tauri installer

```bash
./scripts/build-installer.sh --check
./scripts/build-installer.sh --build
```

`--check` runs `cargo test`. `--build` runs `cargo build --release` and copies
the binary to:

```text
installer/src-tauri/target/release/astra-installer
packages/astra-installer/astra-installer-gui
```

The frontend is plain HTML/CSS/JS under `installer/src-tauri/ui/`. Tauri embeds
it at compile time through `frontendDist`; no Node bundler is required.

### 6.5 Build the ISO

```bash
sudo ASTRA_ISO_APPROVED=1 ./scripts/build-iso.sh --build
```

`build-iso.sh` will:

1. Validate the snapshot date.
2. Resolve the live package manifest.
3. Require the local `astra-local.db`.
4. Pre-bake LazyVim into `build/iso/nvim-lazy` if absent.
5. Copy the archiso releng profile to `build/iso/profile`.
6. Run `scripts/rebrand-archiso.sh` on that profile.
7. Switch the profile to UEFI systemd-boot only.
8. Add `console=ttyS0,115200` for serial diagnostics.
9. Use zstd squashfs compression for practical WSL build times.
10. Write the live package list and pacman configuration.
11. Overlay `config/live/airootfs`.
12. Stage the installer sources under `/root/astra-installer-overlay` for
    `customize_airootfs.sh` to copy after pacstrap.
13. Require the Tauri binary and stage it as
    `/usr/bin/astra-installer-gui`.
14. Bundle `repo/x86_64` and the pre-baked LazyVim tree.
15. Run `mkarchiso`.

The output is written to `out/`.

### 6.6 Overlay ordering

This is critical:

- mkarchiso copies the custom `airootfs` **before** pacstrap.
- If you place installer files directly in `airootfs/usr/bin`, pacstrap can
  conflict with files owned by the `astra-installer` package.
- Therefore `build-iso.sh` stages the new installer under
  `/root/astra-installer-overlay`.
- `customize_airootfs.sh` runs after packages are installed and copies that
  overlay into `/`, then deletes the staging directory.
- The Tauri binary must also be present in that overlay; the build must fail
  if it is missing.

### 6.7 WSL build-tree copy

`rsync` is not installed. Use a tar pipeline:

```bash
wsl -d AstraOS -u root -e bash -c '
  rm -rf /root/astraos-build
  mkdir -p /root/astraos-build
  tar -C /mnt/d/backup-linux/astraos -cf - . |
    tar -C /root/astraos-build -xf -
'
```

Then build from `/root/astraos-build`, not `/mnt/d`.

### 6.8 ISO output

The file name follows the archiso `iso_name` and version, for example:

```text
out/astraos-2026.10.22-x86_64.iso
```

Compute and record SHA-256:

```bash
sha256sum out/astraos-*.iso
```

### 6.9 Build failure policy

Do not work around a failing ISO check by disabling it. The important hard
checks are:

- missing `astra-local.db`;
- missing Tauri binary;
- missing live packages;
- missing `niri`, `niri-session`, `noctalia`, `astra-installer-gui`, `iwctl`;
- missing `niri.desktop`;
- SDDM present in the live image;
- visible Arch Linux boot titles;
- missing archiso search tokens.

If a check fails, fix the cause.

---

## 7. Live ISO behavior

The live image is a real desktop, not a rescue shell.

### 7.1 Root autologin on tty1

`config/live/airootfs/root/customize_airootfs.sh` must:

- Ensure `astra` exists as a fallback user.
- Set `astra:astra` and `root:astra` for rescue logins.
- Copy `/etc/skel` to `/root`.
- Append:

  ```kdl
  spawn-at-startup "astra-installer-gui"
  ```

  to `/root/.config/niri/config.kdl` if not already present.
- Write `/root/.bash_profile`:

  ```bash
  if [[ -z ${WAYLAND_DISPLAY:-} && $(tty 2>/dev/null) == /dev/tty1 ]]; then
      exec niri-session
  fi
  ```

- Create `/etc/systemd/system/getty@tty1.service.d/autologin.conf`:

  ```ini
  [Service]
  ExecStart=
  ExecStart=-/usr/bin/agetty --autologin root --noclear %I 38400 linux
  ```

- Set the default target to `multi-user.target`; getty owns the display.
- Enable `getty@tty1`, `getty@tty2`, `serial-getty@ttyS0`,
  `NetworkManager`, `iwd`, `bluetooth`, and `power-profiles-daemon`.
- Disable `sddm` if it exists.
- Disable `systemd-networkd` services so NetworkManager owns link management.
- Configure NetworkManager’s Wi-Fi backend as `iwd`.
- Remove the archiso demo automation hooks.
- Add `[astra-local]` to `/etc/pacman.conf`.
- Seed the pinned LazyVim tree into `/root/.local/share/nvim/lazy`.
- Run the sanity checks listed in section 6.9.

### 7.2 No SDDM in live

The live image must not contain SDDM at all. `manifests/live-exclude.txt`
excludes:

```text
astra-meta
astra-sddm-theme
sddm
```

`astra-meta` depends on `astra-sddm-theme`, which depends on `sddm`. Excluding
only `sddm` is not enough. The final guard should be:

```bash
command -v sddm && exit 1
```

The live image also excludes Steam, NVIDIA proprietary userspace, and the
32-bit graphics stack.

### 7.3 Live credentials

- tty1: autologin as root.
- tty2/serial: `root` / `astra`.
- Demo user: `astra` / `astra`.

Document these as live-only rescue credentials. Do not reuse them as target
defaults.

### 7.4 Live network

- NetworkManager is the primary manager.
- `iwd` is the Wi-Fi backend.
- `nmtui` and `iwctl` are available.
- The installer needs network access for pacstrap and extra packages.
- The local Astra repository is bundled as a cache, not an offline guarantee.

### 7.5 Live acceptance

On the final ISO:

- systemd-boot shows AstraOS entries, not Arch Linux.
- The live session reaches Niri + Noctalia on tty1 without a display manager.
- The installer window opens automatically.
- `command -v sddm` fails.
- `niri`, `noctalia`, `kitty`, `iwctl`, and `astra-installer-gui` exist.
- The local repo is configured and visible to pacman.
- The serial console shows a login prompt.

---

## 8. Installed system specification

### 8.1 Storage layout

Whole-disk mode:

- GPT.
- Partition 1: 1 GiB, type `EF00`, FAT32, mounted at `/boot/efi`.
- Partition 2: remaining space, type `8300`, Btrfs, label `AstraOS`.

Btrfs subvolumes and mount options:

```text
@          -> /
@home      -> /home
@log       -> /var/log
@pkg       -> /var/cache/pacman/pkg
@snapshots -> /.snapshots
```

Mount options:

```text
noatime,compress=zstd:1,discard=async
```

`/boot` stays inside the Btrfs root so kernels and initramfs are covered by
snapshots. GRUB reads the kernel from Btrfs. The ESP is separate.

### 8.2 Bootloader

- UEFI GRUB installed from inside `arch-chroot`.
- `grub-install --target=x86_64-efi --efi-directory=/boot/efi
  --bootloader-id=AstraOS --recheck`.
- If normal install fails, retry with `--removable`.
- Run `grub-mkconfig -o /boot/grub/grub.cfg`.
- For non-whole-disk modes, enable `os-prober` so existing systems appear.
- Never use the host’s `grub-mkconfig`; it must run inside the target chroot.

### 8.3 Target configuration

The target setup script must:

- Set timezone and hardware clock.
- Enable and generate the selected UTF-8 locale.
- Write `LANG`, `KEYMAP`, hostname, and `/etc/hosts`.
- Set root password.
- Create or update the user with groups:
  `video,render,input,audio,storage,optical,network,power`, plus `wheel` if
  sudo is enabled.
- Set the user shell to `/bin/zsh`.
- Set sudo mode:
  - `passwordless`: `%wheel ALL=(ALL:ALL) NOPASSWD: ALL`;
  - `with-password`: `%wheel ALL=(ALL:ALL) ALL`;
  - `none`: remove the sudoers file.
- Configure zram via `/etc/systemd/zram-generator.conf`:
  `zram-size = min(ram / 2, 4096)`, `compression-algorithm = zstd`.
- Enable:
  - NetworkManager
  - sddm
  - bluetooth
  - power-profiles-daemon
  - fstrim.timer
  - systemd-timesyncd
  - grub-btrfsd (if available)
- Disable `dhcpcd`.
- Set default target `graphical.target`.
- Seed LazyVim from `/usr/share/astra/nvim/lazy` into the user’s
  `~/.local/share/nvim/lazy` if absent.
- Run `mkinitcpio -P`.
- Install and configure GRUB.
- Copy the install log and password-free answers to
  `/var/log/astra-install.log` and `/var/log/astra-answers.json`.

### 8.4 Installed desktop

- SilentSDDM starts the graphical session.
- Niri + Noctalia is the session.
- The default SilentSDDM preset uses the AstraOS wallpaper.
- The `astra-sddm-theme` switcher can change presets.
- The desktop configuration is the same as the live session, except the live
  installer autostart and root autologin.

---

## 9. Installer — Rust/Tauri application

### 9.1 UX pages

Build `installer/src-tauri/ui/` with these pages, in order:

1. **Welcome**
   - AstraOS lockup and short description.
   - System summary: UEFI yes/no, live yes/no, CPU, memory.
   - Warning if not UEFI or not root.
   - “Begin” button.

2. **Language and keyboard**
   - Keyboard layout (searchable select from `system_info.keymaps`).
   - Timezone (searchable select from `system_info.timezones`).
   - Locale (select from `system_info.locales`).
   - Defaults: `us`, `UTC`, `en_US.UTF-8`.

3. **Storage**
   - Mode: whole disk, free space, manual, pre-mounted.
   - Disk list with size, model, transport, live-medium badge.
   - Whole: choose disk; show exact erase warning.
   - Free: choose GPT disk, free region coordinates, new or existing ESP.
   - Manual: choose root partition and ESP; root will be formatted, ESP will
     not.
   - Pre-mounted: choose root and ESP devices and enter the mountpoint;
     typically `/mnt`.
   - Show the Rust `StoragePlan`: total size, minimum, steps, warnings,
     errors, `destroy_disk`.
   - Never run `plan_storage` as a write action. It is read-only.

4. **Account**
   - Hostname (default `astraos`).
   - Username (default `astra`; cannot be `root`).
   - User password and confirmation.
   - Root password and confirmation.
   - Sudo mode: passwordless, with-password, none.
   - Password visibility toggle.

5. **Options**
   - Package source: pinned Arch Linux Archive (`ala`) or current mirrors.
   - Mirror region if `mirrors`.
   - Extra packages, comma-separated.
   - Driver manifests, if exposed.
   - Clear warning that network access is required.

6. **Summary / confirm**
   - Read-only recap of every destructive action.
   - Storage plan steps.
   - What will be erased, created, and kept.
   - Explicit checkbox or typed confirmation.
   - Final button: **Install AstraOS**.
   - The button is disabled until validation passes.

7. **Progress**
   - Streamed engine log via `install-log`.
   - Progress state and current phase.
   - Cancel button.
   - Do not pretend to know a percentage if the engine cannot report one.
   - Show the log path.

8. **Done / failed**
   - Success: “Installation complete”, reboot button.
   - Failure: typed error, last 160 log lines, copy-log button, retry/reboot.
   - Never hide a failure behind a generic message.

### 9.2 Visual design

- Dark, quiet, high-contrast AstraOS visual language.
- Background `#05070D`; panels near-black; text `#E8EEF7`; accent `#67E8F9`;
  secondary accent teal; warning amber; destructive red.
- Use the AstraOS lockup/mark from the branding package. Inline SVG is fine;
  do not fetch remote images.
- System font stack: `Adwaita Sans`, `Noto Sans`, sans-serif.
- Accessible focus rings, keyboard navigation, labels, and `aria-live` for
  errors.
- Add `data-testid` attributes for automation.
- No external network fonts, scripts, or analytics.

### 9.3 Frontend integration

Use Tauri 2 with `withGlobalTauri: true`. The frontend calls:

```js
const { invoke } = window.__TAURI__.core;
```

Commands:

```text
system_info() -> SystemInfo
plan_storage(PlanRequest) -> StoragePlan
engine_status() -> EngineStatus
start_install(InstallConfig) -> StartResult
cancel_install() -> null
read_log() -> string
reboot_system() -> null
```

Events:

```text
install-started
install-log      { line, stream }
install-finished { code, success }
```

The frontend must keep a single `config` object and pass it to
`start_install`. Do not write config to `localStorage`; passwords must not
persist.

### 9.4 Typed Rust backend

`installer/src-tauri/src/main.rs` already defines:

```rust
pub enum InstallerError {
    Validation { message: String },
    Storage { message: String },
    Engine { message: String },
    Io { message: String },
    Busy { message: String },
}
```

Keep typed errors. Do not replace them with `String` returns.

`InstallConfig` fields:

```text
storage_mode, disk, esp_mode, esp_part, root_part, esp_mount,
premounted_root, free_start, free_end, hostname, timezone, locale,
kb_layout, user_name, user_sudo, user_password, root_password,
extra_packages, mirror_source, mirror_region, driver_manifests, confirmed
```

`SystemInfo` fields:

```text
uefi, live, memory_mib, cpu, version, is_root, engine_available,
engine_path, min_total_bytes, min_total_human, min_root_human, disks,
timezones, keymaps, locales
```

`StoragePlan` fields:

```text
valid, errors, warnings, steps, storage_mode, disk, disk_size_bytes,
disk_size_human, total_bytes, total_human, minimum_bytes, minimum_human,
destroy_disk, esp, root
```

### 9.5 Storage planner

`installer/src-tauri/src/plan.rs` is pure and must not write anywhere.

Constants:

```rust
pub const GIB: u64 = 1024 * 1024 * 1024;
pub const MIB: u64 = 1024 * 1024;
pub const MIN_TOTAL_BYTES: u64 = 35 * GIB;
pub const MIN_ROOT_BYTES: u64 = 34 * GIB;
pub const ESP_BYTES: u64 = 1 * GIB;
pub const OVERHEAD_BYTES: u64 = 2 * MIB;
```

Modes:

- `whole`: erase entire disk, create GPT, 1 GiB ESP, root = rest minus 2 MiB
  overhead. Reject the live medium. Reject disks under 35 GiB.
- `free`: require GPT, require unmounted partitions, use only the selected
  sector range, create a new ESP if requested, or reuse an existing EFI
  partition without formatting it. Preserve every entry outside the range.
- `manual`: format only the selected root partition as Btrfs; keep the selected
  ESP unformatted; require at least 34 GiB root; root and ESP must differ.
- `premounted`: require root and ESP block devices, mountpoints, an absolute
  target root, and a distinct ESP; do not format, mount, or unmount anything;
  refuse `/` as the target.

The 2 MiB overhead nuance:

- A 35 GiB disk is accepted as the documented minimum.
- A 35 GiB disk leaves a 34 GiB root partition minus GPT/alignment overhead.
- The checks add the 2 MiB overhead back when comparing to `MIN_ROOT_BYTES`.
- Do not “fix” this by lowering the floor or by requiring 36 GiB.
- The recommended size is 40 GiB; QEMU test images must be 40G.

Validators must enforce:

- hostname 1–63 chars, alphanumeric/hyphen, no leading/trailing hyphen;
- username starts lowercase/underscore, max 32, not `root`;
- IANA timezone exists under `/usr/share/zoneinfo`;
- locale ends in `.UTF-8` (or `C.UTF-8`);
- password non-empty and no CR/LF;
- sudo mode one of the three values;
- keyboard layout `[A-Za-z0-9_-]+`;
- extra package names safe;
- mirror source `""`, `ala`, or `mirrors`.

### 9.6 Privileged engine

`packages/astra-installer/astra-engine` is the only privileged install path.

Behavior:

1. Accept one JSON plan file argument.
2. Read every field into memory.
3. Delete the plan file immediately, before any disk write, because it contains
   passwords.
4. Refuse if `confirmed` is not true.
5. Require root.
6. Validate every field again, independently of the GUI.
7. Require UEFI.
8. Validate storage read-only:
   - whole disk exists, is a disk, is not the live medium, meets 35 GiB;
   - free mode has GPT, unmounted partitions, a valid sector range, and an
     existing ESP if requested;
   - manual root and ESP exist, differ, root is not FAT, root is at least
     34 GiB;
   - pre-mounted root is absolute, mounted, ESP mounted under it, and the root
     is not `/`.
9. Set `UNATTENDED=1`, `WIZARD_ACTIVE=0`, `INTERACTIVE=0`.
10. Call `prepare_storage`, `pacstrap`, target configuration, GRUB.
11. Never prompt. A missing or invalid answer is a hard error.
12. On failure, clean up mounts and exit nonzero.

The engine may source the existing installer libraries:

```text
packages/astra-installer/lib/common.sh
packages/astra-installer/lib/hw.sh
packages/astra-installer/lib/mirrors.sh
packages/astra-installer/lib/storage.sh
packages/astra-installer/lib/install.sh
```

Do not duplicate storage logic in Rust. The Rust planner is a read-only preview;
the engine repeats the checks before writing.

### 9.7 Secrets

- Plan file: `/run/astra-install/plan.json`, mode `0600`, deleted by the
  engine after parsing.
- Target env file: `/mnt/tmp/astra-env`, mode `0600`, deleted immediately after
  sourcing inside the chroot.
- `answers.json`: password-free, mode `0644` in `/run/astra-install` and copied
  to `/var/log/astra-answers.json`.
- Logs must never contain passwords.
- Do not log the plan JSON.

### 9.8 Install sequence

After confirmation:

1. Validate storage and target.
2. Whole/free/manual: unmount target partitions if needed; create GPT/partitions;
   format ESP/root; run `partprobe`/`udevadm settle`.
3. Mount root; create Btrfs subvolumes; remount with subvolume options; mount
   ESP at `/boot/efi`.
4. `verify_install_target`: the mount at `/mnt` must be backed by the selected
   root partition, and it must have at least 10 GiB free.
5. Write a target pacman config pinned to the snapshot.
6. `pacstrap -C <conf> -M /mnt <packages>`.
   **Do not pass `-c`.** `-c` uses the live host’s package cache, which is the
   small archiso overlay, and can fail on a 40 GiB disk. The default target
   cache is correct.
7. Install extra packages inside the chroot.
8. Write target pacman config.
9. `genfstab -U /mnt > /mnt/etc/fstab`.
10. Run the target setup script inside `arch-chroot`.
11. Copy logs.
12. Unmount, unless pre-mounted mode requested keeping mounts.

### 9.9 Tauri packaging

- Package: `packages/astra-installer/PKGBUILD`.
- Version: `0.2.0`.
- Depends include `gtk3`, `webkit2gtk-4.1`, `gum`, `parted`, `gptfdisk`, `jq`,
  `arch-install-scripts`, `btrfs-progs`, `dosfstools`, `util-linux`, `kbd`,
  `networkmanager`, `kitty`.
- GUI binary path in package: `/usr/bin/astra-installer-gui`.
- Desktop entry:
  `packages/astra-installer/astra-installer.desktop`.
- Live autostart: Niri `spawn-at-startup "astra-installer-gui"`.
- The package is ISO-only; it is not a dependency of `astra-meta`.

### 9.10 CLI test modes

The same binary supports:

```bash
astra-installer --version
astra-installer --help
astra-installer --plan-json plan.json
astra-installer --install-json plan.json
```

`--plan-json` prints the read-only plan and exits nonzero if invalid.
`--install-json` validates, writes the mode-0600 plan, and runs the engine.

Example test plan:

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

Inside QEMU, `/dev/vda` is the virtual disk. On the host it is a qcow2 file.
Never use this plan on a real host.

### 9.11 Engine tests

Run the Rust planner tests:

```bash
cd installer/src-tauri
cargo test
```

Then test the CLI in a controlled environment:

```bash
./target/release/astra-installer --plan-json /tmp/plan.json
```

For the full engine, run inside the live VM or a disposable chroot with loop
devices. Do not run a whole-disk plan against the host.

---

## 10. SilentSDDM

### 10.1 Upstream pin

- Upstream: `https://github.com/uiriansan/SilentSDDM`
- Pinned commit: `d477613b07ca13729af20cb4699b308ac7348d2f`
- License: GPL-3.0
- Package: `astra-sddm-theme`
- Install path: `/usr/share/sddm/themes/silent/`

The PKGBUILD must:

- Clone the pinned commit.
- Remove upstream `.git`, `.github`, `nix`, `docs`, install/test helpers, demo
  backgrounds, previews, and helper configs.
- Keep the GPL theme code, components, icons, and QML metadata.
- Replace the theme name/description with AstraOS Silent.
- Install only AstraOS presets and symlinked wallpapers.
- Remove upstream demo media.
- Record upstream license and commit in `THIRD_PARTY.md`.

### 10.2 Presets

Seven presets:

```text
astra-orbital     astraos-default.png
astra-aurora      astraos-aurora.png
astra-ember       astraos-ember.png
astra-lunar       astraos-lunar.png
astra-earthrise   astraos-earthrise.jpg
astra-carina      astraos-carina.png
astra-deepfield   astraos-deepfield.jpg
```

Each preset is a SilentSDDM config under:

```text
/usr/share/sddm/themes/silent/configs/astra-*.conf
```

The default config is:

```text
/etc/sddm.conf.d/astra.conf
```

with:

```ini
[Theme]
Current=silent
ConfigFile=configs/astra-orbital.conf
```

### 10.3 Switcher

`/usr/bin/astra-sddm-theme` supports:

```bash
astra-sddm-theme list
astra-sddm-theme current
sudo astra-sddm-theme set astra-aurora
astra-sddm-theme wallpaper astra-earthrise
```

`set` updates `ConfigFile=` in `/etc/sddm.conf.d/astra.conf` and preserves
`Current=silent`. It must require root. `list` and `current` must work as a
normal user.

### 10.4 Live vs installed

- Live: no SDDM, no theme package, no greeter.
- Installed: SilentSDDM is the display manager.
- `astra-meta` pulls `astra-sddm-theme`, which pulls `sddm`.
- The live manifest excludes all three.
- The SDDM service is enabled only in the target setup, never in the live
  overlay.

### 10.5 Validation

Build the package:

```bash
cd packages/astra-sddm-theme
makepkg --cleanbuild --nodeps --noconfirm
```

Validate:

```bash
bsdtar -tf astra-sddm-theme-*.pkg.tar.zst | grep -E \
  'sddm/themes/silent/(configs|backgrounds)|astra-sddm-theme|sddm.conf.d'
```

Install into a disposable QEMU guest and verify:

```bash
astra-sddm-theme list
sudo astra-sddm-theme set astra-carina
systemctl restart sddm
```

The greeter must show the selected wallpaper. Repeat for at least two presets.

---

## 11. Wallpapers and assets

### 11.1 Original AstraOS wallpapers

- `astraos-default.png` — original orbital/cyan artwork, 4K.
- `astraos-aurora.png` — generated teal variant.
- `astraos-ember.png` — generated amber variant.
- `astraos-lunar.png` — generated violet variant.

The variants come from `packages/astra-branding/generate-wallpaper-variants.py`
and only change accent/deep/gold hues. The star field, charts, mark, and
typography remain identical.

Source SVGs:

```text
packages/astra-branding/files/usr/share/astra/branding/astraos-wallpaper.svg
packages/astra-branding/files/usr/share/astra/branding/astraos-wallpaper-aurora.svg
packages/astra-branding/files/usr/share/astra/branding/astraos-wallpaper-ember.svg
packages/astra-branding/files/usr/share/astra/branding/astraos-wallpaper-lunar.svg
```

### 11.2 Imported NASA imagery

- Earthrise — NASA, Apollo 8, `as08-14-2383`.
- Carina Nebula — NASA/ESA/CSA James Webb Space Telescope, `carina_nebula`.
- Hubble Deep Field — NASA/ESA, `PIA12110`.

Final files:

```text
astraos-earthrise.jpg
astraos-carina.png
astraos-deepfield.jpg
```

Requirements:

- Use public-domain NASA imagery or imagery with a verified compatible
  license.
- Record the exact source URL, author/credit, license, and retrieval date in
  `THIRD_PARTY.md`.
- Do not ship an image whose license or credit is unknown.
- Do not use random wallpaper-site images.
- Keep captions/credits visible in the docs and README.

### 11.3 `THIRD_PARTY.md`

Update it before release. It must cover:

- SilentSDDM at the pinned commit, GPL-3.0, with the AstraOS modifications.
- Each NASA image with source, author, license, and file name.
- The original AstraOS artwork and its project license.
- The removed upstream demo media.
- Any remaining “pending owner confirmation” rows.

The release gate is: every shipped asset has a license and credit row.

---

## 12. Updater

`astra-update` is a v1 preview. The public update channel is not live.

- OS track: pinned Arch snapshot, Astra packages, signed `stable.json` metadata.
- App track: deferred; apps update through the OS track for v1.
- Commands: `check`, `apply`, `status`, `rollback`, `release`, `list`.
- Exit codes: 0 ok, 10 no update, 20 update available, 30 network error,
  40 metadata verification failure, 50 rollback/unsupported.
- `apply`: create a snapper snapshot, `pacman -Syu`, reinstall `astra-meta`,
  refresh GRUB, reboot.
- Offline behavior: checks fail closed; do not claim offline support.

Do not advertise a working update service until the metadata host, signing
key, and release process exist.

---

## 13. Manifests and packages

### 13.1 Live package set

The live set is the union of the target manifests plus `manifests/iso.txt`,
minus `manifests/live-exclude.txt`.

Live-only tools include:

```text
arch-install-scripts
mkinitcpio-archiso
gum
iwd
parted
gptfdisk
jq
pciutils
usbutils
vulkan-nouveau
nano
memtest86+-efi
edk2-shell
os-prober
gtk3
webkit2gtk-4.1
```

Excluded from live:

```text
astra-meta
astra-sddm-theme
sddm
steam
nvidia-open
nvidia-open-dkms
nvidia-utils
lib32-nvidia-utils
nvidia-settings
nvidia-prime
opencl-nvidia
lib32-opencl-nvidia
lib32-mesa
lib32-vulkan-radeon
lib32-vulkan-intel
lib32-nvidia-580xx-utils
lib32-opencl-nvidia-580xx
```

### 13.2 Target packages

Target manifests:

```text
manifests/base.txt
manifests/desktop.txt
manifests/apps.txt
manifests/fonts-themes.txt
manifests/astra.txt
manifests/drivers-*.txt
```

`astra.txt` includes:

```text
astra-branding
astra-desktop-config
astra-sddm-theme
astra-keybinds
astra-updater
astra-keyring
astra-meta
```

`astra-installer` is live-only and is not a dependency of `astra-meta`.

### 13.3 Drivers

- AMD and Intel open drivers by default.
- NVIDIA Maxwell/Pascal/Volta via the 580xx AUR stack.
- CPU microcode is always included even when GPU detection fails.
- `nvidia-open-dkms` is preferred over `nvidia-open` when both appear.
- Steam is target-only and requires multilib plus 32-bit graphics.

### 13.4 Package build order

1. `astra-branding`
2. `astra-desktop-config`
3. `astra-keybinds`
4. `astra-keyring`
5. `astra-updater`
6. `astra-sddm-theme`
7. `astra-meta`
8. `astra-installer`
9. AUR payload (`paru`, `oh-my-posh-bin`, NVIDIA 580xx)

`build-repo.sh` handles the dependency cycle with `--nodeps`.

---

## 14. Testing and acceptance

### 14.1 Static tests

```bash
cd /path/to/astraos
bash tests/run-all.sh
```

`tests/run-all.sh` runs:

- Bash syntax checks for all shell files.
- `shellcheck -x -a`.
- `shfmt -d`.
- `static-guards.sh`.
- `branding-test.sh`.
- `wizard-dry-run.sh`.
- `real-gum.sh`.
- `storage-loop-test.sh` when run as root.

The storage loop test must only use `/var/tmp` image files and loop devices.
Inspect the script before running it.

### 14.2 Rust tests

```bash
./scripts/build-installer.sh --check
```

This runs `cargo test` in `installer/src-tauri`. Required cases include:

- 40 GiB whole disk valid.
- 34 GiB whole disk rejected.
- 35 GiB free region valid.
- 30 GiB manual root rejected.
- identity validators.
- live medium rejected.
- free-space GPT and unmounted checks.
- pre-mounted `/` rejected.

Add tests for any new planner branch.

### 14.3 Tauri UI in WSL

Build dependencies:

```bash
sudo pacman -S --needed rust pkgconf base-devel gtk3 webkit2gtk-4.1 \
  libsoup3 librsvg openssl
```

Build:

```bash
./scripts/build-installer.sh --build
```

Run the GUI in WSL with a Wayland/X11 display. If WSLg is available:

```bash
./installer/src-tauri/target/release/astra-installer
```

Verify with screenshots:

- Welcome page loads.
- System info populates.
- Storage page lists disks and marks the live medium.
- Plan is read-only; no partition table changes.
- Validation errors are specific.
- Summary shows “erase entire disk” warning.
- Final button is disabled until confirmation.
- No password is persisted or logged.

Use the CLI plan mode if the GUI cannot open in WSL:

```bash
./installer/src-tauri/target/release/astra-installer --plan-json /tmp/plan.json
```

### 14.4 Final ISO build

```bash
sudo ASTRA_ISO_APPROVED=1 ./scripts/build-iso.sh --build
```

Then verify:

```bash
ls -lh out/astraos-*.iso
sha256sum out/astraos-*.iso
```

Mount or inspect the ISO tree:

- `iso_label` is `ASTRA_YYYYMM`.
- `iso_publisher` is `AstraOS <https://astraos.org>`.
- `iso_application` is `AstraOS Live Installer`.
- Boot entry titles say AstraOS Live.
- `archisobasedir=` and `archisosearchuuid=` exist.
- No `sddm` package in the live package list.
- `astra-installer-gui` is present in the live `airootfs`.

### 14.5 QEMU/OVMF boot test

Use only image files. Find firmware:

```bash
ls /usr/share/edk2/x64/OVMF.4m.fd
ls /usr/share/edk2-ovmf/x64/OVMF.4m.fd
```

Example UEFI boot:

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 4096 \
  -smp 4 \
  -machine q35 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF.4m.fd \
  -drive file=astraos-install.qcow2,if=virtio,format=qcow2 \
  -cdrom out/astraos-2026.10.22-x86_64.iso \
  -boot d \
  -vga virtio \
  -display gtk \
  -serial file:astraos-serial.log
```

If KVM is unavailable in WSL, remove `-enable-kvm` and expect slow boot.

Create the test disk:

```bash
qemu-img create -f qcow2 astraos-install.qcow2 40G
```

Verify in the guest:

- systemd-boot AstraOS menu.
- Live tty1 root autologin.
- Niri + Noctalia desktop.
- Installer autostarts.
- No SDDM process.
- Network works.
- Installer detects the 40G virtio disk.
- Storage plan shows 40G and valid.
- The 35/34 GiB floor is enforced.

### 14.6 Install test

Preferred: use the GUI in QEMU.

Fallback: run the engine in the live guest with a plan targeting `/dev/vda`.

Before confirming:

```bash
lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINTS
```

The target must be `/dev/vda` (the virtio disk), never a host disk.

Install and wait for completion. Verify:

- Partition table: GPT, 1 GiB ESP, ~39G root.
- Btrfs subvolumes exist.
- `/etc/fstab` uses UUIDs and subvolumes.
- GRUB EFI entry `AstraOS` exists.
- `sddm.service` is enabled.
- `astra-sddm-theme` is installed.
- `astra-meta` is installed.
- User exists with the selected groups and shell.
- Root and user passwords work.
- `/var/log/astra-install.log` exists.
- `/var/log/astra-answers.json` has no passwords.

### 14.7 Installed-system boot test

Boot the same QEMU VM from the installed disk (remove the CD or change boot
order):

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 4096 \
  -smp 4 \
  -machine q35 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF.4m.fd \
  -drive file=astraos-install.qcow2,if=virtio,format=qcow2 \
  -vga virtio \
  -display gtk \
  -serial file:astraos-installed-serial.log
```

Verify:

- GRUB AstraOS menu.
- SilentSDDM greeter with the default AstraOS wallpaper.
- Login as the created user.
- Niri + Noctalia session starts.
- `astra-sddm-theme list` shows seven presets.
- `sudo astra-sddm-theme set astra-carina` updates the config.
- `systemctl restart sddm` shows the new wallpaper.
- Repeat with `astra-earthrise` or `astra-deepfield`.
- No live autologin remains.
- No installer autostart remains.
- Network, audio, Bluetooth, and power profiles are available.
- `snapper list` works.
- `sudo astra-update status` works or fails closed clearly.

### 14.8 Test matrix

| Area | Test | Pass condition |
|---|---|---|
| Branding | `tests/branding-test.sh` | No `ASTRAOS`, no Arch titles, tokens preserved |
| Static | `tests/run-all.sh` | All suites pass |
| Rust | `cargo test` | Planner and validator tests pass |
| Tauri UI | WSL GUI run | Pages load, plan read-only, errors specific |
| Live boot | QEMU/OVMF | AstraOS menu, Niri desktop, no SDDM |
| Autostart | Live boot | Installer opens automatically |
| Storage | GUI plan on 40G | 40G valid; 34G rejected; live disk rejected |
| Install | QEMU install | Completes without prompts or host writes |
| Installed boot | QEMU disk boot | GRUB -> SilentSDDM -> Niri |
| Presets | Switcher + reboot | Wallpaper changes per preset |
| Logs | Installed system | No passwords in logs |
| Safety | Before/after `lsblk` | Host disks untouched |

### 14.9 Evidence to keep

- `tests/run-all.sh` log.
- `cargo test` output.
- Tauri UI screenshots.
- ISO SHA-256.
- QEMU serial logs.
- Installer log from the guest.
- Screenshot of the installed SilentSDDM greeter.
- Switcher output before and after a preset change.

---

## 15. Definition of Done

The project is done only when all of these are true:

- [ ] `config/brand.toml` is the single identity source.
- [ ] Wordmark and lockup are mixed-case and match the color spec.
- [ ] Boot menus say AstraOS; no Arch Linux install-medium titles remain.
- [ ] `archisobasedir=`, `archisosearchuuid=`, `%ARCH%`, `%INSTALL_DIR%`, and
      entry filenames are preserved.
- [ ] Live ISO has no SDDM.
- [ ] Live tty1 root autologin reaches Niri + Noctalia.
- [ ] Installer autostarts in the live session.
- [ ] Tauri UI exists, builds, and passes WSL testing.
- [ ] Rust planner and validator tests pass.
- [ ] The installer performs no disk writes before final confirmation.
- [ ] The engine rejects invalid/unconfirmed plans and deletes the secret plan
      file before writing.
- [ ] 35 GiB total / 34 GiB root floor is enforced in Rust and Bash.
- [ ] Whole, free-space, manual, and pre-mounted modes are implemented and
      documented.
- [ ] Installed system uses GRUB UEFI and SilentSDDM.
- [ ] Seven SilentSDDM presets exist and each uses a different wallpaper.
- [ ] The switcher works and survives an SDDM restart.
- [ ] Original and NASA wallpapers are credited in `THIRD_PARTY.md`.
- [ ] SilentSDDM package builds and is tested in the installed system.
- [ ] `tests/run-all.sh` passes.
- [ ] Final ISO builds.
- [ ] Final ISO boots in QEMU/OVMF.
- [ ] Install to a 40 GiB qcow2 succeeds.
- [ ] Installed system boots and reaches SilentSDDM.
- [ ] No real host disk was touched.
- [ ] Changes are committed.
- [ ] The final report includes artifacts, checksums, test logs, and known
      limitations.

---

## 16. Known pitfalls and hard-won lessons

### 16.1 The Tauri frontend is missing

`tauri.conf.json` points at `../ui`, but `installer/src-tauri/ui/` does not
exist. `cargo build` will fail until `index.html`, CSS, and JS are created.
Create the frontend before debugging Rust build errors.

### 16.2 The ISO build hard-fails without the GUI

`scripts/build-iso.sh` now refuses to build unless
`installer/src-tauri/target/release/astra-installer` exists. This is
intentional: a release must not silently use the TUI fallback. Build the GUI
first.

### 16.3 Live overlay ordering

Do not copy installer files directly into `airootfs/usr/bin` during profile
assembly. mkarchiso copies airootfs before pacstrap, which can conflict with
files owned by `astra-installer`. Stage them under
`/root/astra-installer-overlay` and copy them in `customize_airootfs.sh`.

### 16.4 SDDM dependency leak

`astra-meta` -> `astra-sddm-theme` -> `sddm`. Excluding only `sddm` leaves the
theme/meta and may pull it back. Exclude all three from the live manifest.

### 16.5 35 GiB math

A 35 GiB disk leaves 34 GiB minus GPT/alignment overhead for root. The checks
must still accept 35 GiB because the documented floor is 35 GiB total and
1 GiB + 34 GiB. Do not raise the floor to 36 GiB and do not lower it to 34 GiB.
Use 40G QEMU images.

### 16.6 `pacstrap -c`

Do not use `-c`. It uses the live host’s package cache, which is the small
archiso overlay and can fail on a 40 GiB target. Use the target’s own cache.

### 16.7 Pre-mounted `/`

Refuse `/` as the pre-mounted root. It is the live installer environment, not
the target. Require `/mnt` or another absolute mountpoint.

### 16.8 GPT free-space baseline

Free-space mode snapshots the GPT after cfdisk. `verify_gpt_unchanged` compares
every existing entry, including first-MiB hashes. Do not skip this check and do
not touch entries outside the selected sector range.

### 16.9 OVMF path

The firmware path varies by distribution. Check both
`/usr/share/edk2/x64/OVMF.4m.fd` and `/usr/share/edk2-ovmf/x64/OVMF.4m.fd`.
Use `-machine q35` and a raw pflash drive.

### 16.10 WSL `rsync`

`rsync` is not installed. Use `tar` pipelines. Build on ext4, not `/mnt/d`.

### 16.11 CRLF and executable bits

The repository is edited on Windows. Before building in WSL, ensure shell
scripts are LF and executable. Git may preserve CRLF; use `.gitattributes` or
`dos2unix` if needed. `chmod +x` the scripts after copying.

### 16.12 `set -e` in the TUI

The interactive TUI deliberately does not use `set -e`, because `gum` returns
nonzero on Escape and optional probes fail routinely. The non-interactive
engine uses `set -Eeuo pipefail` and must fail hard. Do not “fix” the TUI by
adding `set -e`.

### 16.13 Tauri system libraries

Building requires `gtk3`, `webkit2gtk-4.1`, `libsoup3`, `pkgconf`, and OpenSSL.
The live image also needs `gtk3` and `webkit2gtk-4.1` at runtime. A binary that
builds but cannot launch in the live session is not done.

### 16.14 Boot token cleanup

Do not remove `archisobasedir=`, `archisosearchuuid=`, `%ARCH%`,
`%INSTALL_DIR%`, or rename boot entry files. They are functional identifiers,
not branding.

### 16.15 Password leakage

The plan file contains passwords. Delete it immediately after parsing. Never
write passwords to `answers.json`, the install log, or the GUI’s persisted
state.

### 16.16 Stale artifacts

The existing ISO predates the current code. Delete or ignore it; rebuild from
the current tree. Do not test the old image and call it final.

### 16.17 QEMU acceleration

KVM may be unavailable in WSL. If so, remove `-enable-kvm`; boot will be slow.
Do not use host disk passthrough. Use qcow2 files.

### 16.18 `makepkg` as root

`makepkg` refuses to run as root. `build-repo.sh` switches to the invoking user
or the checkout owner. Do not bypass this by editing PKGBUILDs to run as root.

### 16.19 Package source mismatch

The build and installer use the pinned Arch Linux Archive snapshot. Do not mix
current mirrors into the target and then claim reproducibility. If you use
current mirrors, document it as an explicit choice.

### 16.20 Noctalia state location

Noctalia v5 reads state under `~/.local/state/noctalia`, not the older config
path. Seed and test the correct directory.

---

## 17. Suggested execution order

1. Inspect the tree and run `git status`.
2. Create `installer/src-tauri/ui/` with the full wizard.
3. Run `./scripts/build-installer.sh --check`; fix Rust tests.
4. Run `./scripts/build-installer.sh --build`; fix compile errors.
5. Test the GUI in WSL; fix frontend/backend integration.
6. Build the SilentSDDM package; validate presets and switcher.
7. Update `THIRD_PARTY.md` and docs.
8. Run `tests/run-all.sh`; fix failures.
9. Copy the tree to `/root/astraos-build`.
10. Build the final ISO.
11. Boot the ISO in QEMU/OVMF; verify live behavior.
12. Install to a 40G qcow2; boot the installed system.
13. Verify SilentSDDM, presets, wallpapers, GRUB, services, logs.
14. Commit the final changes.
15. Write the final report.

Do not stop after step 10. The build is not the deliverable; the tested install
is.

---

## 18. Final report format

When the project is complete, report:

```text
AstraOS handoff — final status

Artifacts
- ISO: <path>
- SHA-256: <hash>
- Installer binary: <path>
- Package repo: <path>

Verification
- tests/run-all.sh: PASS (log: <path>)
- cargo test: PASS
- Tauri GUI in WSL: PASS (screenshots: <paths>)
- Live QEMU boot: PASS (serial log: <path>)
- Install to 40G qcow2: PASS (installer log: <path>)
- Installed boot: PASS (serial log: <path>)
- SilentSDDM presets: PASS (preset outputs: <paths>)

Safety
- Host disks inspected before/after: unchanged
- All destructive tests used loop devices or QEMU image files

Known limitations
- <list only real, verified limitations>

Commits
- <commit hashes and messages>
```

If something is not verified, say so. Do not mark it as done.

---

## 19. Short kickoff block

If you need a compact instruction to paste at the top of the new agent session,
use this:

> You are taking over AstraOS, an Arch-based UEFI-only Niri + Noctalia
> distribution at `D:\backup-linux\astraos`. Read this handoff prompt
> completely. Keep the project in that location; it is the owner's live
> checkout and will continue to be used. Do not move or delete it.
> The working tree is mid-Phase 2/3: the Rust/Tauri backend exists but
> `installer/src-tauri/ui/` is missing, the final ISO has not been rebuilt, and
> no QEMU install test has been run. Your job is to finish the Tauri wizard,
> build and test the installer in WSL, update the SilentSDDM and wallpaper
> metadata, rebuild the ISO, boot it under UEFI/OVMF, install to a 40 GiB qcow2
> image, boot the installed system, and verify SilentSDDM, all seven presets,
> GRUB, and the desktop. Never touch a real host disk; use loop devices or
> QEMU image files only. Do not stop at intermediate phases. Keep `AstraOS`
> mixed case, keep the 35 GiB total / 34 GiB root floor, and do not ship SDDM
> in the live image. Report only after the full test matrix passes.

---

*End of handoff prompt.*
