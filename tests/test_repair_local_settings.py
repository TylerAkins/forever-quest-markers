import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("repair", Path(__file__).resolve().parents[1] / "tools/repair_local_settings.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RepairTests(unittest.TestCase):
    def test_live_link_order_backup_and_idempotence(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            addon = root / "ForeverQuestPins"
            addon.mkdir()
            saved = root / "ForeverQuestPins.lua"
            saved.write_text("ForeverQuestPinsDB = { autoAccept = true }")
            toc = addon / "ForeverQuestPins.toc"
            original = "## Title: Forever Quest Pins\nConfig.lua\nCore.lua\n"
            toc.write_text(original)
            module.repair(addon, saved)
            self.assertEqual(toc.read_text(), original)
            module.repair(addon, saved, dry_run=False)
            first = toc.read_text()
            module.repair(addon, saved, dry_run=False)
            self.assertEqual(toc.read_text(), first)
            self.assertLess(first.index("LocalSavedVariables"), first.index("Config.lua"))
            self.assertEqual(toc.with_suffix(".toc.before-settings-repair").read_text(), original)
            saved.write_text("ForeverQuestPinsDB = { autoAccept = false }")
            self.assertEqual((addon / "LocalSavedVariables/ForeverQuestPins.lua").read_text(), saved.read_text())
