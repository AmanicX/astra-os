"""
Headless visual export of all 17 screens across required terminal dimensions.
(80x24, 100x30, 140x40, 220x60).
"""

import asyncio
import os
from pathlib import Path

from astra_installer.models import AstraConfig, StorageMode
from astra_installer.wizard import AstraInstallerApp


async def capture_all_screens() -> None:
    os.environ["ASTRA_SKIP_UEFI"] = "1"
    os.environ["ASTRA_TEST_HEADLESS"] = "1"
    out_dir = Path("/mnt/c/Users/Apex/Documents/AstraOS/docs/screens/installer")
    out_dir.mkdir(parents=True, exist_ok=True)

    cfg = AstraConfig()
    cfg.network_ok = True
    cfg.uefi_ok = True
    cfg.hostname = "astraos"
    cfg.root_password = "testrootpassword"
    cfg.username = "alex"
    cfg.user_password = "testuserpassword"

    sizes = [(80, 24), (100, 30), (140, 40), (220, 60)]

    for cols, rows in sizes:
        print(f"Capturing at {cols}x{rows}...")
        app = AstraInstallerApp(cfg)
        async with app.run_test(size=(cols, rows)) as pilot:
            await pilot.pause()
            screen = app.screen

            for step in range(1, 18):
                screen.show_step(step)
                await pilot.pause()

                svg_data = app.export_screenshot()
                svg_name = f"screen_{step:02d}_{cols}x{rows}.svg"
                (out_dir / svg_name).write_text(svg_data, encoding="utf-8")
                print(f"  Exported {svg_name}")


if __name__ == "__main__":
    asyncio.run(capture_all_screens())
