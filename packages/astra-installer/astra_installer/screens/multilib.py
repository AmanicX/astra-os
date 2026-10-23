"""
Screen 6: Multilib & Repository Optimization.
Informational screen displaying automatic multilib, parallel downloads, and color output.
"""

from __future__ import annotations

from typing import Callable

from textual.app import ComposeResult
from textual.containers import Container, Vertical
from textual.widgets import Label, Static

from astra_installer.models import AstraConfig
from astra_installer.theme import COLOR_CYAN, COLOR_GREEN, COLOR_MUTED


class MultilibScreenWidget(Container):
    """Screen 06: Multilib and repository options."""

    def __init__(self, config: AstraConfig, on_change: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_change = on_change
        # Multilib, Color, Parallel downloads are permanently enabled
        self.config.multilib_enabled = True
        self.config.parallel_downloads = 5
        self.config.color_output = True

    def compose(self) -> ComposeResult:
        yield Label("Software Repositories & Multilib", classes="screen-title")
        yield Label("AstraOS automatically configures official package channels with high-performance defaults.", classes="screen-desc")

        with Vertical(classes="explain-panel"):
            yield Static(f"[{COLOR_GREEN}]✓ Active Repositories:[/] core, extra, [bold {COLOR_CYAN}]multilib (enabled automatically)[/]")
            yield Static(f"[{COLOR_MUTED}]  Required for 32-bit graphics runtime, Steam, Wine, and legacy compatibility.[/]")

            yield Static(f"[{COLOR_GREEN}]✓ Parallel Downloads:[/] 5 concurrent threads enabled")
            yield Static(f"[{COLOR_MUTED}]  Downloads multiple package files simultaneously to maximize bandwidth.[/]")

            yield Static(f"[{COLOR_GREEN}]✓ Terminal Colors:[/] Colorized pacman output enabled")
            yield Static(f"[{COLOR_MUTED}]  Provides clear visual status during updates and installations.[/]")

        with Vertical(classes="explain-panel"):
            yield Static(f"[bold {COLOR_CYAN}]Repository Integrity & Security[/]")
            yield Static("Only official Arch Linux repositories and the signed AstraOS overlay are included. Testing, unstable, or untrusted repositories are strictly excluded from v1.")
