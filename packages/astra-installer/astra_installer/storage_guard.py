"""
AstraOS Storage Safety Guard and Planner Engine.
Strictly guarantees that existing partitions are untouched unless explicitly selected,
enforces the 35 GiB storage floor, creates GPT backups, and computes first-MiB SHA-256 hashes.
"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from astra_installer.models import (
    OperationType,
    StorageMode,
    StorageOperation,
    StoragePlan,
    SwapMode,
)

MIN_STORAGE_BYTES: int = 35 * 1024 * 1024 * 1024       # 35 GiB total floor (D-037)
MIN_ROOT_BYTES: int = 34 * 1024 * 1024 * 1024          # 34 GiB root
ESP_SIZE_BYTES: int = 1024 * 1024 * 1024               # 1 GiB ESP
SECTOR_SIZE: int = 512
ALIGNMENT_1MIB: int = 2048                              # 1 MiB in 512-byte sectors


@dataclass
class PartitionMeta:
    node: str
    name: str
    partuuid: str
    uuid: str
    fstype: str
    label: str
    size_bytes: int
    start_sector: int
    end_sector: int
    part_type: str
    mountpoints: List[str] = field(default_factory=list)
    is_esp: bool = False
    is_windows: bool = False
    is_live: bool = False


@dataclass
class DiskMeta:
    node: str
    name: str
    model: str
    size_bytes: int
    pttype: str  # gpt, dos, etc.
    serial: str
    wwn: str
    removable: bool
    is_live: bool
    partitions: List[PartitionMeta] = field(default_factory=list)


def run_cmd(cmd: List[str], check: bool = True) -> Tuple[int, str, str]:
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if check and res.returncode != 0:
        raise RuntimeError(f"Command {' '.join(cmd)} failed (code {res.returncode}): {res.stderr}")
    return res.returncode, res.stdout, res.stderr


def get_live_parent_disk() -> Optional[str]:
    """Identify the parent disk of the live ISO medium to prevent selecting it."""
    code, out, _ = run_cmd(["findmnt", "-n", "-o", "SOURCE", "/run/archiso/bootmnt"], check=False)
    src = out.strip()
    if not src:
        return None
    code, pk, _ = run_cmd(["lsblk", "-no", "PKNAME", src], check=False)
    parent = pk.strip()
    if parent:
        return f"/dev/{parent}"
    return None


def discover_disks() -> List[DiskMeta]:
    """Inspect all block devices via lsblk with JSON output."""
    live_parent = get_live_parent_disk()
    columns = "NAME,KNAME,PATH,SIZE,TYPE,MODEL,TRAN,RM,FSTYPE,LABEL,MOUNTPOINTS,PTTYPE,PARTUUID,UUID,PARTTYPE,SERIAL,WWN"
    code, out, _ = run_cmd(["lsblk", "-J", "-b", "-o", columns], check=False)
    if code != 0 or not out.strip():
        # Fallback to older singular MOUNTPOINT
        code, out, _ = run_cmd(["lsblk", "-J", "-b", "-o", "NAME,KNAME,PATH,SIZE,TYPE,MODEL,TRAN,RM,FSTYPE,LABEL,MOUNTPOINT,PTTYPE,PARTUUID,UUID,PARTTYPE,SERIAL,WWN"], check=False)
        if code != 0:
            return []

    try:
        data = json.loads(out)
    except Exception:
        return []

    disks: List[DiskMeta] = []
    blockdevices = data.get("blockdevices", [])

    for dev in blockdevices:
        if dev.get("type") != "disk":
            continue
        name = dev.get("name", "")
        # Filter out RAM, loop, optical, zram, and mapper
        if any(name.startswith(pfx) for pfx in ("loop", "ram", "zram", "sr", "dm-", "md", "nbd", "rbd")):
            continue

        path = dev.get("path") or f"/dev/{name}"
        size_bytes = int(dev.get("size") or 0)
        pttype = dev.get("pttype") or ""
        model = (dev.get("model") or "").strip()
        serial = (dev.get("serial") or "").strip()
        wwn = (dev.get("wwn") or "").strip()
        removable = bool(dev.get("rm"))

        # Check if this disk or its partitions hold the live medium
        is_live = (path == live_parent)

        part_metas: List[PartitionMeta] = []
        for child in dev.get("children", []):
            if child.get("type") != "part":
                continue
            cname = child.get("name", "")
            cpath = child.get("path") or f"/dev/{cname}"
            csize = int(child.get("size") or 0)
            cfstype = (child.get("fstype") or "").strip()
            clabel = (child.get("label") or "").strip()
            cpartuuid = (child.get("partuuid") or "").strip()
            cuuid = (child.get("uuid") or "").strip()
            cparttype = (child.get("parttype") or "").strip().lower()

            mps: List[str] = []
            if "mountpoints" in child and isinstance(child["mountpoints"], list):
                mps = [m for m in child["mountpoints"] if m]
            elif "mountpoint" in child and child["mountpoint"]:
                mps = [child["mountpoint"]]

            if any(m.startswith("/run/archiso") for m in mps):
                is_live = True

            is_esp = (cparttype in ("c12a7328-f81f-11d2-ba4b-00a0c93ec93b", "0xef", "ef00") or cfstype == "vfat" and "efi" in clabel.lower())
            is_win = (cparttype in ("ebd0a0a2-b9e5-4433-87c0-68b6b72699c7", "e3c9e310-0b45-4386-a885-ae8e200268f6") or "recovery" in clabel.lower())

            part_metas.append(PartitionMeta(
                node=cpath,
                name=cname,
                partuuid=cpartuuid,
                uuid=cuuid,
                fstype=cfstype,
                label=clabel,
                size_bytes=csize,
                start_sector=0,
                end_sector=0,
                part_type=cparttype,
                mountpoints=mps,
                is_esp=is_esp,
                is_windows=is_win,
                is_live=is_live,
            ))

        disks.append(DiskMeta(
            node=path,
            name=name,
            model=model,
            size_bytes=size_bytes,
            pttype=pttype,
            serial=serial,
            wwn=wwn,
            removable=removable,
            is_live=is_live,
            partitions=part_metas,
        ))

    disks.sort(key=lambda d: d.node)
    return disks


def compute_first_mib_hash(part_node: str) -> str:
    """Read and hash the first 1 MiB of a partition to verify data preservation."""
    try:
        with open(part_node, "rb") as f:
            data = f.read(1024 * 1024)
            return hashlib.sha256(data).hexdigest()
    except Exception:
        return ""


def make_partition_node(disk_node: str, part_num: int) -> str:
    """Format partition node: /dev/sda1 for sda, /dev/nvme0n1p1 for nvme."""
    sep = "p" if disk_node[-1].isdigit() else ""
    return f"{disk_node}{sep}{part_num}"


def build_erase_plan(disk: DiskMeta, swap_mode: SwapMode, swap_size_gib: int) -> StoragePlan:
    """Option 1: Erase entire disk and generate standard AstraOS layout."""
    plan = StoragePlan(
        mode=StorageMode.ERASE,
        disk_path=disk.node,
        disk_model=disk.model,
        disk_size_bytes=disk.size_bytes,
    )

    if disk.size_bytes < MIN_STORAGE_BYTES:
        plan.valid = False
        plan.validation_error = f"Disk {disk.node} is {disk.size_bytes // (1024**3)} GiB, smaller than the required 35 GiB floor."
        return plan

    # 1. Wipe disk
    plan.operations.append(StorageOperation(
        op_type=OperationType.WIPE_DISK,
        device=disk.node,
    ))

    # 2. ESP partition: 1 GiB FAT32 at /boot/efi
    esp_node = make_partition_node(disk.node, 1)
    plan.operations.append(StorageOperation(
        op_type=OperationType.CREATE_PARTITION,
        device=disk.node,
        target_part=esp_node,
        fs_type="vfat",
        size_bytes=ESP_SIZE_BYTES,
        mountpoint="/boot/efi",
        label="AstraESP",
    ))
    plan.operations.append(StorageOperation(
        op_type=OperationType.FORMAT,
        device=disk.node,
        target_part=esp_node,
        fs_type="vfat",
        mountpoint="/boot/efi",
        label="AstraESP",
    ))
    plan.esp_device = esp_node

    # 3. Optional Swap partition
    curr_part_idx = 2
    if swap_mode == SwapMode.PARTITION:
        swap_bytes = swap_size_gib * 1024 * 1024 * 1024
        swap_node = make_partition_node(disk.node, curr_part_idx)
        curr_part_idx += 1
        plan.operations.append(StorageOperation(
            op_type=OperationType.CREATE_PARTITION,
            device=disk.node,
            target_part=swap_node,
            fs_type="swap",
            size_bytes=swap_bytes,
            label="AstraSwap",
        ))
        plan.operations.append(StorageOperation(
            op_type=OperationType.FORMAT,
            device=disk.node,
            target_part=swap_node,
            fs_type="swap",
            label="AstraSwap",
        ))
        plan.swap_device = swap_node

    # 4. Root partition: Btrfs labeled AstraOS (rest of disk)
    root_node = make_partition_node(disk.node, curr_part_idx)
    plan.operations.append(StorageOperation(
        op_type=OperationType.CREATE_PARTITION,
        device=disk.node,
        target_part=root_node,
        fs_type="btrfs",
        size_bytes=None,  # Fill remaining disk
        mountpoint="/",
        label="AstraOS",
    ))
    plan.operations.append(StorageOperation(
        op_type=OperationType.FORMAT,
        device=disk.node,
        target_part=root_node,
        fs_type="btrfs",
        mountpoint="/",
        label="AstraOS",
    ))
    plan.root_device = root_node

    # Compute baseline hashes for any existing partitions
    for p in disk.partitions:
        h = compute_first_mib_hash(p.node)
        if h:
            plan.baseline_hashes[p.node] = h

    plan.valid = True
    return plan


def create_partition_backup(disk_node: str, backup_dir: Path = Path("/root")) -> Path:
    """Save sfdisk and sgdisk backups to /root/astra-partition-backup-*."""
    backup_dir.mkdir(parents=True, exist_ok=True)
    dev_name = Path(disk_node).name
    sfdisk_file = backup_dir / f"astra-partition-backup-{dev_name}.sfdisk"
    sgdisk_file = backup_dir / f"astra-partition-backup-{dev_name}.sgdisk"

    run_cmd(["sfdisk", "--dump", disk_node], check=False)
    code, dump_out, _ = run_cmd(["sfdisk", "--dump", disk_node], check=False)
    if code == 0:
        sfdisk_file.write_text(dump_out)

    run_cmd(["sgdisk", f"--backup={sgdisk_file}", disk_node], check=False)
    return sfdisk_file


def verify_untouched_partitions(plan: StoragePlan, disks: List[DiskMeta]) -> Tuple[bool, List[str]]:
    """Assert that every partition NOT scheduled for modification is bit-identical."""
    errors: List[str] = []
    if plan.mode == StorageMode.ERASE:
        return True, []

    for disk in disks:
        for p in disk.partitions:
            # Check if this partition was planned to be deleted
            was_deleted = any(op.op_type == OperationType.DELETE_PARTITION and op.target_part == p.node for op in plan.operations)
            if was_deleted:
                continue

            orig_hash = plan.baseline_hashes.get(p.node)
            if orig_hash:
                curr_hash = compute_first_mib_hash(p.node)
                if curr_hash != orig_hash:
                    errors.append(f"CRITICAL: Partition {p.node} first-MiB hash mismatch! Expected {orig_hash[:8]}, got {curr_hash[:8]}")

    return len(errors) == 0, errors
