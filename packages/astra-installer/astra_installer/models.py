"""
AstraOS Installer Models and State Definition.
Maps user selections from the 17-screen sequential wizard to typed models
and bridges to archinstall's ArchConfig and DiskLayoutConfiguration.
"""

from __future__ import annotations

import enum
import json
import re
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional


class StorageMode(str, enum.Enum):
    ERASE = "erase"
    FREE_SPACE = "free_space"
    MANUAL = "manual"
    PRE_MOUNTED = "pre_mounted"


class SwapMode(str, enum.Enum):
    ZRAM = "zram"
    PARTITION = "partition"
    NONE = "none"


class SudoMode(str, enum.Enum):
    WITH_PASSWORD = "with_password"
    NONE = "none"


class BrowserChoice(str, enum.Enum):
    FIREFOX = "firefox"
    CHROMIUM = "chromium"
    BRAVE = "brave"
    NONE = "none"


class AurHelperChoice(str, enum.Enum):
    PARU = "paru"
    YAY = "yay"
    NONE = "none"


class OperationType(str, enum.Enum):
    WIPE_DISK = "WipeDisk"
    CREATE_PARTITION = "CreatePartition"
    DELETE_PARTITION = "DeletePartition"
    FORMAT = "Format"


@dataclass
class StorageOperation:
    op_type: OperationType
    device: str
    target_part: Optional[str] = None
    fs_type: Optional[str] = None
    start_sector: Optional[int] = None
    size_sectors: Optional[int] = None
    size_bytes: Optional[int] = None
    mountpoint: Optional[str] = None
    label: Optional[str] = None

    def describe(self) -> str:
        if self.op_type == OperationType.WIPE_DISK:
            return f"Create fresh GPT partition table on {self.device}"
        elif self.op_type == OperationType.DELETE_PARTITION:
            return f"Delete partition {self.target_part} on {self.device}"
        elif self.op_type == OperationType.CREATE_PARTITION:
            size_mb = (self.size_bytes or 0) // (1024 * 1024)
            return f"Create partition on {self.device} ({size_mb} MiB, {self.fs_type or 'unformatted'})"
        elif self.op_type == OperationType.FORMAT:
            return f"Format {self.target_part} as {self.fs_type} (mount: {self.mountpoint})"
        return f"{self.op_type} on {self.device}"


@dataclass
class StoragePlan:
    mode: StorageMode = StorageMode.ERASE
    disk_path: str = ""
    disk_model: str = ""
    disk_size_bytes: int = 0
    operations: List[StorageOperation] = field(default_factory=list)
    esp_device: str = ""
    root_device: str = ""
    swap_device: Optional[str] = None
    premounted_root: Optional[str] = None
    premounted_esp: Optional[str] = None
    confirmed_token: Optional[str] = None
    baseline_hashes: Dict[str, str] = field(default_factory=dict)
    valid: bool = False
    validation_error: str = ""


@dataclass
class AstraConfig:
    # 01 Welcome
    network_ok: bool = False
    uefi_ok: bool = True
    secure_boot: bool = False
    memory_mib: int = 4096

    # 02 Keyboard
    keyboard_layout: str = "us"
    keyboard_variant: str = ""

    # 03 Locale
    locale: str = "en_US.UTF-8"

    # 04 Timezone
    timezone: str = "UTC"
    ntp: bool = True

    # 05 Mirrors
    mirror_regions: List[str] = field(default_factory=lambda: ["Worldwide"])

    # 06 Multilib
    multilib_enabled: bool = True
    parallel_downloads: int = 5
    color_output: bool = True

    # 07 Swap
    swap_mode: SwapMode = SwapMode.ZRAM
    swap_size_gib: int = 4

    # 08 Hostname
    hostname: str = "astraos"

    # 09 Root password
    root_password: str = ""

    # 10 User account
    username: str = ""
    user_password: str = ""

    # 11 Sudo
    sudo_mode: SudoMode = SudoMode.WITH_PASSWORD

    # 12 Storage plan
    storage_plan: StoragePlan = field(default_factory=StoragePlan)

    # 13 Extra boot entries (os-prober)
    os_prober: bool = True
    detected_other_os: List[str] = field(default_factory=list)

    # 14 Additional packages
    additional_packages: List[str] = field(default_factory=list)
    browser: BrowserChoice = BrowserChoice.FIREFOX
    aur_helper: AurHelperChoice = AurHelperChoice.PARU

    # Validation rules
    @staticmethod
    def validate_hostname(name: str) -> tuple[bool, str]:
        if not name:
            return False, "Hostname cannot be empty."
        if len(name) > 63:
            return False, "Hostname must not exceed 63 characters."
        if not re.match(r"^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?$", name):
            return False, "Hostname must contain only letters, numbers, and hyphens (RFC 1123)."
        return True, ""

    @staticmethod
    def validate_username(name: str) -> tuple[bool, str]:
        if not name:
            return False, "Username cannot be empty."
        if not re.match(r"^[a-z_][a-z0-9_-]{0,31}$", name):
            return False, "Username must start with a lowercase letter and contain 1-32 chars [a-z0-9_-]."
        if name in ("root", "bin", "daemon", "adm", "sync", "shutdown", "halt", "mail", "news", "uucp", "operator", "games", "nobody", "systemd-network", "systemd-resolve"):
            return False, f"Username '{name}' is reserved by system."
        return True, ""

    @staticmethod
    def validate_password(pw: str) -> tuple[bool, str]:
        if not pw:
            return False, "Password cannot be empty."
        if "\n" in pw or "\r" in pw:
            return False, "Password cannot contain newlines."
        if len(pw) < 4:
            return False, "Password must be at least 4 characters."
        return True, ""

    def to_safe_dict(self) -> Dict[str, Any]:
        """Return a sanitized dictionary without secrets for support / debug logs."""
        data = asdict(self)
        data["root_password"] = "***" if self.root_password else ""
        data["user_password"] = "***" if self.user_password else ""
        return data

    def to_json(self, safe: bool = True) -> str:
        if safe:
            return json.dumps(self.to_safe_dict(), indent=2)
        return json.dumps(asdict(self), indent=2)
