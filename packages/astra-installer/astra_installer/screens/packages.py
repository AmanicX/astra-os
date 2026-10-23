"""
Screen 14: Additional Software, Web Browser & AUR Helper.
Lists default pre-configured stack, provides browser and AUR helper selectors,
and allows adding custom packages.
"""

from __future__ import annotations

from typing import Callable

from textual.app import ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Input, Label, RadioButton, RadioSet, Static

from astra_installer.models import AstraConfig, BrowserChoice, AurHelperChoice
from astra_installer.theme import COLOR_CYAN, COLOR_MUTED


class PackagesScreenWidget(Container):
    """Screen 14: Software selection."""

    def __init__(self, config: AstraConfig, on_change: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_change = on_change

    def compose(self) -> ComposeResult:
        yield Label("Software Selection & Packages", classes="screen-title")
        yield Label("Customize application preferences and add extra software.", classes="screen-desc")

        with Vertical(classes="explain-panel"):
            yield Static(f"[bold {COLOR_CYAN}]Already Included in AstraOS Default Stack:[/]")
            yield Static("• Desktop: Niri compositor, Noctalia shell, SilentSDDM display manager\n"
                         "• Apps: Kitty terminal, Nautilus Files, Loupe image viewer, Steam, btop, fastfetch\n"
                         "• Tools: Zsh + Oh My Posh, Pre-baked LazyVim IDE, PipeWire audio stack, Bluetooth, NetworkManager")

        yield Label("Web Browser:", classes="screen-desc")
        with RadioSet(id="radio-browser"):
            yield RadioButton("Firefox (Default AstraOS browser)", value=(self.config.browser == BrowserChoice.FIREFOX), id="opt-firefox")
            yield RadioButton("Chromium open-source browser", value=(self.config.browser == BrowserChoice.CHROMIUM), id="opt-chromium")
            yield RadioButton("Brave privacy browser", value=(self.config.browser == BrowserChoice.BRAVE), id="opt-brave")
            yield RadioButton("None (I will install a browser later)", value=(self.config.browser == BrowserChoice.NONE), id="opt-browser-none")

        yield Label("AUR Helper Tool:", classes="screen-desc")
        with RadioSet(id="radio-aur"):
            yield RadioButton("paru (Rust-based pacman wrapper) — Default", value=(self.config.aur_helper == AurHelperChoice.PARU), id="opt-paru")
            yield RadioButton("yay (Go-based pacman wrapper)", value=(self.config.aur_helper == AurHelperChoice.YAY), id="opt-yay")
            yield RadioButton("None", value=(self.config.aur_helper == AurHelperChoice.NONE), id="opt-aur-none")

        yield Label("Additional Packages (Comma or space separated):", classes="screen-desc")
        yield Input(
            value=", ".join(self.config.additional_packages),
            placeholder="e.g. vlc, git, htop, docker...",
            id="input-extra-pkgs"
        )

    def on_radio_set_changed(self, event: RadioSet.Changed) -> None:
        bid = event.pressed.id
        if bid == "opt-firefox":
            self.config.browser = BrowserChoice.FIREFOX
        elif bid == "opt-chromium":
            self.config.browser = BrowserChoice.CHROMIUM
        elif bid == "opt-brave":
            self.config.browser = BrowserChoice.BRAVE
        elif bid == "opt-browser-none":
            self.config.browser = BrowserChoice.NONE

        if bid == "opt-paru":
            self.config.aur_helper = AurHelperChoice.PARU
        elif bid == "opt-yay":
            self.config.aur_helper = AurHelperChoice.YAY
        elif bid == "opt-aur-none":
            self.config.aur_helper = AurHelperChoice.NONE

        self.on_change()

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "input-extra-pkgs":
            raw = event.value.replace(",", " ").split()
            self.config.additional_packages = [p.strip() for p in raw if p.strip()]
            self.on_change()
