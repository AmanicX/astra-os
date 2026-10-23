"""
Screen 9: Root Password Setup.
Entered twice, masked, non-empty, with dynamic strength indicator.
"""

from __future__ import annotations

from typing import Callable

from textual.app import ComposeResult
from textual.containers import Container, Vertical
from textual.widgets import Input, Label, Static

from astra_installer.models import AstraConfig
from astra_installer.theme import COLOR_AMBER, COLOR_GREEN, COLOR_RED


def password_strength(pw: str) -> tuple[str, str]:
    if not pw:
        return "", ""
    if len(pw) < 6:
        return "Weak (Too short)", COLOR_RED
    has_digit = any(c.isdigit() for c in pw)
    has_upper = any(c.isupper() for c in pw)
    has_special = any(not c.isalnum() for c in pw)

    score = int(has_digit) + int(has_upper) + int(has_special)
    if len(pw) >= 10 and score >= 2:
        return "Strong", COLOR_GREEN
    elif len(pw) >= 8 and score >= 1:
        return "Moderate", COLOR_AMBER
    return "Fair", COLOR_AMBER


class RootPasswordScreenWidget(Container):
    """Screen 09: Root administrative password."""

    def __init__(self, config: AstraConfig, on_change: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_change = on_change
        self.p1 = self.config.root_password
        self.p2 = self.config.root_password

    def compose(self) -> ComposeResult:
        yield Label("Root Password Setup", classes="screen-title")
        yield Label("Set the superuser (root) administrative password. You must enter it twice.", classes="screen-desc")

        with Vertical():
            yield Label("Root Password:", classes="screen-desc")
            yield Input(password=True, placeholder="Enter root password...", id="input-root-pw1")

            yield Label("Confirm Root Password:", classes="screen-desc")
            yield Input(password=True, placeholder="Confirm root password...", id="input-root-pw2")

            yield Static("", id="root-pw-feedback")

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "input-root-pw1":
            self.p1 = event.value
        elif event.input.id == "input-root-pw2":
            self.p2 = event.value

        self.validate()

    def validate(self) -> None:
        feedback = self.query_one("#root-pw-feedback", Static)
        if not self.p1:
            feedback.update(f"[{COLOR_AMBER}]⚠ Root password cannot be empty.[/]")
            self.config.root_password = ""
        elif len(self.p1) < 4:
            feedback.update(f"[{COLOR_RED}]✗ Password must be at least 4 characters.[/]")
            self.config.root_password = ""
        elif self.p1 != self.p2:
            desc, col = password_strength(self.p1)
            feedback.update(f"[{col}]Strength: {desc}[/] • [{COLOR_RED}]✗ Passwords do not match yet.[/]")
            self.config.root_password = ""
        else:
            desc, col = password_strength(self.p1)
            feedback.update(f"[{COLOR_GREEN}]✓ Passwords match[/] • [{col}]Strength: {desc}[/]")
            self.config.root_password = self.p1

        self.on_change()
