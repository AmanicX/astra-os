"""
Screen 13: Extra Boot Entries (os-prober & GRUB).
Allows detecting Windows / other Linux systems and adding them to GRUB menu.
"""

from __future__ import annotations

import shutil
import subprocess
from typing import Callable, List

from textual.app import ComposeResult
from textual.containers import Container, Vertical
from textual.widgets import Label, RadioButton, RadioSet, Static

from astra_installer.models import AstraConfig
from astra_installer.theme import COLOR_CYAN, COLOR_GREEN, COLOR_MUTED


def probe_other_operating_systems() -> List[str]:
    """Run os-prober to discover any co-existing operating systems."""
    found: List[str] = []
    if shutil.which("os-prober"):
        try:
            res = subprocess.run(["os-prober"], stdout=subprocess.PIPE, text=True, check=False)
            if res.returncode == 0:
                for line in res.stdout.splitlines():
                    parts = line.strip().split(":")
                    if len(parts) >= 2:
                        found.append(f"{parts[1]} on {parts[0]}")
        except Exception:
            pass
    return found


class BootloaderScreenWidget(Container):
    """Screen 13: Extra boot entries and os-prober."""

    def __init__(self, config: AstraConfig, on_change: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_change = on_change
        self.detected = probe_other_operating_systems()
        self.config.detected_other_os = self.detected
        if self.detected:
            self.config.os_prober = True

    def compose(self) -> ComposeResult:
        yield Label("Bootloader & Multi-Boot (GRUB)", classes="screen-title")
        yield Label("GRUB is configured with AstraOS styling and Btrfs snapshot support.", classes="screen-desc")

        with Vertical(classes="explain-panel"):
            yield Static(f"[bold {COLOR_CYAN}]OS Prober Status[/]")
            if self.detected:
                yield Static(f"[{COLOR_GREEN}]✓ Detected other operating system(s):[/]")
                for item in self.detected:
                    yield Static(f"  • {item}")
            else:
                yield Static("No other installed operating systems detected on local disks.")

        with RadioSet(id="radio-os-prober"):
            yield RadioButton(
                "Detect other operating systems (Enable os-prober) — Recommended",
                value=self.config.os_prober,
                id="opt-prober-yes"
            )
            yield RadioButton(
                "Do not search for other operating systems (Disable os-prober)",
                value=not self.config.os_prober,
                id="opt-prober-no"
            )

        with Vertical(classes="explain-panel"):
            yield Static("Enabling os-prober installs [bold]os-prober[/] and [bold]ntfs-3g[/], enabling dual-boot menus for Windows and other distributions.")

    def on_radio_set_changed(self, event: RadioSet.Changed) -> None:
        self.config.os_prober = (event.pressed.id == "opt-prober-yes")
        self.on_change()
