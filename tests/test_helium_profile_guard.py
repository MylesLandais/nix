from __future__ import annotations

import importlib.util
import json
import os
import socket
import sys
import tempfile
import unittest
from pathlib import Path
from types import ModuleType


REPO_ROOT = Path(__file__).resolve().parents[1]


def load_script(name: str, filename: str | None = None) -> ModuleType:
    script_name = filename or name
    spec = importlib.util.spec_from_file_location(name, REPO_ROOT / "scripts" / f"{script_name}.py")
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load script module {name}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


guard = load_script("helium_profile_guard", "helium-profile-guard")


class HeliumProfileGuardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.data_dir = self.root / "net.imput.helium"
        self.profile_dir = self.data_dir / "Default"
        self.profile_dir.mkdir(parents=True)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write_json(self, path: Path, value: object) -> None:
        path.write_text(json.dumps(value), encoding="utf-8")

    def read_json(self, path: Path) -> dict:
        return json.loads(path.read_text(encoding="utf-8"))

    def test_registers_existing_profile_and_repairs_preferences(self) -> None:
        self.write_json(
            self.profile_dir / "Preferences",
            {
                "profile": {"name": "Your Helium", "avatar_index": 26},
                "helium": {"unrelated": "keep"},
                "vertical_tabs": {"uncollapsed_width": 120},
            },
        )
        self.write_json(self.data_dir / "Local State", {"browser": {"keep": True}})

        changed = guard.repair_profile(self.data_dir)

        self.assertEqual({Path(path).name for path in changed}, {"Preferences", "Local State"})
        preferences = self.read_json(self.profile_dir / "Preferences")
        self.assertEqual(preferences["helium"]["unrelated"], "keep")
        self.assertTrue(preferences["helium"]["services"]["ext_proxy"])
        self.assertTrue(preferences["vertical_tabs"]["enabled"])

        local_state = self.read_json(self.data_dir / "Local State")
        entry = local_state["profile"]["info_cache"]["Default"]
        self.assertEqual(entry["name"], "Your Helium")
        self.assertEqual(entry["avatar_index"], 26)
        self.assertEqual(local_state["profile"]["profiles_order"], ["Default"])
        self.assertEqual(local_state["profile"]["last_active_profiles"], ["Default"])
        self.assertTrue(local_state["browser"]["keep"])

    def test_repairs_mismatched_profile_name(self) -> None:
        self.write_json(self.profile_dir / "Preferences", {"profile": {"name": "Your Helium"}})
        self.write_json(
            self.data_dir / "Local State",
            {"profile": {"info_cache": {"Default": {"name": "You"}}}},
        )

        guard.repair_profile(self.data_dir)

        self.assertEqual(
            self.read_json(self.data_dir / "Local State")["profile"]["info_cache"]["Default"]["name"],
            "Your Helium",
        )

    def test_repair_is_idempotent(self) -> None:
        self.write_json(self.profile_dir / "Preferences", {"profile": {"name": "Your Helium"}})
        self.write_json(self.data_dir / "Local State", {})

        guard.repair_profile(self.data_dir)
        first_preferences = (self.profile_dir / "Preferences").read_bytes()
        first_local_state = (self.data_dir / "Local State").read_bytes()

        self.assertEqual(guard.repair_profile(self.data_dir), [])
        self.assertEqual((self.profile_dir / "Preferences").read_bytes(), first_preferences)
        self.assertEqual((self.data_dir / "Local State").read_bytes(), first_local_state)

    def test_missing_local_state_is_created(self) -> None:
        self.write_json(self.profile_dir / "Preferences", {"profile": {"name": "Your Helium"}})

        guard.repair_profile(self.data_dir)

        self.assertTrue((self.data_dir / "Local State").exists())
        self.assertIn(
            "Default",
            self.read_json(self.data_dir / "Local State")["profile"]["info_cache"],
        )

    def test_malformed_local_state_is_not_overwritten(self) -> None:
        self.write_json(self.profile_dir / "Preferences", {"profile": {"name": "Your Helium"}})
        local_state = self.data_dir / "Local State"
        local_state.write_text("not json", encoding="utf-8")

        self.assertEqual(guard.repair_profile(self.data_dir), [])
        self.assertEqual(local_state.read_text(encoding="utf-8"), "not json")

    def test_live_browser_lock_skips_all_writes(self) -> None:
        self.write_json(self.profile_dir / "Preferences", {"profile": {"name": "Your Helium"}})
        self.write_json(self.data_dir / "Local State", {})
        os.symlink(f"{socket.gethostname()}-{os.getpid()}", self.data_dir / "SingletonLock")
        before_preferences = (self.profile_dir / "Preferences").read_bytes()
        before_local_state = (self.data_dir / "Local State").read_bytes()

        self.assertEqual(guard.repair_profile(self.data_dir), [])
        self.assertEqual((self.profile_dir / "Preferences").read_bytes(), before_preferences)
        self.assertEqual((self.data_dir / "Local State").read_bytes(), before_local_state)

    def test_stale_browser_lock_is_removed(self) -> None:
        os.symlink(f"{socket.gethostname()}-999999999", self.data_dir / "SingletonLock")

        self.assertFalse(guard._browser_lock_is_live(self.data_dir))
        self.assertFalse(os.path.lexists(self.data_dir / "SingletonLock"))


if __name__ == "__main__":
    unittest.main()
