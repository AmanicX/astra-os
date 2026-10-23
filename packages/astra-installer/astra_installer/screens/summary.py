"""
Screen 15: Installation Summary & Destructive Action Gate.
Requires typing the target disk or partition name before unlocking the Install button.
"""

from __future__ import annotations

from typing import Callable

from textual.app import ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Button, Input, Label, Static

from astra_installer.models import AstraConfig, StorageMode
from astra_installer.theme import COLOR_AMBER, COLOR_CYAN, COLOR_GREEN, COLOR_RED


class SummaryScreenWidget(Container):
    """Screen 15: Review choices and confirm destructive actions."""

    def __init__(self, config: AstraConfig, on_jump_step: Callable[[int], None], on_change: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_jump_step = on_jump_step
        self.on_change = on_change
        self.typed_confirm: str = ""

    def compose(self) -> ComposeResult:
        yield Label("Installation Summary & Review", classes="screen-title")
        yield Label("Review your configuration carefully. Verify storage changes before proceeding.", classes="screen-desc")

        with Vertical(classes="explain-panel"):
            yield Static(f"[bold {COLOR_CYAN}]System Configuration[/]")
            yield Static(f"• Hostname: [bold]{self.config.hostname}[/] | Locale: [bold]{self.config.locale}[/] | Timezone: [bold]{self.config.timezone}[/]")
            yield Static(f"• User Account: [bold]{self.config.username}[/] ({'Administrator with sudo' if self.config.sudo_mode.value == 'with_password' else 'Standard user'})")
            yield Static(f"• Swap: [bold]{self.config.swap_mode.value.upper()}[/] | OS-Prober: [bold]{'Enabled' if self.config.os_prober else 'Disabled'}[/]")
            yield Static(f"• Browser: [bold]{self.config.browser.value}[/] | AUR Helper: [bold]{self.config.aur_helper.value}[/]")

        # Storage summary
        plan = self.config.storage_plan
        with Vertical(classes="danger-panel" if plan.mode == StorageMode.ERASE else "explain-panel"):
            yield Static(f"[bold {COLOR_RED if plan.mode == StorageMode.ERASE else COLOR_GREEN}]Storage Plan Target: {plan.disk_path}[/]")
            if plan.mode == StorageMode.ERASE:
                yield Static(f"[{COLOR_RED}]⚠ ENTIRE DISK WILL BE ERASED AND RE-PARTITIONED[/]")
                yield Static("  • All existing partitions and data on this disk will be permanently destroyed.\n"
                             "  • A new GPT table, 1 GiB ESP, and Btrfs root filesystem will be created.")
            elif plan.mode == StorageMode.FREE_SPACE:
                yield Static(f"[{COLOR_GREEN}]✓ DUAL-BOOT SAFE: Existing partitions will be kept untouched.[/]")
            else:
                yield Static(f"[{COLOR_CYAN}]Pre-mounted mode: Using {plan.premounted_root}.[/]")

        # Confirmation gate
        req_token = plan.disk_path if plan.mode == StorageMode.ERASE else "CONFIRM"
        with Vertical():
            yield Label(f"To authorize installation, type exactly '{req_token}' below:", classes="screen-desc")
            yield Input(placeholder=f"Type '{req_token}' here...", id="input-confirm-gate")
            yield Static("", id="confirm-status-msg")

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "input-confirm-gate":
            self.typed_confirm = event.value.strip()
            self.validate_confirmation()

    def validate_confirmation(self) -> None:
        plan = self.config.storage_plan
        req_token = plan.disk_path if plan.mode == StorageMode.ERASE else "CONFIRM"
        msg = self.query_one("#confirm-status-msg", Static)

        if self.typed_confirm == req_token:
            plan.confirmed_token = self.typed_confirm
            msg.update(f"[{COLOR_GREEN}]✓ Confirmation verified. Ready to proceed with installation.[/]")
        else:
            plan.confirmed_token = None
            msg.update(f"[{COLOR_AMBER}]Waiting for exact match '{req_token}'...[/]")

        self.on_change()
