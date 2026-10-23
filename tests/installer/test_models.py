"""
Unit tests for AstraOS Installer models and validation rules.
"""

import unittest
from astra_installer.models import AstraConfig, SudoMode, SwapMode


class TestAstraModels(unittest.TestCase):
    def test_hostname_validation(self):
        ok, _ = AstraConfig.validate_hostname("astraos")
        self.assertTrue(ok)
        ok, _ = AstraConfig.validate_hostname("my-pc-123")
        self.assertTrue(ok)
        ok, err = AstraConfig.validate_hostname("-invalid")
        self.assertFalse(ok)
        ok, err = AstraConfig.validate_hostname("toolong" * 15)
        self.assertFalse(ok)

    def test_username_validation(self):
        ok, _ = AstraConfig.validate_username("alex")
        self.assertTrue(ok)
        ok, _ = AstraConfig.validate_username("user_1")
        self.assertTrue(ok)
        ok, err = AstraConfig.validate_username("1user")
        self.assertFalse(ok)
        ok, err = AstraConfig.validate_username("root")
        self.assertFalse(ok)

    def test_password_validation(self):
        ok, _ = AstraConfig.validate_password("secret123")
        self.assertTrue(ok)
        ok, err = AstraConfig.validate_password("12")
        self.assertFalse(ok)
        ok, err = AstraConfig.validate_password("has\nnewline")
        self.assertFalse(ok)

    def test_nopasswd_forbidden(self):
        cfg = AstraConfig()
        cfg.sudo_mode = SudoMode.WITH_PASSWORD
        safe = cfg.to_safe_dict()
        # Ensure NOPASSWD never appears anywhere in default or safe configuration
        self.assertNotIn("NOPASSWD", str(safe))

    def test_safe_dict_masks_secrets(self):
        cfg = AstraConfig()
        cfg.root_password = "supersecretroot"
        cfg.user_password = "supersecretuser"
        safe = cfg.to_safe_dict()
        self.assertEqual(safe["root_password"], "***")
        self.assertEqual(safe["user_password"], "***")

    def test_browser_choices(self):
        from astra_installer.models import BrowserChoice
        self.assertIn(BrowserChoice.HELIUM, list(BrowserChoice))
        self.assertEqual(BrowserChoice.HELIUM.value, "helium-browser-bin")


if __name__ == "__main__":
    unittest.main()
