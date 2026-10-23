"""
Headless UI and navigation tests for AstraInstallerApp using Textual's test runner.
Captures screenshots/SVGs to docs/screens/installer/.
"""

import os
import unittest
from pathlib import Path

from astra_installer.models import AstraConfig
from astra_installer.wizard import AstraInstallerApp


class TestWizardHeadless(unittest.IsolatedAsyncioTestCase):
    async def test_wizard_navigation_and_screenshot(self):
        os.environ["ASTRA_SKIP_UEFI"] = "1"
        cfg = AstraConfig()
        cfg.network_ok = True
        cfg.uefi_ok = True
        cfg.hostname = "astraos"
        cfg.root_password = "testrootpassword"
        cfg.username = "tester"
        cfg.user_password = "testuserpassword"

        app = AstraInstallerApp(cfg)
        async with app.run_test(size=(100, 30)) as pilot:
            await pilot.pause()
            screen = app.screen
            self.assertTrue(hasattr(screen, "step"))
            self.assertEqual(screen.step, 1)

            # Advance to step 2 (Keyboard)
            screen.action_next_step()
            await pilot.pause()
            self.assertEqual(screen.step, 2)

            # Advance to step 3 (Locale)
            screen.action_next_step()
            await pilot.pause()
            self.assertEqual(screen.step, 3)

            # Test Back navigation
            screen.action_back_step()
            await pilot.pause()
            self.assertEqual(screen.step, 2)

            # Export SVG screenshot to docs/screens/installer/
            out_dir = Path("/mnt/c/Users/Apex/Documents/AstraOS/docs/screens/installer")
            out_dir.mkdir(parents=True, exist_ok=True)
            svg_data = app.export_screenshot()
            svg_file = out_dir / "installer_step2_100x30.svg"
            svg_file.write_text(svg_data, encoding="utf-8")
            self.assertTrue(svg_file.exists())


if __name__ == "__main__":
    unittest.main()
