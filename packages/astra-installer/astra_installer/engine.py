"""
AstraOS Supervised Installation Engine.
Executes the 7-phase installation workflow, streams real-time output,
parses pacman package counters, and recovers gracefully on error.
"""

from __future__ import annotations

import os
import re
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
            "dosfstools", "e2fsprogs", "zsh", "sudo", "networkmanager"
        ]
        log_msg(widget, f"Running pacstrap for core packages: {', '.join(base_pkgs)}")
        run_command_stream(
            ["pacstrap", "-M", str(TARGET_MOUNT)] + base_pkgs,
            widget,
            pkg_callback=widget.update_package_progress
        )

        # Generate fstab
        log_msg(widget, "Generating /etc/fstab with UUIDs...")
        code, fstab_out, _ = subprocess.run(["genfstab", "-U", str(TARGET_MOUNT)], stdout=subprocess.PIPE, text=True, check=True)
        (TARGET_MOUNT / "etc" / "fstab").write_text(fstab_out)

        # -------------------------------------------------------------
        # Phase 3: Installing AstraOS packages
        # -------------------------------------------------------------
        widget.set_phase(3, "Installing AstraOS desktop and tools")
        extra_pkgs = ["kitty", "pipewire", "pipewire-pulse", "wireplumber", "sddm"]
        if config.browser.value != "none":
            extra_pkgs.append(config.browser.value)
        if config.aur_helper.value != "none":
            extra_pkgs.append(config.aur_helper.value)
        if config.os_prober:
            extra_pkgs.extend(["os-prober", "ntfs-3g"])
        if config.additional_packages:
            extra_pkgs.extend(config.additional_packages)

        log_msg(widget, f"Installing additional selected packages: {', '.join(extra_pkgs)}")
        run_chroot(TARGET_MOUNT, ["pacman", "-S", "--noconfirm", "--needed"] + extra_pkgs, widget.append_log)

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
        p.communicate(f"root:{config.root_password}\n")

        # Create User
        log_msg(widget, f"Creating user account '{config.username}' with zsh...")
        run_chroot(TARGET_MOUNT, ["useradd", "-m", "-U", "-s", "/bin/zsh", config.username], widget.append_log)
        p = subprocess.Popen(["arch-chroot", str(TARGET_MOUNT), "chpasswd"], stdin=subprocess.PIPE, text=True)
        p.communicate(f"{config.username}:{config.user_password}\n")

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
