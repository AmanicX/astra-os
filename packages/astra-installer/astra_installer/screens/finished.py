"""
Screen 17: Installation Finished & Reboot Confirmation.
Asks: 'Reboot now?' (Yes / No).
Never reboots automatically.
"""

from __future__ import annotations

import os
import subprocess
from typing import Callable

from textual.app import ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Button, Label, Static

from astra_installer.models import AstraConfig
from astra_installer.theme import COLOR_CYAN, COLOR_GREEN


class FinishedScreenWidget(Container):
    """Screen 17: Completion and reboot prompt."""

    def __init__(self, config: AstraConfig, on_exit_app: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_exit_app = on_exit_app

    def compose(self) -> ComposeResult:
        yield Label("Installation Complete!", classes="screen-title")
        yield Label("AstraOS has been successfully installed on your computer.", classes="screen-desc")

        with Vertical(classes="explain-panel"):
            yield Static(f"[{COLOR_GREEN}]✓ All packages, users, and bootloader entries are installed.[/]")
            yield Static(f"• Target root: [bold]{self.config.storage_plan.root_device or self.config.storage_plan.premounted_root}[/]")
            yield Static(f"• User: [bold]{self.config.username}[/] ({self.config.hostname})")
            yield Static(f"• Install log saved to: /var/log/astra-install/install.log")

        with Vertical():
            yield Label("Would you like to reboot into your new AstraOS installation now?", classes="screen-desc")
            with Horizontal():
                yield Button("Reboot Now", id="btn-reboot-now", classes="btn-primary")
                yield Button("Return to Live Desktop", id="btn-return-live", classes="btn-secondary")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "btn-reboot-now":
            # Clean sync and reboot
            subprocess.run(["sync"])
            subprocess.run(["systemctl", "reboot"])
            self.on_exit_app()
        elif event.button.id == "btn-return-live":
            self.on_exit_app()
