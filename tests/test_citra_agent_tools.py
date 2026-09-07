from __future__ import annotations

import json
import importlib.util
import os
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path
from types import ModuleType

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))


def load_script(name: str) -> ModuleType:
    spec = importlib.util.spec_from_file_location(name, REPO_ROOT / "scripts" / f"{name}.py")
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load script module {name}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


bridge_module = load_script("citra_agent_bridge")
fe_echoes_index = load_script("fe_echoes_index")
three_ds_save_sync = load_script("three_ds_save_sync")


class CitraAgentBridgeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.games = self.root / "games"
        self.games.mkdir()
        self.config = bridge_module.BridgeConfig(
            host="127.0.0.1",
            port=47833,
            state_dir=self.root / "state",
            game_roots=(self.games.resolve(),),
            azahar_bin="false",
            ffmpeg_bin="false",
            xdotool_bin="false",
            display=":99",
            video_encoder="libx264",
        )
        self.bridge = bridge_module.Bridge(self.config)

    def tearDown(self) -> None:
        self.bridge.stop()
        self.temporary.cleanup()

    def test_roms_are_allowlisted_by_root_and_extension(self) -> None:
        rom = self.games / "owned.3ds"
        rom.write_bytes(b"synthetic fixture")
        self.assertEqual(self.bridge._validate_rom(str(rom)), rom.resolve())

        outside = self.root / "outside.3ds"
        outside.write_bytes(b"synthetic fixture")
        with self.assertRaisesRegex(bridge_module.BridgeError, "outside the configured game roots"):
            self.bridge._validate_rom(str(outside))

        wrong_type = self.games / "owned.zip"
        wrong_type.write_bytes(b"synthetic fixture")
        with self.assertRaisesRegex(bridge_module.BridgeError, "existing 3DS image"):
            self.bridge._validate_rom(str(wrong_type))

    def test_start_uses_azahar_short_gdb_option(self) -> None:
        rom = self.games / "owned.3ds"
        rom.write_bytes(b"synthetic fixture")
        process = mock.Mock(pid=1234)
        process.poll.return_value = None

        with (
            mock.patch.object(bridge_module.subprocess, "Popen", return_value=process) as popen,
            mock.patch.object(self.bridge, "_find_window", return_value=5678),
            mock.patch.object(self.bridge, "_start_window_stream"),
        ):
            self.bridge.start({"rom_path": str(rom)})

        self.assertEqual(
            popen.call_args.args[0],
            ["false", "-g", "24689", str(rom)],
        )
        self.bridge.process = None

    def test_input_rejects_unknown_buttons_before_touching_x11(self) -> None:
        with self.assertRaisesRegex(bridge_module.BridgeError, "unknown buttons"):
            self.bridge.press({"buttons": ["A", "SELF_DESTRUCT"]})

    def test_memory_reads_are_bounded(self) -> None:
        remote = bridge_module.GDBRemote("127.0.0.1", 1)
        with self.assertRaisesRegex(bridge_module.BridgeError, "between 1 and 4096"):
            remote.read_memory(0, 4097)
        self.assertEqual(bridge_module.GDBRemote._packet(b"m10,4"), b"$m10,4#2e")

    def test_non_loopback_configuration_is_rejected_by_main_contract(self) -> None:
        args = bridge_module.parser().parse_args(["--host", "0.0.0.0"])
        config = bridge_module.build_config(args)
        self.assertNotIn(config.host, {"127.0.0.1", "::1", "localhost"})

    def test_cors_reflects_only_loopback_browser_origins(self) -> None:
        self.assertEqual(
            bridge_module.allowed_cors_origin("http://localhost:4000"),
            "http://localhost:4000",
        )
        self.assertEqual(
            bridge_module.allowed_cors_origin("https://127.0.0.1:4443"),
            "https://127.0.0.1:4443",
        )
        self.assertIsNone(bridge_module.allowed_cors_origin("https://example.com"))
        self.assertIsNone(bridge_module.allowed_cors_origin("https://localhost.example.com"))


class SaveSyncTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.source = self.root / "checkpoint"
        self.source.mkdir()
        (self.source / "chapter0").write_bytes(b"save data")
        nested = self.source / "slot"
        nested.mkdir()
        (nested / "global").write_bytes(b"global data")

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_pull_verify_and_confirmed_push_preserve_backups(self) -> None:
        result = three_ds_save_sync.create_snapshot(
            self.source,
            self.root / "snapshots",
            "physical-3ds-before-new-game",
            "test-fixture",
        )
        snapshot = Path(result["snapshot"])
        manifest = three_ds_save_sync.verify_snapshot(snapshot)
        self.assertEqual(manifest["file_count"], 2)

        destination = self.root / "azahar-save"
        destination.mkdir()
        (destination / "old-save").write_text("old", encoding="utf-8")

        pushed = three_ds_save_sync.push_local(snapshot, destination, manifest["root_digest"])
        self.assertEqual((destination / "chapter0").read_bytes(), b"save data")
        self.assertFalse((destination / three_ds_save_sync.MANIFEST_NAME).exists())
        self.assertEqual((Path(pushed["backup"]) / "old-save").read_text(encoding="utf-8"), "old")

    def test_tampering_breaks_snapshot_verification(self) -> None:
        result = three_ds_save_sync.create_snapshot(
            self.source,
            self.root / "snapshots",
            "snapshot",
            "test-fixture",
        )
        snapshot = Path(result["snapshot"])
        (snapshot / "chapter0").write_bytes(b"tampered")
        with self.assertRaisesRegex(three_ds_save_sync.SyncError, "digest mismatch"):
            three_ds_save_sync.verify_snapshot(snapshot)

    def test_push_requires_exact_manifest_digest(self) -> None:
        result = three_ds_save_sync.create_snapshot(
            self.source,
            self.root / "snapshots",
            "snapshot",
            "test-fixture",
        )
        with self.assertRaisesRegex(three_ds_save_sync.SyncError, "confirm-digest"):
            three_ds_save_sync.push_local(Path(result["snapshot"]), self.root / "destination", "wrong")

    def test_checkpoint_wireless_receive_creates_verified_snapshot(self) -> None:
        fake_chlink = self.root / "fake-chlink"
        fake_chlink.write_text(
            """#!/usr/bin/env python3
import json
from pathlib import Path
import sys

out = Path(sys.argv[sys.argv.index("--out") + 1])
received = out / "saves" / "owned-title" / "pre-maya"
received.mkdir(parents=True)
(received / "chapter0").write_bytes(b"wireless save")
print(json.dumps({"event": "listening", "port": 8000, "pin": "1234", "ips": ["192.0.2.1"]}), flush=True)
print(json.dumps({"event": "received", "savedPath": str(received), "dataType": "save", "backupName": "pre-maya"}), flush=True)
""",
            encoding="utf-8",
        )
        fake_chlink.chmod(0o755)

        result = three_ds_save_sync.receive_checkpoint_wireless(
            fake_chlink,
            self.root / "snapshots",
            "physical-3ds-wireless",
            port=8000,
            timeout_seconds=5,
        )

        snapshot = Path(result["snapshot"])
        self.assertEqual((snapshot / "chapter0").read_bytes(), b"wireless save")
        self.assertEqual(three_ds_save_sync.verify_snapshot(snapshot)["root_digest"], result["manifest"]["root_digest"])

    def test_checkpoint_wireless_receive_rejects_reported_path_outside_staging(self) -> None:
        outside = self.root / "outside"
        outside.mkdir()
        (outside / "save").write_bytes(b"not staged")
        fake_chlink = self.root / "fake-chlink-outside"
        fake_chlink.write_text(
            f"""#!/usr/bin/env python3
import json
from pathlib import Path
import sys
Path(sys.argv[sys.argv.index("--out") + 1]).mkdir(parents=True)
print(json.dumps({{"event": "listening", "port": 8000, "pin": "1234", "ips": []}}), flush=True)
print(json.dumps({{"event": "received", "savedPath": {str(outside)!r}}}), flush=True)
""",
            encoding="utf-8",
        )
        fake_chlink.chmod(0o755)

        with self.assertRaisesRegex(three_ds_save_sync.SyncError, "outside the receive staging root"):
            three_ds_save_sync.receive_checkpoint_wireless(
                fake_chlink,
                self.root / "snapshots",
                "physical-3ds-wireless",
                port=8000,
                timeout_seconds=5,
            )

    def test_checkpoint_wireless_parser_uses_packaged_port(self) -> None:
        with mock.patch.dict(os.environ, {"CHECKPOINT_CHLINK_PORT": "18080"}):
            args = three_ds_save_sync.parser().parse_args(
                [
                    "receive-wireless",
                    "--destination-root",
                    str(self.root / "snapshots"),
                    "--name",
                    "physical-3ds-wireless",
                ]
            )
        self.assertEqual(args.port, 18080)


class EchoesIndexTest(unittest.TestCase):
    def test_index_is_deterministic_and_classifies_known_extensions(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "message.msbt").write_bytes(b"MsgStdBn" + bytes(16))
            (root / "model.bch").write_bytes(b"CGFX" + bytes(4))
            first = fe_echoes_index.build_index(root, "synthetic")
            second = fe_echoes_index.build_index(root, "synthetic")
            self.assertEqual(first["tree_digest"], second["tree_digest"])
            self.assertEqual(first["file_count"], 2)
            files = {entry["path"]: entry for entry in first["files"]}
            self.assertEqual(files["message.msbt"]["magic"], "msbt")
            self.assertEqual(files["model.bch"]["category"], "cgfx-model-or-texture")

    def test_extraction_is_rejected_inside_git_worktrees(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / ".git").mkdir()
            with self.assertRaisesRegex(fe_echoes_index.DatamineError, "inside Git worktree"):
                fe_echoes_index.ensure_outside_git(root / "extracted")


if __name__ == "__main__":
    unittest.main()
