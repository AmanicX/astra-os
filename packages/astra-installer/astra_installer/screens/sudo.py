"""
Screen 11: Sudo Privilege Configuration.
Options:
  1) Sudo with user password (Administrator in wheel group)
  2) Standard account (No sudo privileges)
Passwordless sudo is explicitly omitted (NOPASSWD forbidden).
"""

from __future__ import annotations

from typing import Callable

from textual.app import ComposeResult
from textual.containers import Container, Vertical
from textual.widgets import Label, RadioButton, RadioSet, Static

from astra_installer.models import AstraConfig, SudoMode
from astra_installer.theme import COLOR_CYAN, COLOR_MUTED


class SudoScreenWidget(Container):
    """Screen 11: Administrative privileges."""

    def __init__(self, config: AstraConfig, on_change: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_change = on_change

    def compose(self) -> ComposeResult:
        yield Label("Administrative Privileges (sudo)", classes="screen-title")
        yield Label("Choose whether this user account can perform administrative tasks.", classes="screen-desc")

        with RadioSet(id="radio-sudo"):
            yield RadioButton(
                "Sudo with user password (Administrator) — Recommended",
                value=(self.config.sudo_mode == SudoMode.WITH_PASSWORD),
                id="opt-sudo-password"
            )
            yield RadioButton(
                "Standard account (No sudo access) — System changes require root login",
                value=(self.config.sudo_mode == SudoMode.NONE),
                id="opt-sudo-none"
            )

        with Vertical(classes="explain-panel"):
            yield Static(f"[bold {COLOR_CYAN}]Security Architecture[/]")
            yield Static("• [bold]Administrator[/]: Adds user to the 'wheel' group. Running privileged commands (e.g. system updates) will prompt for the user's own password.\n"
                         "• [bold]Standard Account[/]: The account cannot execute 'sudo'. Administrative changes must be done by switching directly to root with 'su'.\n"
                         "• [bold]Passwordless Sudo[/]: Disabled by design for AstraOS security compliance.")

    def on_radio_set_changed(self, event: RadioSet.Changed) -> None:
        if event.pressed.id == "opt-sudo-password":
            self.config.sudo_mode = SudoMode.WITH_PASSWORD
        else:
            self.config.sudo_mode = SudoMode.NONE
        self.on_change()
