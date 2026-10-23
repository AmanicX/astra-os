"""
Screen 12: Storage & Partitioning Planner.
Options:
  1) Erase Entire Disk (Clean GPT, 1G FAT32 ESP + Btrfs root)
  2) Use Free Space (Dual-boot safe, keeps existing partitions bit-identical)
  3) Manual / Pre-mounted (/mnt custom mounts)
Displays dynamic before/after layout preview bar.
"""

from __future__ import annotations

from typing import Callable, List, Optional

from textual.app import ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Button, Input, Label, OptionList, RadioButton, RadioSet, Static
from textual.widgets.option_list import Option

from astra_installer.models import AstraConfig, StorageMode, StoragePlan
from astra_installer.storage_guard import (
    DiskMeta,
    build_erase_plan,
    discover_disks,
    MIN_STORAGE_BYTES,
)
from astra_installer.theme import COLOR_CYAN, COLOR_GREEN, COLOR_MUTED, COLOR_RED, COLOR_AMBER


def render_layout_bar(disk: DiskMeta, plan: Optional[StoragePlan] = None) -> str:
    """Render a visual ascii block layout bar representing disk partitions."""
    if not disk.partitions:
        return "[#4f6170] [ Empty / Unpartitioned Disk ] [/]"

    blocks = []
    total_sz = disk.size_bytes or 1
    for p in disk.partitions:
        pct = max(2, int((p.size_bytes / total_sz) * 40))
        label = p.name
        if plan and plan.mode == StorageMode.ERASE:
            # All existing partitions will be erased
            blocks.append(f"[{COLOR_RED} on #3a1518]{'█'*pct} {label} (Erase)[/]")
        else:
            # Preserved partition
            blocks.append(f"[{COLOR_GREEN} on #10261b]{'█'*pct} {label}[/]")

    return " ".join(blocks)


class StorageScreenWidget(Container):
    """Screen 12: Storage configuration and projected layout."""

    def __init__(self, config: AstraConfig, on_change: Callable[[], None]) -> None:
        super().__init__()
        self.config = config
        self.on_change = on_change
        self.disks = [d for d in discover_disks() if not d.is_live]
        self.selected_disk: Optional[DiskMeta] = self.disks[0] if self.disks else None
        self.mode = StorageMode.ERASE

    def compose(self) -> ComposeResult:
        yield Label("Storage & Partitioning", classes="screen-title")
        yield Label("Choose how AstraOS prepares your storage. No disk is touched until final summary confirmation.", classes="screen-desc")

        with RadioSet(id="radio-storage-mode"):
            yield RadioButton(
                "Erase entire disk — Recommended for dedicated installations (Creates clean GPT layout)",
                value=True,
                id="opt-storage-erase"
            )
            yield RadioButton(
                "Use free unpartitioned space — Dual-boot safe (Preserves other operating systems)",
                value=False,
                id="opt-storage-free"
            )
            yield RadioButton(
                "Manual / Pre-mounted filesystem — Advanced (Use existing custom /mnt mounts)",
                value=False,
                id="opt-storage-manual"
            )

        # Disk picker
        with Vertical(id="disk-select-container"):
            yield Label("Target Disk:", classes="screen-desc")
            yield OptionList(id="list-disks")

        # Partition layout bar preview
        with Vertical(classes="explain-panel", id="preview-panel"):
            yield Label("Projected Layout Preview:", classes="screen-desc")
            yield Static("", id="layout-bar-preview")
            yield Static("", id="storage-plan-summary")

        # Manual mountpoint input (hidden unless manual mode chosen)
        with Vertical(id="manual-mount-container"):
            yield Label("Pre-mounted root path (default /mnt):", classes="screen-desc")
            yield Input(value="/mnt", id="input-premount")

    def on_mount(self) -> None:
        self.update_disk_list()
        self.update_plan()

    def update_disk_list(self) -> None:
        opt_list = self.query_one("#list-disks", OptionList)
        opt_list.clear_options()

        if not self.disks:
            opt_list.add_option(Option("  No usable disks detected", id="none"))
            return

        for d in self.disks:
            sz_gib = d.size_bytes // (1024**3)
            info = f"  {d.node} ({sz_gib} GiB) — {d.model or 'Generic Drive'} [{d.pttype.upper() or 'No table'}]"
            opt_list.add_option(Option(info, id=d.node))

        opt_list.highlighted = 0

    def update_plan(self) -> None:
        if not self.selected_disk:
            return

        preview = self.query_one("#layout-bar-preview", Static)
        summary = self.query_one("#storage-plan-summary", Static)
        manual_box = self.query_one("#manual-mount-container")
        manual_box.display = (self.mode == StorageMode.PRE_MOUNTED or self.mode == StorageMode.MANUAL)

        if self.mode == StorageMode.ERASE:
            plan = build_erase_plan(self.selected_disk, self.config.swap_mode, self.config.swap_size_gib)
            self.config.storage_plan = plan
            preview.update(render_layout_bar(self.selected_disk, plan))

            if plan.valid:
                summary.update(
                    f"[{COLOR_CYAN}]Plan: New GPT layout on {self.selected_disk.node}[/]\n"
                    f"• {plan.esp_device}: 1 GiB FAT32 EFI System Partition (/boot/efi)\n"
                    f"• {plan.root_device}: Btrfs subvolumes @, @home, @log, @pkg, @snapshots (/)\n"
                    f"• Note: Whole-disk wipe requires typing '{self.selected_disk.node}' on summary screen."
                )
            else:
                summary.update(f"[{COLOR_RED}]Error: {plan.validation_error}[/]")

        elif self.mode == StorageMode.FREE_SPACE:
            plan = StoragePlan(
                mode=StorageMode.FREE_SPACE,
                disk_path=self.selected_disk.node,
                disk_model=self.selected_disk.model,
                disk_size_bytes=self.selected_disk.size_bytes,
                valid=True
            )
            self.config.storage_plan = plan
            preview.update(render_layout_bar(self.selected_disk, plan))
            summary.update(
                f"[{COLOR_GREEN}]Dual-Boot Protection Active[/]\n"
                f"• Existing partitions on {self.selected_disk.node} will be [bold]strictly preserved[/].\n"
                f"• A new 1 GiB ESP and Btrfs root will be created only inside contiguous free space."
            )

        elif self.mode in (StorageMode.MANUAL, StorageMode.PRE_MOUNTED):
            plan = StoragePlan(
                mode=StorageMode.PRE_MOUNTED,
                disk_path=self.selected_disk.node,
                premounted_root="/mnt",
                premounted_esp="/mnt/boot/efi",
                valid=True
            )
            self.config.storage_plan = plan
            summary.update(f"[{COLOR_CYAN}]Pre-mounted mode: Using existing mounts under /mnt. No formatting applied.[/]")

        self.on_change()

    def on_radio_set_changed(self, event: RadioSet.Changed) -> None:
        if event.pressed.id == "opt-storage-erase":
            self.mode = StorageMode.ERASE
        elif event.pressed.id == "opt-storage-free":
            self.mode = StorageMode.FREE_SPACE
        elif event.pressed.id == "opt-storage-manual":
            self.mode = StorageMode.PRE_MOUNTED

        self.update_plan()

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        if event.option_id:
            for d in self.disks:
                if d.node == event.option_id:
                    self.selected_disk = d
                    break
            self.update_plan()

    def on_option_list_option_highlighted(self, event: OptionList.OptionHighlighted) -> None:
        if event.option_id:
            for d in self.disks:
                if d.node == event.option_id:
                    self.selected_disk = d
                    break
            self.update_plan()
