"""
Screen 8: System Hostname.
Default 'astraos' or custom name validated against RFC 1123.
"""

from __future__ import annotations

from typing import Callable

from textual.app import ComposeResult
from textual.containers import Container, Vertical
from textual.widgets import Input, Label, RadioButton, RadioSet, Static

from astra_installer.models import AstraConfig
from astra_installer.theme import COLOR_AMBER, COLOR_CYAN, COLOR_GREEN


class HostnameScreenWidget(Container):
    """Screen 08: Hostname configuration."""

    def __init__(self, config: AstraConfig, on_change: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_change = on_change
        self.custom_mode = (self.config.hostname != "astraos")

    def compose(self) -> ComposeResult:
        yield Label("System Hostname", classes="screen-title")
        yield Label("Choose the name that identifies your computer on the local network.", classes="screen-desc")

        with RadioSet(id="radio-host"):
            yield RadioButton(
                "Use standard default name (astraos)",
                value=not self.custom_mode,
                id="opt-default-host"
            )
            yield RadioButton(
                "Choose a custom hostname",
                value=self.custom_mode,
                id="opt-custom-host"
            )

        with Vertical(id="host-input-container"):
            yield Label("Enter computer hostname (1–63 characters):", classes="screen-desc")
            yield Input(
                value=self.config.hostname,
                placeholder="e.g. astra-laptop, desktop...",
                id="input-hostname"
            )
            yield Static("", id="host-validation-msg")

    def on_mount(self) -> None:
        self.update_ui()

    def update_ui(self) -> None:
        input_box = self.query_one("#host-input-container")
        input_box.display = self.custom_mode
        self.validate()

    def validate(self) -> None:
        msg = self.query_one("#host-validation-msg", Static)
        ok, err = AstraConfig.validate_hostname(self.config.hostname)
        if ok:
            msg.update(f"[{COLOR_GREEN}]✓ Valid hostname: {self.config.hostname}[/]")
        else:
            msg.update(f"[{COLOR_AMBER}]⚠ {err}[/]")
        self.on_change()

    def on_radio_set_changed(self, event: RadioSet.Changed) -> None:
        if event.pressed.id == "opt-default-host":
            self.custom_mode = False
            self.config.hostname = "astraos"
            inp = self.query_one("#input-hostname", Input)
            inp.value = "astraos"
        else:
            self.custom_mode = True

        self.update_ui()

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "input-hostname":
            self.config.hostname = event.value.strip().lower()
            self.validate()
