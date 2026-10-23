"""
Screen 4: Timezone Selection.
Searchable Region/City list with NTP time synchronization kept on.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path
from typing import Callable, List

from textual.app import ComposeResult
from textual.containers import Container
from textual.widgets import Input, Label, OptionList
from textual.widgets.option_list import Option

from astra_installer.models import AstraConfig


def list_timezones() -> List[str]:
    """Retrieve list of valid IANA timezones."""
    if shutil.which("timedatectl"):
        try:
            res = subprocess.run(["timedatectl", "list-timezones"], stdout=subprocess.PIPE, text=True, check=False)
            if res.returncode == 0:
                zones = [z.strip() for z in res.stdout.splitlines() if z.strip()]
                if zones:
                    return zones
        except Exception:
            pass

    zone_tab = Path("/usr/share/zoneinfo/zone.tab")
    if zone_tab.exists():
        try:
            zones = []
            with open(zone_tab) as f:
                for line in f:
                    if not line.startswith("#") and line.strip():
                        parts = line.split()
                        if len(parts) >= 3:
                            zones.append(parts[2])
            if zones:
                return sorted(list(set(zones)))
        except Exception:
            pass

    return [
        "UTC", "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles",
        "Europe/London", "Europe/Berlin", "Europe/Paris", "Asia/Tokyo", "Asia/Shanghai",
        "Asia/Kolkata", "Australia/Sydney"
    ]


class TimezoneScreenWidget(Container):
    """Screen 04: Timezone selection."""

    def __init__(self, config: AstraConfig, on_change: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_change = on_change
        self.all_timezones = list_timezones()
        self.filtered = self.all_timezones[:]

    def compose(self) -> ComposeResult:
        yield Label("Timezone & Clock", classes="screen-title")
        yield Label("Select your local timezone. Network Time Protocol (NTP) stays enabled automatically.", classes="screen-desc")

        yield Input(placeholder="Type to filter timezone (e.g. America, Europe, Asia)...", id="input-search-tz")
        yield OptionList(id="list-timezones")

    def on_mount(self) -> None:
        self.update_options()

    def update_options(self, filter_text: str = "") -> None:
        opt_list = self.query_one("#list-timezones", OptionList)
        opt_list.clear_options()
        f = filter_text.strip().lower()
        self.filtered = [z for z in self.all_timezones if f in z.lower()] if f else self.all_timezones[:120]

        default_idx = 0
        for i, tz in enumerate(self.filtered):
            if tz == self.config.timezone:
                default_idx = i
            opt_list.add_option(Option(f"  {tz}", id=tz))

        if self.filtered:
            opt_list.highlighted = default_idx

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "input-search-tz":
            self.update_options(event.value)

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        if event.option_id:
            self.config.timezone = event.option_id
            self.on_change()

    def on_option_list_option_highlighted(self, event: OptionList.OptionHighlighted) -> None:
        if event.option_id:
            self.config.timezone = event.option_id
            self.on_change()
