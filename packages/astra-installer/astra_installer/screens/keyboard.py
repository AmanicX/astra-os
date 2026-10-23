"""
Screen 2: Keyboard Layout.
Searchable list of keymaps, default 'us', with an interactive test field.
Applies immediately to live session via localectl.
"""

from __future__ import annotations

import shutil
import subprocess
from typing import Callable, List

from textual.app import ComposeResult
from textual.containers import Container, Vertical
from textual.widgets import Input, Label, OptionList
from textual.widgets.option_list import Option

from astra_installer.models import AstraConfig


def list_keymaps() -> List[str]:
    """Fetch available console keymaps."""
    if shutil.which("localectl"):
        try:
            res = subprocess.run(["localectl", "list-keymaps"], stdout=subprocess.PIPE, text=True, check=False)
            if res.returncode == 0:
                lines = [l.strip() for l in res.stdout.splitlines() if l.strip()]
                if lines:
                    return lines
        except Exception:
            pass
    return ["us", "uk", "de", "fr", "es", "it", "br", "ru", "jp", "cn", "pl", "se", "no", "dk"]


class KeyboardScreenWidget(Container):
    """Screen 02: Keyboard layout selection."""

    def __init__(self, config: AstraConfig, on_change: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_change = on_change
        self.all_keymaps = list_keymaps()
        self.filtered = self.all_keymaps[:]

    def compose(self) -> ComposeResult:
        yield Label("Keyboard Layout", classes="screen-title")
        yield Label("Select your preferred keymap. Changes apply immediately to this session.", classes="screen-desc")

        yield Input(placeholder="Type to filter keymaps (e.g. us, de, uk)...", id="input-search-kb")
        yield OptionList(id="list-keymaps")

        yield Label("Test layout below:", classes="screen-desc")
        yield Input(placeholder="Type here to test characters: @ # $ % ~ ` [ { / ...", id="input-test-kb")

    def on_mount(self) -> None:
        self.update_options()

    def update_options(self, filter_text: str = "") -> None:
        opt_list = self.query_one("#list-keymaps", OptionList)
        opt_list.clear_options()
        f = filter_text.strip().lower()
        self.filtered = [k for k in self.all_keymaps if f in k.lower()] if f else self.all_keymaps[:100]

        default_idx = 0
        for i, k in enumerate(self.filtered):
            if k == self.config.keyboard_layout:
                default_idx = i
            opt_list.add_option(Option(f"  {k}", id=k))

        if self.filtered:
            opt_list.highlighted = default_idx

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "input-search-kb":
            self.update_options(event.value)

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        if event.option_id:
            self.select_layout(event.option_id)

    def on_option_list_option_highlighted(self, event: OptionList.OptionHighlighted) -> None:
        if event.option_id:
            self.select_layout(event.option_id)

    def select_layout(self, layout: str) -> None:
        self.config.keyboard_layout = layout
        # Apply immediately to live session
        if shutil.which("localectl"):
            subprocess.run(["localectl", "set-keymap", layout], check=False)
        self.on_change()
