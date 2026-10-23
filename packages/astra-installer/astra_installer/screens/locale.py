"""
Screen 3: System Locale.
Searchable list of UTF-8 locales from /usr/share/i18n/SUPPORTED.
Default: en_US.UTF-8.
"""

from __future__ import annotations

from pathlib import Path
from typing import Callable, List

from textual.app import ComposeResult
from textual.containers import Container
from textual.widgets import Input, Label, OptionList
from textual.widgets.option_list import Option

from astra_installer.models import AstraConfig


def list_supported_locales() -> List[str]:
    """Parse /usr/share/i18n/SUPPORTED for UTF-8 locales."""
    supported_file = Path("/usr/share/i18n/SUPPORTED")
    locales: List[str] = []
    if supported_file.exists():
        try:
            with open(supported_file, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#"):
                        parts = line.split()
                        if len(parts) >= 2 and "UTF-8" in parts[1].upper():
                            locales.append(parts[0])
        except Exception:
            pass

    if not locales:
        locales = [
            "en_US.UTF-8", "en_GB.UTF-8", "de_DE.UTF-8", "fr_FR.UTF-8",
            "es_ES.UTF-8", "it_IT.UTF-8", "pt_BR.UTF-8", "ru_RU.UTF-8",
            "ja_JP.UTF-8", "zh_CN.UTF-8", "pl_PL.UTF-8", "nl_NL.UTF-8", "C.UTF-8"
        ]
    return sorted(list(set(locales)))


class LocaleScreenWidget(Container):
    """Screen 03: Locale selection."""

    def __init__(self, config: AstraConfig, on_change: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_change = on_change
        self.all_locales = list_supported_locales()
        self.filtered = self.all_locales[:]

    def compose(self) -> ComposeResult:
        yield Label("System Language & Locale", classes="screen-title")
        yield Label("Select your primary system language and character encoding (UTF-8).", classes="screen-desc")

        yield Input(placeholder="Type to search locale (e.g. en_US, de_DE, ja_JP)...", id="input-search-locale")
        yield OptionList(id="list-locales")

    def on_mount(self) -> None:
        self.update_options()

    def update_options(self, filter_text: str = "") -> None:
        opt_list = self.query_one("#list-locales", OptionList)
        opt_list.clear_options()
        f = filter_text.strip().lower()
        self.filtered = [l for l in self.all_locales if f in l.lower()] if f else self.all_locales[:120]

        default_idx = 0
        for i, loc in enumerate(self.filtered):
            if loc == self.config.locale:
                default_idx = i
            opt_list.add_option(Option(f"  {loc}", id=loc))

        if self.filtered:
            opt_list.highlighted = default_idx

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "input-search-locale":
            self.update_options(event.value)

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        if event.option_id:
            self.config.locale = event.option_id
            self.on_change()

    def on_option_list_option_highlighted(self, event: OptionList.OptionHighlighted) -> None:
        if event.option_id:
            self.config.locale = event.option_id
            self.on_change()
