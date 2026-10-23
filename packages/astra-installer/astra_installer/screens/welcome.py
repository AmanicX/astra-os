"""
Screen 1: Welcome & System Health Checks.
Verifies UEFI, RAM, Disk, and Network connectivity.
Provides a Connect button to open nmtui if offline.
"""

from __future__ import annotations

import os
import shutil
import socket
import subprocess
from pathlib import Path
from typing import Callable

from textual.app import ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Button, Label, Static

from astra_installer.models import AstraConfig
from astra_installer.storage_guard import discover_disks
from astra_installer.theme import ASTRA_BANNER, ASTRA_STAR_SMALL, COLOR_CYAN, COLOR_GREEN, COLOR_RED, COLOR_AMBER


def check_internet() -> bool:
    """Check connectivity against common public DNS/NTP servers."""
    for host, port in [("1.1.1.1", 53), ("8.8.8.8", 53), ("archlinux.org", 80)]:
        try:
            socket.create_connection((host, port), timeout=2.5).close()
            return True
        except OSError:
            continue
    return False


def check_uefi() -> bool:
    if os.environ.get("ASTRA_SKIP_UEFI") == "1":
        return True
    return Path("/sys/firmware/efi").exists()


def check_secure_boot() -> bool:
    sb_var = Path("/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c")
    if sb_var.exists():
        try:
            data = sb_var.read_bytes()
            return len(data) >= 5 and data[4] == 1
        except Exception:
            return False
    return False


def get_memory_mib() -> int:
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    kb = int(line.split()[1])
                    return kb // 1024
    except Exception:
        pass
    return 4096


class WelcomeScreenWidget(Container):
    """Screen 01: Welcome & Preflight diagnostics."""

    def __init__(self, config: AstraConfig, on_change: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_change = on_change
        self.disks = discover_disks()

    def compose(self) -> ComposeResult:
        yield Label("Welcome to AstraOS", classes="screen-title")
        yield Label("A calm, design-driven Linux system crafted around Niri and Noctalia.", classes="screen-desc")

        # Diagnostics Status Grid
        with Vertical(classes="explain-panel"):
            yield Static(f"{ASTRA_BANNER} Installer v1.0 • System Health Checks", id="welcome-subhead")

            # 1. UEFI
            is_uefi = check_uefi()
            self.config.uefi_ok = is_uefi
            uefi_color = COLOR_GREEN if is_uefi else COLOR_RED
            uefi_icon = "✓" if is_uefi else "✗"
            yield Static(f"[{uefi_color}]{uefi_icon} Boot Architecture:[/] {'UEFI (x86_64)' if is_uefi else 'BIOS / CSM (Unsupported)'}")

            # 2. Internet
            has_net = check_internet()
            self.config.network_ok = has_net
            net_color = COLOR_GREEN if has_net else COLOR_RED
            net_icon = "✓" if has_net else "✗"
            net_status = "Connected (Online installation ready)" if has_net else "Disconnected (Internet required)"
            yield Static(f"[{net_color}]{net_icon} Network:[/] {net_status}")

            # 3. Secure Boot
            sb = check_secure_boot()
            self.config.secure_boot = sb
            sb_text = f"[{COLOR_AMBER}]⚠ Secure Boot:[/] Enabled (Disable in UEFI firmware)" if sb else f"[{COLOR_GREEN}]✓ Secure Boot:[/] Disabled"
            yield Static(sb_text)

            # 4. RAM
            mem = get_memory_mib()
            self.config.memory_mib = mem
            mem_ok = mem >= 3500
            mem_color = COLOR_GREEN if mem_ok else COLOR_AMBER
            yield Static(f"[{mem_color}]✓ System Memory:[/] {mem / 1024:.1f} GiB available")

            # 5. Usable Disks
            usable_disks = [d for d in self.disks if not d.is_live and d.size_bytes >= 35 * (1024**3)]
            disk_ok = len(usable_disks) > 0
            disk_color = COLOR_GREEN if disk_ok else COLOR_RED
            disk_icon = "✓" if disk_ok else "✗"
            yield Static(f"[{disk_color}]{disk_icon} Usable Storage Disks:[/] {len(usable_disks)} drive(s) detected (>= 35 GiB)")

        # Network Connect Helper action
        with Horizontal():
            if not self.config.network_ok:
                yield Button("Connect to Wi-Fi / Network (nmtui)", id="btn-nmtui", classes="btn-secondary")
                yield Button("Re-check Connection", id="btn-recheck-net", classes="btn-primary")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "btn-nmtui":
            if shutil.which("nmtui"):
                subprocess.run(["nmtui"])
            self.recheck()
        elif event.button.id == "btn-recheck-net":
            self.recheck()

    def recheck(self) -> None:
        self.config.network_ok = check_internet()
        self.on_change()
        self.refresh(layout=True)
