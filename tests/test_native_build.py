"""Check the optional native helpers without installing or compiling packages."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1]
MOCK = r'''
import json
import os
from pathlib import Path
import sys

name, args = Path(sys.argv[0]).name, sys.argv[1:]
record = {"tool": name, "args": args, "cwd": os.getcwd()}
if name == "sage" and args[:2] == ["-python", "-"]:
    record["stdin"] = sys.stdin.read()
with open(os.environ["NATIVE_TEST_LOG"], "a") as stream:
    stream.write(json.dumps(record) + "\n")
fail = os.environ.get("NATIVE_TEST_FAIL")
if fail == name or (fail == "runtime" and name == "sage" and args[:2] == ["-python", "-c"]):
    sys.exit(17)
if name == "sage-get-system-packages":
    print("python3-dev gcc g++\nautoconf libtool")
'''


class NativeBuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="sagepod-native-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.tree = self.root / "sage-10.10"
        self.tree.mkdir()
        (self.tree / "VERSION.txt").write_text("10.10\n")
        self.mockbin = self.root / "mockbin"
        self.mockbin.mkdir()
        self.log = self.root / "commands.jsonl"
        self.env = {k: v for k, v in os.environ.items() if k not in
                    ("SAGE_TAG", "SAGE_HOME", "SAGE_LOCAL")}
        self.env.update(SAGE_HOME=str(self.tree), PATH=f"{self.mockbin}:/usr/bin:/bin",
                        NATIVE_TEST_LOG=str(self.log))
        for path in (self.tree / "sage", self.tree / "configure",
                     self.tree / "build/bin/sage-get-system-packages",
                     self.mockbin / "make", self.mockbin / "sudo"):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f"#!{sys.executable}\n" + MOCK)
            path.chmod(0o755)

    def run_script(self, name, *args, success=True, **overrides):
        result = subprocess.run([str(SOURCE / "compiling_sage" / name), *args],
                                cwd=self.root, env=self.env | overrides,
                                capture_output=True, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def calls(self):
        return [json.loads(row) for row in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_prerequisites_use_release_metadata_and_dry_run_does_not_install(self):
        result = self.run_script("sage-prereq.sh", "--dry-run")
        self.assertIn("python3-dev gcc g++ autoconf libtool git gfortran", result.stdout)
        self.assertEqual([row["tool"] for row in self.calls()], ["sage-get-system-packages"])
        self.assertEqual(self.calls()[0]["args"], ["debian", "_prereq", "_bootstrap"])
        self.run_script("sage-prereq.sh")
        sudo = [row for row in self.calls() if row["tool"] == "sudo"]
        self.assertEqual(sudo[0]["args"], ["apt-get", "update"])
        self.assertIn("python3-dev", sudo[1]["args"])
        self.assertIn("gfortran", sudo[1]["args"])

    def test_configure_runs_in_source_tree_and_preserves_options(self):
        prefix = self.root / "custom-prefix"
        self.run_script("minimal_sage.sh", "--with-system-gf2x=no", SAGE_LOCAL=str(prefix))
        calls = self.calls()
        self.assertEqual([row["tool"] for row in calls], ["make", "configure"])
        self.assertEqual(calls[0]["args"], ["configure"])
        self.assertEqual(calls[1]["args"], [f"--prefix={prefix}", "--with-system-gf2x=no"])
        self.assertTrue(all(row["cwd"] == str(self.tree) for row in calls))

    def test_failed_bootstrap_stops_before_configuration(self):
        self.run_script("minimal_sage.sh", success=False, NATIVE_TEST_FAIL="make")
        self.assertEqual([row["tool"] for row in self.calls()], ["make"])

    def test_wrong_source_version_is_rejected_before_any_commands(self):
        (self.tree / "VERSION.txt").write_text("10.8\n")
        for script in ("sage-prereq.sh", "minimal_sage.sh", "sage-postinstall.sh"):
            with self.subTest(script=script):
                result = self.run_script(script, success=False)
                self.assertIn("does not match SAGE_TAG=10.10", result.stderr)
        self.assertFalse(self.calls())

    def test_wrong_built_version_stops_before_package_changes(self):
        self.run_script("sage-postinstall.sh", success=False, NATIVE_TEST_FAIL="runtime")
        self.assertEqual(len(self.calls()), 1)
        self.assertEqual(self.calls()[0]["args"][:2], ["-python", "-c"])

    def test_postinstall_builds_solver_and_uses_modern_widget_packages(self):
        self.run_script("sage-postinstall.sh")
        calls = self.calls()
        pip = [row["args"] for row in calls if row["args"][:1] == ["-pip"]]
        self.assertIn("--no-binary=pycryptosat", pip[0])
        self.assertIn("pycryptosat==5.11.21", pip[0])
        self.assertIn("notebook>=7,<8", pip[1])
        self.assertIn("jupyterlab>=4,<5", pip[1])
        self.assertIn("ipywidgets>=8,<9", pip[1])
        compile(calls[-1]["stdin"], "native-postinstall-stdin", "exec")

    def test_help_needs_no_source_and_whitespace_paths_are_rejected(self):
        missing = str(self.root / "missing source")
        for script in ("sage-prereq.sh", "minimal_sage.sh", "sage-postinstall.sh"):
            with self.subTest(script=script):
                result = self.run_script(script, "--help", SAGE_HOME=missing)
                self.assertIn("10.10", result.stdout)
                result = self.run_script(script, success=False, SAGE_HOME=missing)
                self.assertIn("no whitespace", result.stderr)
                result = self.run_script(script, success=False, SAGE_HOME="relative-source")
                self.assertIn("absolute paths", result.stderr)
        self.assertFalse(self.calls())


if __name__ == "__main__":
    unittest.main()
