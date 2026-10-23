"""
AstraOS Supervised Installation Engine.
Executes the 7-phase installation workflow, streams real-time output,
parses pacman package counters, and recovers gracefully on error.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any, Callable, List

from astra_installer.hooks import (
    apply_astra_identity,
    configure_sudo_rules,
    copy_wifi_profiles,
    remove_live_leftovers,
    run_chroot,
    seed_lazyvim,
)
from astra_installer.models import AstraConfig, OperationType, StorageMode, SwapMode
from astra_installer.storage_guard import (
    create_partition_backup,
    discover_disks,
    verify_untouched_partitions,
)

TARGET_MOUNT = Path("/mnt")
LOG_DIR = Path("/var/log/astra-install")
LOG_FILE = LOG_DIR / "install.log"


def log_msg(widget: Any, msg: str) -> None:
    """Log message to UI and disk file."""
    timestamp = time.strftime("[%Y-%m-%d %H:%M:%S]")
    line = f"{timestamp} {msg}"
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(line + "\n")
    if widget and hasattr(widget, "append_log"):
        widget.append_log(msg)


def run_command_stream(cmd: List[str], widget: Any, pkg_callback: Callable[[int, int], None] | None = None) -> None:
    """Execute command and stream stdout/stderr live to UI."""
    log_msg(widget, f"> {' '.join(cmd)}")
    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    )

    pkg_pattern = re.compile(r"\((\d+)/(\d+)\)\s+(?:downloading|installing)")

    if proc.stdout:
        for line in proc.stdout:
            clean = line.rstrip()
            log_msg(widget, f"  {clean}")
            if pkg_callback:
                m = pkg_pattern.search(clean)
                if m:
                    pkg_callback(int(m.group(1)), int(m.group(2)))

    proc.wait()
    if proc.returncode != 0:
        raise RuntimeError(f"Command '{cmd[0]}' failed with exit code {proc.returncode}")


def run_installation_worker(config: AstraConfig, widget: Any) -> None:
    """Main background installation thread."""
    try:
        log_msg(widget, "Starting AstraOS Supervised Installation Worker...")
        log_msg(widget, f"Target: {config.hostname} | Storage: {config.storage_plan.mode.value}")

        # -------------------------------------------------------------
        # Phase 0: Preflight checks & Mirrors
        # -------------------------------------------------------------
        widget.set_phase(0, "Preflight checks & network")
        log_msg(widget, "Validating time synchronization and mirror reachability...")
        if os.path.exists("/usr/bin/timedatectl"):
            subprocess.run(["timedatectl", "set-ntp", "true"], check=False)

        # Refresh package databases
        run_command_stream(["pacman", "-Sy"], widget)

        # -------------------------------------------------------------
        # Phase 1: Preparing storage & partitions
        # -------------------------------------------------------------
        widget.set_phase(1, "Preparing storage & partitions")
        plan = config.storage_plan

        if plan.mode == StorageMode.ERASE:
            log_msg(widget, f"Creating partition table backup for {plan.disk_path}...")
            create_partition_backup(plan.disk_path, LOG_DIR)

            log_msg(widget, f"Initializing fresh GPT label on {plan.disk_path}...")
            run_command_stream(["sgdisk", "-Z", plan.disk_path], widget)
            run_command_stream(["sgdisk", "-o", plan.disk_path], widget)

            # Partition 1: ESP (1 GiB FAT32)
            log_msg(widget, "Creating 1 GiB EFI System Partition...")
            run_command_stream(["sgdisk", "-n", "1:2048:+1G", "-t", "1:ef00", "-c", "1:AstraESP", plan.disk_path], widget)

            # Format ESP
            run_command_stream(["udevadm", "settle"], widget)
            run_command_stream(["mkfs.fat", "-F32", "-n", "AstraESP", plan.esp_device], widget)

            # Partition 2: Root (Btrfs)
            log_msg(widget, "Creating Btrfs root partition...")
            run_command_stream(["sgdisk", "-n", "2:0:0", "-t", "2:8300", "-c", "2:AstraOS", plan.disk_path], widget)
            run_command_stream(["udevadm", "settle"], widget)
            run_command_stream(["mkfs.btrfs", "-f", "-L", "AstraOS", plan.root_device], widget)

            # Create Subvolumes: @, @home, @log, @pkg, @snapshots
            log_msg(widget, "Creating Btrfs subvolumes (@, @home, @log, @pkg, @snapshots)...")
            TARGET_MOUNT.mkdir(parents=True, exist_ok=True)
            subprocess.run(["mount", plan.root_device, str(TARGET_MOUNT)], check=True)
            for subvol in ("@", "@home", "@log", "@pkg", "@snapshots"):
                subprocess.run(["btrfs", "subvolume", "create", f"/mnt/{subvol}"], check=True)
            subprocess.run(["umount", str(TARGET_MOUNT)], check=True)

            # Mount subvolume layout with zstd compression
            btrfs_opts = "noatime,compress=zstd:1,space_cache=v2,discard=async"
            subprocess.run(["mount", "-o", f"subvol=@,{btrfs_opts}", plan.root_device, str(TARGET_MOUNT)], check=True)
            for sv, path in [("@home", "home"), ("@log", "var/log"), ("@pkg", "var/cache/pacman/pkg"), ("@snapshots", ".snapshots")]:
                p = TARGET_MOUNT / path
                p.mkdir(parents=True, exist_ok=True)
                subprocess.run(["mount", "-o", f"subvol={sv},{btrfs_opts}", plan.root_device, str(p)], check=True)

            # Mount ESP at /boot/efi
            esp_dir = TARGET_MOUNT / "boot" / "efi"
            esp_dir.mkdir(parents=True, exist_ok=True)
            subprocess.run(["mount", plan.esp_device, str(esp_dir)], check=True)

        elif plan.mode == StorageMode.PRE_MOUNTED:
            log_msg(widget, "Using existing /mnt mounts. Bypassing disk repartitioning.")

        # -------------------------------------------------------------
        # Phase 2: Installing base system
        # -------------------------------------------------------------
        widget.set_phase(2, "Installing base system (pacstrap)")
        base_pkgs = [
            "base", "base-devel", "linux", "linux-firmware", "btrfs-progs",
            "dosfstools", "e2fsprogs", "zsh", "sudo", "networkmanager",
            "grub", "efibootmgr", "arch-install-scripts",
        ]
        log_msg(widget, f"Running pacstrap for core packages: {', '.join(base_pkgs)}")

        # Ensure /mnt/etc exists for pacman config copy
        (TARGET_MOUNT / "etc" / "pacman.d").mkdir(parents=True, exist_ok=True)

        # Copy host pacman config + mirrorlist into target so chroot pacman works
        if Path("/etc/pacman.conf").exists():
            shutil.copy2("/etc/pacman.conf", TARGET_MOUNT / "etc" / "pacman.conf")
            log_msg(widget, "Copied /etc/pacman.conf to target.")
        if Path("/etc/pacman.d/mirrorlist").exists():
            shutil.copy2("/etc/pacman.d/mirrorlist", TARGET_MOUNT / "etc" / "pacman.d" / "mirrorlist")
            log_msg(widget, "Copied mirrorlist to target.")

        # Copy live astra-local repo into target so chroot pacman can install
        # AstraOS packages (paru, noctalia, etc.) from the offline repo.
        live_repo = Path("/usr/share/astra/repo")
        target_repo = TARGET_MOUNT / "usr" / "share" / "astra" / "repo"
        if live_repo.exists():
            target_repo.mkdir(parents=True, exist_ok=True)
            if not target_repo.exists() or not any(target_repo.iterdir()):
                shutil.copytree(live_repo, target_repo, dirs_exist_ok=True)
                log_msg(widget, "Copied astra-local offline repo to target.")

        # Use -c (host cache) + -M (skip mirrorlist re-copy, we already did it)
        # Do NOT use -N (unshare mode causes namespace isolation that loses /mnt writes)
        # Do NOT use -K (generates new keyring from scratch; extremely slow / fails on low entropy VMs)
        # Flags: -c = use host pkg cache, -M = skip mirrorlist copy (we copied it manually)
        run_command_stream(
            ["pacstrap", "-c", "-M", str(TARGET_MOUNT)] + base_pkgs,
            widget,
            pkg_callback=widget.update_package_progress
        )

        # Verify pacman actually landed in the target
        if not (TARGET_MOUNT / "usr" / "bin" / "pacman").exists():
            raise RuntimeError(
                "pacstrap completed but /usr/bin/pacman not found in target. "
                "The base system was not installed correctly."
            )

        # Generate fstab
        log_msg(widget, "Generating /etc/fstab with UUIDs...")
        res = subprocess.run(["genfstab", "-U", str(TARGET_MOUNT)], stdout=subprocess.PIPE, text=True, check=True)
        (TARGET_MOUNT / "etc" / "fstab").write_text(res.stdout)

        # Inject astra-local repo into target /etc/pacman.conf so chroot pacman
        # can resolve paru, noctalia, quickshell, etc. from the offline repo.
        target_pacman_conf = TARGET_MOUNT / "etc" / "pacman.conf"
        if target_pacman_conf.exists():
            conf_text = target_pacman_conf.read_text()
            astra_repo_block = (
                "\n[astra-local]\n"
                "SigLevel = Optional TrustAll\n"
                "Server = file:///usr/share/astra/repo\n"
            )
            if "[astra-local]" not in conf_text:
                conf_text += astra_repo_block
                target_pacman_conf.write_text(conf_text)
                log_msg(widget, "Injected [astra-local] repo into target pacman.conf.")

        # Refresh package databases in chroot (picks up astra-local)
        run_chroot(TARGET_MOUNT, ["pacman", "-Sy", "--noconfirm"], widget.append_log)

        # -------------------------------------------------------------
        # Phase 3: Installing AstraOS desktop packages
        # AUR-only packages (paru, yay, helium-browser-bin, brave) cannot
        # be installed via chroot pacman from official repos.  We split them:
        #   - official_pkgs  → installed now via arch-chroot pacman
        #   - pending_pkgs   → written to a list file; the astra-pending-packages
        #                      service installs them with paru on first boot.
        # -------------------------------------------------------------
        widget.set_phase(3, "Installing AstraOS desktop and tools")

        # Packages known to be AUR-only (not in any official Arch repo)
        AUR_ONLY = {"paru", "yay", "helium-browser-bin", "brave", "brave-browser"}

        official_extra: list[str] = ["kitty", "pipewire", "pipewire-pulse", "wireplumber", "sddm"]
        pending_aur: list[str] = []

        if config.browser.value not in ("none",):
            pkg = config.browser.value
            if pkg in AUR_ONLY:
                pending_aur.append(pkg)
            else:
                official_extra.append(pkg)

        if config.aur_helper.value not in ("none",):
            pkg = config.aur_helper.value
            if pkg in AUR_ONLY:
                # paru/yay – try from astra-local repo first; fall back to pending
                pending_aur.append(pkg)
            else:
                official_extra.append(pkg)

        if config.os_prober:
            official_extra.extend(["os-prober", "ntfs-3g"])

        for pkg in config.additional_packages:
            if pkg in AUR_ONLY:
                pending_aur.append(pkg)
            else:
                official_extra.append(pkg)

        # Try to install astra-local packages (paru, noctalia, etc.) via chroot pacman.
        # Because the astra-local repo is now present in the target, this should work.
        astra_desktop_pkgs = [
            "niri", "noctalia", "quickshell", "xwayland-satellite",
            "kitty", "pipewire", "pipewire-pulse", "wireplumber",
            "pipewire-alsa", "pipewire-jack", "wireplumber",
            "sddm", "networkmanager",
            "zsh", "zsh-autosuggestions", "zsh-syntax-highlighting",
            "neovim", "git", "fzf", "fd", "ripgrep", "bat", "eza", "btop", "fastfetch",
            "noto-fonts", "noto-fonts-emoji", "ttf-jetbrains-mono-nerd",
            "nautilus", "loupe", "mpv", "pavucontrol",
            "bluez", "bluez-utils",
            "polkit", "gnome-keyring",
            "xdg-user-dirs", "xdg-utils",
            "wl-clipboard", "grim", "slurp",
        ]
        # Merge with user selections (deduplicate)
        all_official = list(dict.fromkeys(astra_desktop_pkgs + official_extra))

        log_msg(widget, f"Installing {len(all_official)} desktop packages via pacman...")
        run_chroot(TARGET_MOUNT, ["pacman", "-S", "--noconfirm", "--needed"] + all_official, widget.append_log)

        # Try to install paru from astra-local repo (it is pre-built there)
        if pending_aur:
            log_msg(widget, f"Attempting astra-local install for AUR packages: {', '.join(pending_aur)}")
            try:
                run_chroot(TARGET_MOUNT, ["pacman", "-S", "--noconfirm", "--needed"] + pending_aur, widget.append_log)
                pending_aur = []  # cleared – installed OK from astra-local
            except RuntimeError as e:
                log_msg(widget, f"[warn] astra-local install failed ({e}); queuing for first-boot paru install.")

        # Queue any remaining AUR packages for first-boot installation
        if pending_aur:
            pending_dir = TARGET_MOUNT / "var" / "lib" / "astra"
            pending_dir.mkdir(parents=True, exist_ok=True)
            pending_file = pending_dir / "pending-packages"
            with open(pending_file, "a") as pf:
                pf.write("\n".join(pending_aur) + "\n")
            log_msg(widget, f"Queued for first-boot paru install: {', '.join(pending_aur)}")

        # -------------------------------------------------------------
        # Phase 4: Configuring users & services
        # -------------------------------------------------------------
        widget.set_phase(4, "Configuring system identity and accounts")
        log_msg(widget, f"Setting hostname '{config.hostname}'...")
        (TARGET_MOUNT / "etc" / "hostname").write_text(f"{config.hostname}\n")

        # Timezone & Clock
        log_msg(widget, f"Setting timezone '{config.timezone}'...")
        run_chroot(TARGET_MOUNT, ["ln", "-sf", f"/usr/share/zoneinfo/{config.timezone}", "/etc/localtime"], widget.append_log)
        run_chroot(TARGET_MOUNT, ["hwclock", "--systohc"], widget.append_log)

        # Locale
        log_msg(widget, f"Generating locale '{config.locale}'...")
        (TARGET_MOUNT / "etc" / "locale.conf").write_text(f"LANG={config.locale}\n")
        (TARGET_MOUNT / "etc" / "vconsole.conf").write_text(f"KEYMAP={config.keyboard_layout}\n")
        run_chroot(TARGET_MOUNT, ["locale-gen"], widget.append_log)

        # Set Root Password
        log_msg(widget, "Setting administrative root password...")
        p = subprocess.Popen(["arch-chroot", str(TARGET_MOUNT), "chpasswd"], stdin=subprocess.PIPE, text=True)
        _, err = p.communicate(f"root:{config.root_password}\n")
        if p.returncode != 0:
            raise RuntimeError(f"Setting root password failed: {err}")

        # Create User
        log_msg(widget, f"Creating user account '{config.username}' with zsh...")
        run_chroot(TARGET_MOUNT, ["useradd", "-m", "-U", "-s", "/bin/zsh", config.username], widget.append_log)
        p = subprocess.Popen(["arch-chroot", str(TARGET_MOUNT), "chpasswd"], stdin=subprocess.PIPE, text=True)
        _, err = p.communicate(f"{config.username}:{config.user_password}\n")
        if p.returncode != 0:
            raise RuntimeError(f"Setting user password failed: {err}")

        # Sudo configuration (wheel)
        configure_sudo_rules(TARGET_MOUNT, config, widget.append_log)
        if config.sudo_mode.value == "with_password":
            run_chroot(TARGET_MOUNT, ["usermod", "-aG", "wheel,video,audio,input,storage", config.username], widget.append_log)

        # Enable core systemd services
        log_msg(widget, "Enabling NetworkManager, sddm, and fstrim.timer...")
        run_chroot(TARGET_MOUNT, ["systemctl", "enable", "NetworkManager.service", "sddm.service", "fstrim.timer"], widget.append_log)

        # -------------------------------------------------------------
        # Phase 5: Installing GRUB bootloader
        # -------------------------------------------------------------
        widget.set_phase(5, "Installing and configuring GRUB bootloader")
        log_msg(widget, "Running grub-install for UEFI (x86_64-efi)...")
        run_chroot(
            TARGET_MOUNT,
            ["grub-install", "--target=x86_64-efi", "--efi-directory=/boot/efi", "--bootloader-id=AstraOS", "--recheck"],
            widget.append_log
        )

        if config.os_prober:
            log_msg(widget, "Enabling GRUB_DISABLE_OS_PROBER=false...")
            grub_default = TARGET_MOUNT / "etc" / "default" / "grub"
            if grub_default.exists():
                text = grub_default.read_text()
                if "GRUB_DISABLE_OS_PROBER=" in text:
                    text = re.sub(r"^GRUB_DISABLE_OS_PROBER=.*", "GRUB_DISABLE_OS_PROBER=false", text, flags=re.M)
                else:
                    text += "\nGRUB_DISABLE_OS_PROBER=false\n"
                grub_default.write_text(text)

        log_msg(widget, "Generating /boot/grub/grub.cfg...")
        run_chroot(TARGET_MOUNT, ["grub-mkconfig", "-o", "/boot/grub/grub.cfg"], widget.append_log)

        # -------------------------------------------------------------
        # Phase 6: Finishing installation
        # -------------------------------------------------------------
        widget.set_phase(6, "Applying AstraOS branding and finishing")
        apply_astra_identity(TARGET_MOUNT, widget.append_log)
        copy_wifi_profiles(TARGET_MOUNT, widget.append_log)
        seed_lazyvim(TARGET_MOUNT, config.username, widget.append_log)
        remove_live_leftovers(TARGET_MOUNT, widget.append_log)

        # Verify untouched partition safety
        disks = discover_disks()
        safe, safety_errors = verify_untouched_partitions(plan, disks)
        if not safe:
            raise RuntimeError(f"Storage safety check failed: {'; '.join(safety_errors)}")

        log_msg(widget, "AstraOS installation successfully completed!")
        widget.on_complete()

    except Exception as exc:
        log_msg(widget, f"EXCEPTION in installer worker: {exc}")
        widget.set_error(str(exc))
