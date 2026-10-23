"""
AstraOS Post-Install Custom Hooks.
Configures target identity, SilentSDDM, Niri session, zsh, LazyVim,
hardware microcode, and GPU drivers.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path
from typing import Callable, Optional

from astra_installer.models import AstraConfig, SudoMode


def run_chroot(target: Path, cmd: list[str], log_fn: Optional[Callable[[str], None]] = None) -> None:
    """Run command inside target arch-chroot."""
    full_cmd = ["arch-chroot", str(target)] + cmd
    if log_fn:
        log_fn(f"[arch-chroot] {' '.join(cmd)}")
    res = subprocess.run(full_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if log_fn and res.stdout:
        for line in res.stdout.splitlines():
            log_fn(f"  {line}")
    if res.returncode != 0:
        raise RuntimeError(f"Chroot command failed (code {res.returncode}): {' '.join(cmd)}")


def apply_astra_identity(target: Path, log_fn: Optional[Callable[[str], None]] = None) -> None:
    """Write /etc/os-release and setup pacman hook to preserve AstraOS branding."""
    os_release = target / "etc" / "os-release"
    os_release.parent.mkdir(parents=True, exist_ok=True)
    os_release.write_text(
        'NAME="AstraOS"\n'
        'PRETTY_NAME="AstraOS Linux"\n'
        'ID=astraos\n'
        'ID_LIKE=arch\n'
        'BUILD_ID=rolling\n'
        'ANSI_COLOR="38;2;94;230;242"\n'
        'HOME_URL="https://github.com/AmanicX/astra-os"\n'
        'SUPPORT_URL="https://github.com/AmanicX/astra-os/issues"\n'
        'BUG_REPORT_URL="https://github.com/AmanicX/astra-os/issues"\n'
        'LOGO=astraos-logo\n'
    )

    # Pacman hook to restore os-release on filesystem updates
    hook_dir = target / "etc" / "pacman.d" / "hooks"
    hook_dir.mkdir(parents=True, exist_ok=True)
    (hook_dir / "99-astra-os-release.hook").write_text(
        "[Trigger]\n"
        "Operation = Install\n"
        "Operation = Upgrade\n"
        "Type = Package\n"
        "Target = filesystem\n\n"
        "[Action]\n"
        "Description = Re-applying AstraOS identity...\n"
        "When = PostTransaction\n"
        'Exec = /usr/bin/bash -c \'sed -i "s/^NAME=.*/NAME=\\"AstraOS\\"/; s/^ID=.*/ID=astraos/" /etc/os-release\'\n'
    )
    if log_fn:
        log_fn("Applied AstraOS identity and filesystem protection hook.")


def copy_wifi_profiles(target: Path, log_fn: Optional[Callable[[str], None]] = None) -> None:
    """Copy connected live Wi-Fi network profiles to target NetworkManager."""
    live_nm = Path("/etc/NetworkManager/system-connections")
    target_nm = target / "etc" / "NetworkManager" / "system-connections"
    if live_nm.exists() and any(live_nm.iterdir()):
        target_nm.mkdir(parents=True, exist_ok=True)
        for profile in live_nm.glob("*.nmconnection"):
            shutil.copy2(profile, target_nm / profile.name)
            os.chmod(target_nm / profile.name, 0o600)
            if log_fn:
                log_fn(f"Preserved Wi-Fi profile: {profile.name}")


def seed_lazyvim(target: Path, username: str, log_fn: Optional[Callable[[str], None]] = None) -> None:
    """Seed LazyVim plugins non-fatally from live ISO if present."""
    live_nvim = Path("/usr/share/astra/nvim/lazy")
    if live_nvim.exists() and username and username != "root":
        user_nvim = target / "home" / username / ".local" / "share" / "nvim" / "lazy"
        user_nvim.parent.mkdir(parents=True, exist_ok=True)
        if not user_nvim.exists():
            shutil.copytree(live_nvim, user_nvim)
            run_chroot(target, ["chown", "-R", f"{username}:{username}", f"/home/{username}/.local"], log_fn)
            if log_fn:
                log_fn("Seeded pre-baked LazyVim plugin tree.")


def configure_sudo_rules(target: Path, config: AstraConfig, log_fn: Optional[Callable[[str], None]] = None) -> None:
    """Ensure wheel group has standard sudo with password. NOPASSWD is strictly forbidden."""
    sudoers_d = target / "etc" / "sudoers.d"
    sudoers_d.mkdir(parents=True, exist_ok=True)
    rule_file = sudoers_d / "90-astra"

    if config.sudo_mode == SudoMode.WITH_PASSWORD:
        rule_file.write_text("%wheel ALL=(ALL:ALL) ALL\n")
        os.chmod(rule_file, 0o440)
        if log_fn:
            log_fn("Configured administrator privileges (wheel with user password).")
    else:
        if rule_file.exists():
            rule_file.unlink()
        if log_fn:
            log_fn("Configured standard account without sudo.")


def remove_live_leftovers(target: Path, log_fn: Optional[Callable[[str], None]] = None) -> None:
    """Ensure root autologin, live users, and live scripts do not persist to target."""
    autologin_conf = target / "etc" / "systemd" / "system" / "getty@tty1.service.d" / "autologin.conf"
    if autologin_conf.exists():
        autologin_conf.unlink()

    live_sh = target / "etc" / "profile.d" / "99-astra-live.sh"
    if live_sh.exists():
        live_sh.unlink()

    for p in ("root/.automated_script.sh", "root/.zlogin", "etc/skel/.automated_script.sh"):
        bad_f = target / p
        if bad_f.exists():
            bad_f.unlink()

    if log_fn:
        log_fn("Cleaned live-environment artifacts from target root.")
