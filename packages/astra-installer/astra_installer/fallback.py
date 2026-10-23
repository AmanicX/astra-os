"""
AstraOS Plain Prompt Fallback Mode.
Activated when running on bare TTYs without full terminal features
or when window size is below 80x24.
"""

from __future__ import annotations

import getpass
import sys
from typing import Optional

from astra_installer.models import AstraConfig, BrowserChoice, SudoMode, SwapMode


def run_plain_prompt_wizard(config: Optional[AstraConfig] = None) -> AstraConfig:
    """Sequential CLI prompt wizard asking the 17 questions in order."""
    cfg = config or AstraConfig()
    print("=" * 60)
    print("        AstraOS Terminal Installer (Fallback Mode)")
    print("=" * 60)

    # 1. Welcome
    print("\n[1/17] Welcome to AstraOS")
    input("Press Enter to begin preflight checks...")

    # 2. Keyboard
    print(f"\n[2/17] Keyboard Layout (current: {cfg.keyboard_layout})")
    kb = input("Enter keymap (e.g. us, de, uk) [default us]: ").strip()
    if kb:
        cfg.keyboard_layout = kb

    # 3. Locale
    print(f"\n[3/17] Locale (current: {cfg.locale})")
    loc = input("Enter locale [default en_US.UTF-8]: ").strip()
    if loc:
        cfg.locale = loc

    # 4. Timezone
    print(f"\n[4/17] Timezone (current: {cfg.timezone})")
    tz = input("Enter timezone [default UTC]: ").strip()
    if tz:
        cfg.timezone = tz

    # 5. Mirrors
    print("\n[5/17] Mirror Regions")
    reg = input("Enter mirror region (e.g. Worldwide, United States) [default Worldwide]: ").strip()
    if reg:
        cfg.mirror_regions = [reg]

    # 6. Multilib
    print("\n[6/17] multilib and 32-bit software support: Enabled automatically.")

    # 7. Swap
    print("\n[7/17] Swap Memory: 1) zram (recommended) 2) Swap Partition 3) None")
    sw = input("Select [1]: ").strip()
    if sw == "2":
        cfg.swap_mode = SwapMode.PARTITION
    elif sw == "3":
        cfg.swap_mode = SwapMode.NONE
    else:
        cfg.swap_mode = SwapMode.ZRAM

    # 8. Hostname
    print("\n[8/17] Hostname")
    hn = input("Enter hostname [default astraos]: ").strip()
    if hn:
        cfg.hostname = hn

    # 9. Root password
    print("\n[9/17] Root Administrative Password")
    while True:
        p1 = getpass.getpass("Enter root password: ")
        p2 = getpass.getpass("Confirm root password: ")
        if p1 and p1 == p2:
            cfg.root_password = p1
            break
        print("Passwords do not match or empty. Try again.")

    # 10. User account
    print("\n[10/17] Primary User Account")
    while True:
        un = input("Enter username (lowercase): ").strip()
        ok, err = AstraConfig.validate_username(un)
        if ok:
            cfg.username = un
            break
        print(f"Error: {err}")

    while True:
        up1 = getpass.getpass(f"Enter password for {cfg.username}: ")
        up2 = getpass.getpass("Confirm password: ")
        if up1 and up1 == up2:
            cfg.user_password = up1
            break
        print("Passwords do not match or empty. Try again.")

    # 11. Sudo
    print("\n[11/17] Sudo Access: 1) Sudo with password (Administrator) 2) Standard account")
    su = input("Select [1]: ").strip()
    cfg.sudo_mode = SudoMode.NONE if su == "2" else SudoMode.WITH_PASSWORD

    # 12. Storage
    print("\n[12/17] Storage: 1) Erase whole disk 2) Manual / Pre-mounted (/mnt)")
    sm = input("Select [1]: ").strip()
    # (Plan is filled via storage_guard)

    # 13. OS Prober
    print("\n[13/17] Detect other operating systems with os-prober? [Y/n]")
    op = input().strip().lower()
    cfg.os_prober = (op != "n")

    # 14. Additional packages
    print("\n[14/17] Web Browser: 1) Firefox 2) Chromium 3) Brave 4) None")
    br = input("Select [1]: ").strip()
    if br == "2":
        cfg.browser = BrowserChoice.CHROMIUM
    elif br == "3":
        cfg.browser = BrowserChoice.BRAVE
    elif br == "4":
        cfg.browser = BrowserChoice.NONE
    else:
        cfg.browser = BrowserChoice.FIREFOX

    # 15. Summary
    print("\n[15/17] Configuration Summary:")
    print(f"Target: {cfg.hostname} | User: {cfg.username} | Locale: {cfg.locale}")
    confirm = input("Type 'CONFIRM' to begin installation: ").strip()
    if confirm != "CONFIRM":
        print("Installation aborted by user.")
        sys.exit(0)

    return cfg
