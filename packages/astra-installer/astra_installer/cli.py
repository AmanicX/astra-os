"""
AstraOS Terminal Installer Entry Point (astra-install).
Supports interactive Textual TUI wizard, unattended JSON mode, and fallback mode.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from pathlib import Path

from astra_installer.fallback import run_plain_prompt_wizard
from astra_installer.models import AstraConfig
from astra_installer.wizard import AstraInstallerApp


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="astra-install",
        description="AstraOS Modern Terminal Installer"
    )
    parser.add_argument("--config", help="Path to JSON configuration file for unattended install")
    parser.add_argument("--creds", help="Path to credentials JSON file for unattended install")
    parser.add_argument("--silent", action="store_true", help="Run in non-interactive silent mode")
    parser.add_argument("--dry-run", action="store_true", help="Validate configuration and exit without disk writes")
    parser.add_argument("--fallback", action="store_true", help="Force plain prompt mode without Textual TUI")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    # Require root execution unless testing
    if os.geteuid() != 0 and os.environ.get("ASTRA_SKIP_ROOT") != "1":
        print("error: astra-install must be run as root (try: sudo astra-install)", file=sys.stderr)
        sys.exit(1)

    config = AstraConfig()

    # Load unattended config if specified
    if args.config:
        try:
            with open(args.config, "r", encoding="utf-8") as f:
                data = json.load(f)
                # Populate config fields
                if "hostname" in data:
                    config.hostname = data["hostname"]
                if "locale" in data:
                    config.locale = data["locale"]
                if "timezone" in data:
                    config.timezone = data["timezone"]
                if "keyboard_layout" in data:
                    config.keyboard_layout = data["keyboard_layout"]
        except Exception as e:
            print(f"error: Failed to load config from {args.config}: {e}", file=sys.stderr)
            sys.exit(1)

    if args.creds:
        try:
            with open(args.creds, "r", encoding="utf-8") as f:
                creds = json.load(f)
                if "root_password" in creds:
                    config.root_password = creds["root_password"]
                if "user_password" in creds:
                    config.user_password = creds["user_password"]
                if "username" in creds:
                    config.username = creds["username"]
        except Exception as e:
            print(f"error: Failed to load creds from {args.creds}: {e}", file=sys.stderr)
            sys.exit(1)

    if args.dry_run:
        print("[Dry Run] AstraOS configuration validated successfully:")
        print(config.to_json(safe=True))
        sys.exit(0)

    # Check terminal dimensions
    cols, rows = shutil.get_terminal_size(fallback=(100, 30))
    use_fallback = args.fallback or (cols < 76 or rows < 20) or not sys.stdin.isatty()

    if use_fallback:
        if cols < 76 or rows < 20:
            print(f"Notice: Terminal size is {cols}x{rows}. AstraOS TUI recommends at least 80x24.")
            print("Switching to plain prompt fallback mode...\n")
        config = run_plain_prompt_wizard(config)
        # Execute plain install worker
        from astra_installer.engine import run_installation_worker
        class DummyWidget:
            def append_log(self, t: str) -> None:
                print(t)
            def set_phase(self, i: int, n: str) -> None:
                print(f"\n[Phase {i+1}/7] {n}")
            def update_package_progress(self, c: int, t: int) -> None:
                print(f"  Package progress: {c}/{t}")
            def set_error(self, err: str) -> None:
                print(f"FAILED: {err}")
            def on_complete(self) -> None:
                print("\nInstallation Completed Successfully!")
        run_installation_worker(config, DummyWidget())
    else:
        # Launch Textual TUI
        app = AstraInstallerApp(config)
        app.run()


if __name__ == "__main__":
    main()
