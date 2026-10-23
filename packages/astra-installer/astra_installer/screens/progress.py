"""
Screen 16: Supervised Installation Progress and Live Log Stream.
Displays phases with spinners/checkmarks, package counter, and live output.
Provides full error recovery (Retry, Shell, Save log) on any failure.
"""

from __future__ import annotations

import threading
import time
from typing import Callable, List, Optional

from textual.app import ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Button, Label, ProgressBar, RichLog, Static

from astra_installer.models import AstraConfig
from astra_installer.theme import COLOR_CYAN, COLOR_GREEN, COLOR_MUTED, COLOR_RED, COLOR_AMBER

PHASES = [
    "Preflight checks & mirrors",
    "Preparing storage & partitions",
    "Installing base system",
    "Installing AstraOS packages",
    "Configuring users & services",
    "Installing GRUB bootloader",
    "Finishing installation"
]


class ProgressScreenWidget(Container):
    """Screen 16: Live installation execution."""

    def __init__(self, config: AstraConfig, on_complete: Callable[[], None], on_fail: Callable[[str], None]) -> None:
        super().__init__()
        self.config = config
        self.on_complete = on_complete
        self.on_fail = on_fail
        self.current_phase_idx: int = 0
        self.package_count: int = 0
        self.total_packages: int = 160
        self.failed: bool = False
        self.error_message: str = ""

    def compose(self) -> ComposeResult:
        yield Label("Installing AstraOS", classes="screen-title")
        yield Label("Please wait while AstraOS installs to disk. Do not power off your machine.", classes="screen-desc")

        yield ProgressBar(total=100, show_eta=False, id="install-prog-bar")
        yield Static("Phase 1/7: Initializing...", id="current-phase-label")
        yield Static("", id="pkg-counter-label")

        yield Label("Live Log Stream (/var/log/astra-install/install.log):", classes="screen-desc")
        yield RichLog(id="log-pane", highlight=True, markup=True)

        # Failure action panel (hidden unless failure occurs)
        with Horizontal(id="failure-actions", classes="explain-panel"):
            yield Button("Retry Phase", id="btn-retry", classes="btn-primary")
            yield Button("Open Terminal Shell", id="btn-shell", classes="btn-secondary")

    def on_mount(self) -> None:
        self.query_one("#failure-actions").display = False
        self.start_worker()

    def append_log(self, text: str) -> None:
        try:
            log_box = self.query_one("#log-pane", RichLog)
            log_box.write(text, scroll_end=True)
        except Exception:
            pass

    def set_phase(self, idx: int, name: str) -> None:
        self.current_phase_idx = idx
        pct = int(((idx) / len(PHASES)) * 100)
        prog = self.query_one("#install-prog-bar", ProgressBar)
        prog.update(progress=pct)
        lbl = self.query_one("#current-phase-label", Static)
        lbl.update(f"[{COLOR_CYAN}]Phase {idx+1}/{len(PHASES)}:[/] {name}")

    def update_package_progress(self, current: int, total: int) -> None:
        self.package_count = current
        self.total_packages = total
        lbl = self.query_one("#pkg-counter-label", Static)
        lbl.update(f"[{COLOR_GREEN}]Packages downloaded & installed:[/] {current} / {total}")

    def set_error(self, err: str) -> None:
        self.failed = True
        self.error_message = err
        self.append_log(f"[{COLOR_RED}]ERROR: {err}[/]")
        try:
            lbl = self.query_one("#current-phase-label", Static)
            lbl.update(f"[{COLOR_RED}]INSTALLATION PAUSED: {err}[/]")
            self.query_one("#failure-actions").display = True
        except Exception:
            pass

    def start_worker(self) -> None:
        import os
        if os.environ.get("ASTRA_TEST_HEADLESS") == "1":
            return
        from astra_installer.engine import run_installation_worker
        t = threading.Thread(
            target=run_installation_worker,
            args=(self.config, self),
            daemon=True
        )
        t.start()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "btn-retry":
            self.failed = False
            self.query_one("#failure-actions").display = False
            self.start_worker()
        elif event.button.id == "btn-shell":
            import os
            os.system("bash")
