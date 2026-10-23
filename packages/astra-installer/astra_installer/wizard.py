"""
AstraOS Textual Wizard Controller.
Implements the 17-screen sequential Next/Back wizard with full step stack.
"""

from __future__ import annotations

import sys
from typing import List, Optional

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal, Vertical
from textual.screen import Screen
from textual.widgets import Button, Footer, Header, Label, ProgressBar, Static

from astra_installer.models import AstraConfig, StorageMode
from astra_installer.screens import (
    SCREEN_NAMES,
    WelcomeScreenWidget,
    KeyboardScreenWidget,
    LocaleScreenWidget,
    TimezoneScreenWidget,
    MirrorsScreenWidget,
    MultilibScreenWidget,
    SwapScreenWidget,
    HostnameScreenWidget,
    RootPasswordScreenWidget,
    UserAccountScreenWidget,
    SudoScreenWidget,
    StorageScreenWidget,
    BootloaderScreenWidget,
    PackagesScreenWidget,
    SummaryScreenWidget,
    ProgressScreenWidget,
    FinishedScreenWidget,
)
from astra_installer.theme import (
    APP_CSS,
    ASTRA_BANNER,
    COLOR_CYAN,
    COLOR_GREEN,
    COLOR_MUTED,
)


class WizardMainScreen(Screen):
    """The unified wizard shell with header, rail, dynamic main pane, and controls."""

    BINDINGS = [
        Binding("enter", "next_step", "Next", priority=True),
        Binding("escape", "back_step", "Back", priority=True),
        Binding("f1", "help", "Help"),
    ]

    def __init__(self, config: AstraConfig) -> None:
        super().__init__()
        self.config = config
        self.step: int = 1
        self.step_stack: List[int] = [1]
        self.max_step_reached: int = 1

    def compose(self) -> ComposeResult:
        with Container(id="app-container"):
            # Header
            with Horizontal(id="app-header"):
                yield Static(ASTRA_BANNER, id="header-logo")
                yield Static(" • Terminal Installer", id="header-title")
                yield Static("Step 1 of 17", id="header-step")

            # Center content: Left Rail + Main Pane
            with Horizontal(id="content-box"):
                with Vertical(id="rail-container"):
                    with Vertical(id="rail-scroll"):
                        for i, name in enumerate(SCREEN_NAMES, 1):
                            yield Static(f"○ {i:02d} {name}", id=f"rail-step-{i}", classes="rail-item rail-item-upcoming")

                with Vertical(id="main-pane"):
                    yield Static("Loading...", id="pane-content-placeholder")

            # Navigation buttons
            with Horizontal(id="nav-buttons-bar"):
                yield Button("← Back (Esc)", id="btn-back", classes="btn-secondary")
                yield Static("", id="nav-spacer", classes="spacer")
                yield Button("Next (Enter) →", id="btn-next", classes="btn-primary")

            # Footer
            yield Static("Enter: Next  •  Esc: Back  •  Mouse Supported", id="footer-hints")

    def on_mount(self) -> None:
        self.show_step(1)

    def update_rail(self) -> None:
        """Update step rail icons and active highlight."""
        for i, name in enumerate(SCREEN_NAMES, 1):
            try:
                lbl = self.query_one(f"#rail-step-{i}", Static)
                if i < self.step:
                    lbl.update(f"✓ {i:02d} {name}")
                    lbl.remove_class("rail-item-upcoming", "rail-item-current")
                    lbl.add_class("rail-item-completed")
                elif i == self.step:
                    lbl.update(f"● {i:02d} {name}")
                    lbl.remove_class("rail-item-upcoming", "rail-item-completed")
                    lbl.add_class("rail-item-current")
                else:
                    lbl.update(f"○ {i:02d} {name}")
                    lbl.remove_class("rail-item-current", "rail-item-completed")
                    lbl.add_class("rail-item-upcoming")
            except Exception:
                pass

        step_lbl = self.query_one("#header-step", Static)
        step_lbl.update(f"Step {self.step} of 17")

    def can_advance(self) -> bool:
        """Enforce validation rules before allowing Next."""
        if self.step == 1:
            return self.config.network_ok and self.config.uefi_ok
        elif self.step == 8:
            ok, _ = AstraConfig.validate_hostname(self.config.hostname)
            return ok
        elif self.step == 9:
            return bool(self.config.root_password)
        elif self.step == 10:
            ok_name, _ = AstraConfig.validate_username(self.config.username)
            return ok_name and bool(self.config.user_password)
        elif self.step == 12:
            return self.config.storage_plan.valid
        elif self.step == 15:
            # Summary screen requires exact typed confirmation token
            plan = self.config.storage_plan
            req = plan.disk_path if plan.mode == StorageMode.ERASE else "CONFIRM"
            return plan.confirmed_token == req
        elif self.step == 16:
            # Cannot advance manually while install is progressing
            return False
        return True

    def on_state_changed(self) -> None:
        """Called by child widgets when user changes an input or selection."""
        btn_next = self.query_one("#btn-next", Button)
        btn_next.disabled = not self.can_advance()

    def show_step(self, step: int) -> None:
        self.step = step
        self.max_step_reached = max(self.max_step_reached, step)
        self.update_rail()

        main_pane = self.query_one("#main-pane", Vertical)
        main_pane.remove_children()

        widget = None
        if step == 1:
            widget = WelcomeScreenWidget(self.config, self.on_state_changed)
        elif step == 2:
            widget = KeyboardScreenWidget(self.config, self.on_state_changed)
        elif step == 3:
            widget = LocaleScreenWidget(self.config, self.on_state_changed)
        elif step == 4:
            widget = TimezoneScreenWidget(self.config, self.on_state_changed)
        elif step == 5:
            widget = MirrorsScreenWidget(self.config, self.on_state_changed)
        elif step == 6:
            widget = MultilibScreenWidget(self.config, self.on_state_changed)
        elif step == 7:
            widget = SwapScreenWidget(self.config, self.on_state_changed)
        elif step == 8:
            widget = HostnameScreenWidget(self.config, self.on_state_changed)
        elif step == 9:
            widget = RootPasswordScreenWidget(self.config, self.on_state_changed)
        elif step == 10:
            widget = UserAccountScreenWidget(self.config, self.on_state_changed)
        elif step == 11:
            widget = SudoScreenWidget(self.config, self.on_state_changed)
        elif step == 12:
            widget = StorageScreenWidget(self.config, self.on_state_changed)
        elif step == 13:
            widget = BootloaderScreenWidget(self.config, self.on_state_changed)
        elif step == 14:
            widget = PackagesScreenWidget(self.config, self.on_state_changed)
        elif step == 15:
            widget = SummaryScreenWidget(self.config, self.jump_to_step, self.on_state_changed)
        elif step == 16:
            widget = ProgressScreenWidget(self.config, self.on_install_completed, self.on_install_failed)
        elif step == 17:
            widget = FinishedScreenWidget(self.config, self.app.exit)

        if widget:
            main_pane.mount(widget)

        # Update button states
        btn_back = self.query_one("#btn-back", Button)
        btn_next = self.query_one("#btn-next", Button)

        btn_back.disabled = (step == 1 or step == 16 or step == 17)
        btn_next.display = (step < 16)
        if step == 15:
            btn_next.label = "Install AstraOS →"
            btn_next.remove_class("btn-primary")
            btn_next.add_class("btn-danger")
        else:
            btn_next.label = "Next (Enter) →"
            btn_next.remove_class("btn-danger")
            btn_next.add_class("btn-primary")

        btn_next.disabled = not self.can_advance()

    def action_next_step(self) -> None:
        if self.can_advance():
            if self.step < 17:
                next_st = self.step + 1
                self.step_stack.append(next_st)
                self.show_step(next_st)

    def action_back_step(self) -> None:
        if self.step > 1 and self.step not in (16, 17):
            if len(self.step_stack) > 1:
                self.step_stack.pop()
                prev_st = self.step_stack[-1]
            else:
                prev_st = self.step - 1
            self.show_step(prev_st)

    def jump_to_step(self, step: int) -> None:
        self.step_stack.append(step)
        self.show_step(step)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "btn-next":
            self.action_next_step()
        elif event.button.id == "btn-back":
            self.action_back_step()

    def on_install_completed(self) -> None:
        self.step_stack.append(17)
        self.show_step(17)

    def on_install_failed(self, error: str) -> None:
        pass


class AstraInstallerApp(App[None]):
    """Main Textual Application for AstraOS Installer."""

    CSS = APP_CSS
    TITLE = "AstraOS Installer"

    def __init__(self, config: Optional[AstraConfig] = None) -> None:
        super().__init__()
        self.config = config or AstraConfig()

    def get_default_screen(self) -> Screen:
        return WizardMainScreen(self.config)
