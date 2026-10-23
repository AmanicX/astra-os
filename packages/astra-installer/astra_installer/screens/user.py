"""
Screen 10: User Account Creation.
Username (validated regex) and user password (entered twice, masked).
"""

from __future__ import annotations

from typing import Callable

from textual.app import ComposeResult
from textual.containers import Container, Vertical
from textual.widgets import Input, Label, Static

from astra_installer.models import AstraConfig
from astra_installer.screens.root_pw import password_strength
from astra_installer.theme import COLOR_AMBER, COLOR_GREEN, COLOR_RED


class UserAccountScreenWidget(Container):
    """Screen 10: Primary user account."""

    def __init__(self, config: AstraConfig, on_change: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_change = on_change
        self.username = self.config.username
        self.p1 = self.config.user_password
        self.p2 = self.config.user_password

    def compose(self) -> ComposeResult:
        yield Label("Primary User Account", classes="screen-title")
        yield Label("Create your personal user account for logging in to AstraOS.", classes="screen-desc")

        with Vertical():
            yield Label("Username:", classes="screen-desc")
            yield Input(value=self.username, placeholder="e.g. alex, dev, user (lowercase)...", id="input-username")
            yield Static("", id="user-name-feedback")

            yield Label("User Password:", classes="screen-desc")
            yield Input(password=True, placeholder="Enter user password...", id="input-user-pw1")

            yield Label("Confirm User Password:", classes="screen-desc")
            yield Input(password=True, placeholder="Confirm user password...", id="input-user-pw2")
            yield Static("", id="user-pw-feedback")

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "input-username":
            self.username = event.value.strip().lower()
        elif event.input.id == "input-user-pw1":
            self.p1 = event.value
        elif event.input.id == "input-user-pw2":
            self.p2 = event.value

        self.validate()

    def validate(self) -> None:
        name_fb = self.query_one("#user-name-feedback", Static)
        pw_fb = self.query_one("#user-pw-feedback", Static)

        ok_name, err_name = AstraConfig.validate_username(self.username)
        if ok_name:
            name_fb.update(f"[{COLOR_GREEN}]✓ Valid username: {self.username}[/]")
            self.config.username = self.username
        else:
            name_fb.update(f"[{COLOR_AMBER}]⚠ {err_name}[/]")
            self.config.username = ""

        if not self.p1:
            pw_fb.update(f"[{COLOR_AMBER}]⚠ User password cannot be empty.[/]")
            self.config.user_password = ""
        elif len(self.p1) < 4:
            pw_fb.update(f"[{COLOR_RED}]✗ Password must be at least 4 characters.[/]")
            self.config.user_password = ""
        elif self.p1 != self.p2:
            desc, col = password_strength(self.p1)
            pw_fb.update(f"[{col}]Strength: {desc}[/] • [{COLOR_RED}]✗ Passwords do not match yet.[/]")
            self.config.user_password = ""
        else:
            desc, col = password_strength(self.p1)
            pw_fb.update(f"[{COLOR_GREEN}]✓ Passwords match[/] • [{col}]Strength: {desc}[/]")
            self.config.user_password = self.p1

        self.on_change()
