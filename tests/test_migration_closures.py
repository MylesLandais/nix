import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/migration/compare-closures.py"
spec = importlib.util.spec_from_file_location("migration_closures", SCRIPT)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class ClosureGateTests(unittest.TestCase):
    def compare_leaf(self, name, old_hash, new_hash, new_name=None):
        root = "/nix/store/old-system"
        old = {root: {"narHash": "system"}, f"/nix/store/a-{name}": {"narHash": old_hash}}
        new = {root: {"narHash": "system"}, f"/nix/store/b-{new_name or name}": {"narHash": new_hash}}
        return gate.compare(root, old, root, new)

    def test_relocated_identical_output(self):
        report = self.compare_leaf("client-1", "content", "content")
        self.assertFalse(report["problems"])
        self.assertEqual(len(report["paired"]), 1)

    def test_version_change_with_same_content(self):
        self.assertTrue(self.compare_leaf("client-1", "content", "content", "client-2")["problems"])

    def test_edited_consumed_file_same_name(self):
        self.assertTrue(self.compare_leaf("client-1", "old", "edited")["problems"])

    def test_installer_name_does_not_exempt_a_nonstamp_edit(self):
        self.assertTrue(self.compare_leaf("iso-build-info", "stamp + file", "stamp + edit")["problems"])

    @unittest.skipUnless(shutil.which("nix") and shutil.which("git"), "requires Nix and Git")
    def test_stamp_override_preserves_real_source_and_installer_edits(self):
        wrapper = SCRIPT.with_name("installer-comparison.nix")
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1",
                       GIT_AUTHOR_NAME="Fixture", GIT_AUTHOR_EMAIL="fixture@example.invalid",
                       GIT_COMMITTER_NAME="Fixture", GIT_COMMITTER_EMAIL="fixture@example.invalid")

            def git(*args):
                return subprocess.check_output(["git", *args], cwd=repo, env=env, text=True).strip()

            def evaluate():
                git("add", ".")
                git("commit", "-qm", "fixture")
                revision = git("rev-parse", "HEAD")
                return json.loads(subprocess.check_output([
                    "nix", "eval", "--json", "--file", str(wrapper),
                    "--argstr", "flakeRef", f"git+file://{repo}?rev={revision}",
                    "--argstr", "expectedRev", revision, "info",
                ]))

            git("init", "-q")
            flake = repo / "flake.nix"
            flake.write_text('''{
              outputs = { self }: {
                nixosConfigurations.installerIso.config.info = {
                  inherit (self) rev shortRev;
                  file = builtins.readFile (self.outPath + "/payload");
                  edition = "shim";
                };
              };
            }''')
            payload = repo / "payload"
            payload.write_text("first")
            baseline = evaluate()
            (repo / "unconsumed").write_text("irrelevant")
            self.assertEqual(baseline, evaluate())
            self.assertEqual((baseline["rev"], baseline["shortRev"]), ("0" * 40, "0" * 7))
            payload.write_text("second")
            self.assertEqual(evaluate(), {**baseline, "file": "second"})
            flake.write_text(flake.read_text().replace('"shim"', '"changed"'))
            self.assertEqual(evaluate(), {**baseline, "file": "second", "edition": "changed"})
