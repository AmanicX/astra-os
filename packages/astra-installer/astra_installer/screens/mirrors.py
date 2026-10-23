"""
Screen 5: Mirror Regions & Package Sources.
Allows selecting mirror countries with background speed ranking.
"""

from __future__ import annotations

import json
from typing import Callable, List, Set

from textual.app import ComposeResult
from textual.containers import Container
from textual.widgets import Input, Label, OptionList
from textual.widgets.option_list import Option

from astra_installer.models import AstraConfig

DEFAULT_REGIONS = [
    "Worldwide", "United States", "Germany", "United Kingdom", "France",
    "Canada", "Australia", "Japan", "Singapore", "India", "Netherlands",
    "Sweden", "Brazil", "South Korea"
]


class MirrorsScreenWidget(Container):
    """Screen 05: Mirror Region Selection."""

    def __init__(self, config: AstraConfig, on_change: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_change = on_change
        self.all_regions = DEFAULT_REGIONS[:]
        self.selected_regions: Set[str] = set(self.config.mirror_regions or ["Worldwide"])

    def compose(self) -> ComposeResult:
        yield Label("Package Mirror Region", classes="screen-title")
        yield Label("Select mirror countries closest to you for fast package downloads. Press Enter to toggle selection.", classes="screen-desc")

        yield Input(placeholder="Type to filter country (e.g. United States, Germany)...", id="input-search-mirrors")
        yield OptionList(id="list-mirrors")

    def on_mount(self) -> None:
        self.update_options()

    def update_options(self, filter_text: str = "") -> None:
        opt_list = self.query_one("#list-mirrors", OptionList)
        opt_list.clear_options()
        f = filter_text.strip().lower()
        filtered = [r for r in self.all_regions if f in r.lower()] if f else self.all_regions

        for r in filtered:
            checked = "✓ " if r in self.selected_regions else "○ "
            opt_list.add_option(Option(f"{checked}{r}", id=r))

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "input-search-mirrors":
            self.update_options(event.value)

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        if event.option_id:
            reg = event.option_id
            if reg in self.selected_regions:
                if len(self.selected_regions) > 1:
                    self.selected_regions.remove(reg)
            else:
                self.selected_regions.add(reg)
            self.config.mirror_regions = sorted(list(self.selected_regions))
            self.update_options()
            self.on_change()
