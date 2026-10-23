"""
Screen 7: Swap Space Configuration.
Choices: zram (compressed RAM, recommended), swap partition (custom GiB), or no swap.
"""

from __future__ import annotations

from typing import Callable

from textual.app import ComposeResult
from textual.containers import Container, Vertical
from textual.widgets import Input, Label, RadioButton, RadioSet, Static

from astra_installer.models import AstraConfig, SwapMode
from astra_installer.theme import COLOR_CYAN, COLOR_MUTED


class SwapScreenWidget(Container):
    """Screen 07: Swap memory options."""

    def __init__(self, config: AstraConfig, on_change: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_change = on_change

    def compose(self) -> ComposeResult:
        yield Label("Swap & Memory Management", classes="screen-title")
        yield Label("Choose how AstraOS should handle virtual memory and background paging.", classes="screen-desc")

        with RadioSet(id="radio-swap"):
            yield RadioButton(
                "zram (Compressed RAM swap) — Recommended default",
                value=(self.config.swap_mode == SwapMode.ZRAM),
                id="opt-zram"
            )
            yield RadioButton(
                "Swap Partition — Dedicated disk partition (supports hibernation)",
                value=(self.config.swap_mode == SwapMode.PARTITION),
                id="opt-partition"
            )
            yield RadioButton(
                "No Swap — Do not configure swap",
                value=(self.config.swap_mode == SwapMode.NONE),
                id="opt-none"
            )

        with Vertical(id="swap-size-container", classes="explain-panel"):
            yield Label("Swap partition size in GiB (e.g. 4, 8, 16):", classes="screen-desc")
            yield Input(
                value=str(self.config.swap_size_gib),
                placeholder="Size in GiB...",
                id="input-swap-size"
            )

        with Vertical(classes="explain-panel"):
            yield Static(f"[bold {COLOR_CYAN}]What this does[/]")
            yield Static("• [bold]zram[/]: Creates an in-RAM compressed block device (fastest, reduces SSD wear, but does not support suspend-to-disk hibernation).\n"
                         "• [bold]Swap Partition[/]: Formats a real partition on disk. Suggest RAM size (4–8 GiB) if you plan to use hibernation.")

    def on_mount(self) -> None:
        self.update_visibility()

    def update_visibility(self) -> None:
        size_box = self.query_one("#swap-size-container")
        size_box.display = (self.config.swap_mode == SwapMode.PARTITION)

    def on_radio_set_changed(self, event: RadioSet.Changed) -> None:
        if event.pressed.id == "opt-zram":
            self.config.swap_mode = SwapMode.ZRAM
        elif event.pressed.id == "opt-partition":
            self.config.swap_mode = SwapMode.PARTITION
        elif event.pressed.id == "opt-none":
            self.config.swap_mode = SwapMode.NONE

        self.update_visibility()
        self.on_change()

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "input-swap-size":
            try:
                val = int(event.value.strip())
                if 1 <= val <= 128:
                    self.config.swap_size_gib = val
                    self.on_change()
            except ValueError:
                pass
