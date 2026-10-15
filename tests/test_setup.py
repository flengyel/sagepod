"""Exercise setup orchestration in an isolated home with fake host commands.

These tests do not build or run a Sage image. Compose rendering tests additionally
use the real pinned podman-compose package when it is installed.
"""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1]
MOCK = r'''
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
record = {"tool": name, "args": args, "cwd": os.getcwd(),
          "env": {key: os.environ.get(key) for key in
                  ("SAGE_TAG", "PORT", "CONTAINER_NAME", "SAGEPOD_NETWORK_MODE")}}
if name == "podman" and args and (args[0] == "unshare" or args[:2] == ["exec", "-i"]):
    record["stdin"] = sys.stdin.read()
with open(os.environ["TEST_LOG"], "a") as stream:
    stream.write(json.dumps(record) + "\n")

fail = os.environ.get("TEST_FAIL")
if (name == "podman" and args and args[0] == fail) or (name == "podman-compose" and fail == "compose" and "up" in args):
    sys.exit(17)
if name == "id":
    print(os.environ.get("TEST_UID", "1000"))
elif name == "podman":
    state = Path(os.environ["TEST_IMAGE"])
    if args[:2] == ["image", "exists"]:
        sys.exit(0 if state.exists() else 1)
    if args and args[0] == "build":
        state.touch()
    if args and args[0] == "logs":
        print("http://localhost:8888/tree?token=abc123", file=sys.stderr)
    if args[:1] == ["unshare"] and os.environ.get("TEST_REAL_PERMISSIONS"):
        sys.exit(subprocess.run(args[1:], input=record["stdin"], text=True).returncode)
elif name == "setfacl" and os.environ.get("TEST_REAL_PERMISSIONS"):
    # Map namespace root to this process's UID, including in restricted sandboxes.
    mapped = [arg.replace("u:0:", f"u:{os.getuid()}:") for arg in args]
    sys.exit(subprocess.run([os.environ["TEST_SETFACL"], *mapped]).returncode)
elif name in ("python", "python3", "test-python"):
    if args[:2] == ["-m", "venv"]:
        venv = Path(args[2])
        (venv / "bin").mkdir(parents=True)
        for executable in ("python", "podman-compose"):
            shutil.copy2(__file__, venv / "bin" / executable)
    if args[:3] == ["-m", "pip", "install"] and fail == "pip":
        sys.exit(18)
    if args[:3] == ["-m", "pip", "check"] and os.environ.get("TEST_BROKEN_VENV"):
        marker = Path(os.environ["TEST_BROKEN_VENV"])
        if marker.exists():
            marker.unlink()
            sys.exit(1)
elif name == "podman-compose" and "--version" in args:
    print("podman-compose version: test")
'''


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="sagepod setup ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "checkout with spaces"
        shutil.copytree(SOURCE, self.repo, ignore=shutil.ignore_patterns(
            ".git", ".venv", "__pycache__"))
        self.home = self.root / "home with spaces"
        self.home.mkdir()
        self.mockbin = self.root / "mockbin"
        self.mockbin.mkdir()
        self.log = self.root / "commands.jsonl"
        self.image = self.root / "image-present"
        self.env = {k: v for k, v in os.environ.items() if k not in
                    ("SAGE_TAG", "PORT", "CONTAINER_NAME", "SAGEPOD_NETWORK_MODE",
                     "PODMAN_COMPOSE", "IMAGE", "VIRTUAL_ENV", "PYTHONPATH")}
        self.env.update(HOME=str(self.home), PATH=f"{self.mockbin}:/usr/bin:/bin",
                        TEST_LOG=str(self.log), TEST_IMAGE=str(self.image))
        for command in ("podman", "id", "python3", "setfacl", "test-python"):
            self.make_mock(self.mockbin / command)

    def make_mock(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"#!{sys.executable}\n" + MOCK)
        path.chmod(0o755)

    def local_compose(self):
        self.make_mock(self.repo / ".venv/bin/podman-compose")
        self.make_mock(self.repo / ".venv/bin/python")

    def run_script(self, script, *args, success=True, **env):
        result = subprocess.run([str(self.repo / script), *args], cwd=self.root,
                                env=self.env | env, capture_output=True, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def calls(self, tool=None):
        rows = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        return [row for row in rows if tool is None or row["tool"] == tool]

    def test_clean_setup_needs_only_this_checkout(self):
        result = self.run_script("bin/setup.sh")
        self.assertIn("http://localhost:8889/tree?token=abc123", result.stdout)
        self.assertFalse((self.home / "src/sagequeue").exists())
        calls = self.calls()
        self.assertNotIn("sagequeue", json.dumps(calls))
        permissions = next(c for c in calls if c["args"][:1] == ["unshare"])
        expected = ["Jupyter", ".jupyter", ".sagepod-dot_sage", ".sagepod-local", ".sagepod-config", ".sagepod-cache"]
        self.assertEqual(permissions["args"][4:], [str(self.home / p) for p in expected])
        self.assertTrue(all((self.home / p).is_dir() for p in expected))
        build = next(i for i, c in enumerate(calls) if c["args"][:1] == ["build"])
        self.assertIn("SAGE_TAG=10.10", calls[build]["args"])
        self.assertIn("localhost/sagepod-sagemath:10.10-pycryptosat", calls[build]["args"])
        up = next(i for i, c in enumerate(calls) if c["tool"] == "podman-compose" and "up" in c["args"])
        check = next(i for i, c in enumerate(calls) if c["args"][:2] == ["exec", "-i"])
        self.assertLess(build, up)
        self.assertLess(up, check)
        compile(calls[check]["stdin"], "verify-stdin", "exec")
        self.assertEqual(calls[up]["cwd"], str(self.repo))

    def test_repeated_setup_preserves_data_and_reuses_tools(self):
        self.run_script("bin/setup.sh")
        notebook = self.home / "Jupyter/keep.ipynb"
        notebook.write_text("existing notebook")
        self.run_script("bin/setup.sh")
        self.assertEqual(notebook.read_text(), "existing notebook")
        self.assertEqual(sum(c["args"][:1] == ["build"] for c in self.calls("podman")), 1)
        self.assertEqual(sum(c["args"][:2] == ["-m", "venv"] for c in self.calls()), 1)
        self.assertFalse(list(self.home.rglob(".sagepod-host-check.*")))

    @unittest.skipUnless(shutil.which("setfacl"), "Install acl to test inherited permission masks")
    def test_permission_repair_preserves_execute_status_with_inherited_acls(self):
        # Run the helper's real ACL/chmod operations. Namespace entry, UID mapping,
        # and ownership changes are substituted, so no subordinate IDs are needed.
        setfacl = shutil.which("setfacl")
        self.make_mock(self.mockbin / "chown")
        files = []
        for name in ("Jupyter", ".jupyter", ".sagepod-dot_sage", ".sagepod-local",
                     ".sagepod-config", ".sagepod-cache"):
            mount = self.home / name
            mount.mkdir()
            subprocess.run([setfacl, "-m",
                f"d:u::rwx,d:u:{os.getuid()}:rwx,d:g::rwx,d:m::rwx,d:o::---",
                str(mount)], check=True)
            nested = mount / "nested"
            nested.mkdir(mode=0o700)
            for filename, mode in (("data", 0o600), ("executable", 0o700)):
                path = nested / filename
                path.write_text("preserve contents\n")
                path.chmod(mode)
                files.append((path, bool(mode & stat.S_IXUSR)))
        for _ in range(2):
            self.run_script("bin/fix-bind-mounts.sh", TEST_REAL_PERMISSIONS="1",
                            TEST_SETFACL=setfacl)
            for path, executable in files:
                with self.subTest(path=path, executable=executable):
                    self.assertEqual(path.read_text(), "preserve contents\n")
                    self.assertEqual(bool(path.stat().st_mode & 0o111), executable)

    def test_overrides_reach_builder_compose_and_verifier(self):
        result = self.run_script("bin/setup.sh", SAGE_TAG="10.8", PORT="8890",
                                 CONTAINER_NAME="sagepod-test", SAGEPOD_NETWORK_MODE="host")
        self.assertIn("localhost:8890", result.stdout)
        build = next(c for c in self.calls("podman") if c["args"][:1] == ["build"])
        self.assertIn("SAGE_TAG=10.8", build["args"])
        self.assertIn("localhost/sagepod-sagemath:10.8-pycryptosat", build["args"])
        self.assertEqual(build["args"][1:3], ["--network", "host"])
        compose = next(c for c in self.calls("podman-compose") if "up" in c["args"])
        self.assertEqual(compose["env"]["SAGE_TAG"], "10.8")
        self.assertEqual(compose["env"]["CONTAINER_NAME"], "sagepod-test")
        verify = next(c for c in self.calls("podman") if c["args"][:2] == ["exec", "-i"])
        self.assertEqual(verify["args"][2], "sagepod-test")

    def test_build_does_not_need_compose_or_restart_containers(self):
        self.run_script("bin/build-image.sh", "--sage-tag", "10.10", SAGE_TAG="10.8")
        calls = self.calls()
        self.assertFalse(any(c["tool"] == "podman-compose" for c in calls))
        self.assertFalse(any(c["args"][:1] in (["rm"], ["stop"], ["exec"]) for c in calls))
        build = next(c for c in calls if c["args"][:1] == ["build"])
        self.assertIn("SAGE_TAG=10.10", build["args"])

    def test_failed_build_does_not_start_or_remove_container(self):
        self.local_compose()
        self.run_script("man-up.sh", "--no-follow", success=False, TEST_FAIL="build")
        self.assertFalse(self.calls("podman-compose"))
        self.assertFalse(any(c["args"][:1] == ["rm"] for c in self.calls("podman")))

    def test_permission_failure_stops_setup_before_install_or_start(self):
        self.run_script("bin/setup.sh", success=False, TEST_FAIL="unshare")
        self.assertFalse(self.calls("podman-compose"))
        self.assertFalse(any(c["args"][:1] == ["build"] for c in self.calls("podman")))
        self.assertFalse((self.repo / ".venv").exists())

    def test_failed_dependency_install_stops_setup(self):
        self.run_script("bin/setup.sh", success=False, TEST_FAIL="pip")
        self.assertFalse(any("up" in c["args"] for c in self.calls("podman-compose")))
        self.assertFalse(any(c["args"][:1] == ["build"] for c in self.calls("podman")))

    def test_broken_venv_is_rebuilt(self):
        self.local_compose()
        marker = self.root / "broken-once"
        marker.touch()
        self.run_script("bin/setup.sh", TEST_BROKEN_VENV=str(marker))
        self.assertEqual(sum(c["args"][:2] == ["-m", "venv"] for c in self.calls()), 1)

    def test_verify_failure_is_reported_as_startup_failure(self):
        self.local_compose()
        self.image.touch()
        result = self.run_script("man-up.sh", "--no-follow", success=False, TEST_FAIL="exec")
        self.assertNotIn("Jupyter:", result.stdout)
        self.assertFalse(any(c["args"][:1] == ["logs"] for c in self.calls("podman")))

    def test_compose_failure_is_reported(self):
        self.local_compose()
        self.image.touch()
        self.run_script("man-up.sh", "--no-follow", success=False, TEST_FAIL="compose")
        self.assertFalse(any(c["args"][:1] == ["exec"] for c in self.calls("podman")))

    def test_local_compose_precedes_path_fallback(self):
        self.local_compose()
        path_compose = self.mockbin / "podman-compose"
        path_compose.write_text("#!/bin/sh\nexit 97\n")
        path_compose.chmod(0o755)
        self.run_script("man-down.sh")
        self.assertEqual(self.calls("podman-compose")[0]["args"][-1], "down")

    def test_path_compose_fallback_and_existing_image(self):
        self.make_mock(self.mockbin / "podman-compose")
        self.image.touch()
        self.run_script("man-up.sh", "--no-follow")
        self.assertFalse(any(c["args"][:1] == ["build"] for c in self.calls("podman")))

    def test_missing_compose_points_to_local_repair(self):
        result = self.run_script("man-down.sh", success=False)
        self.assertIn(str(self.repo / "bin/venvfix.sh"), result.stderr)
        self.assertNotIn("sagequeue", result.stderr)

    def test_venv_repair_preserves_scripts_and_legacy_files(self):
        sentinel = self.repo / "bin/keep.sh"
        sentinel.write_text("keep")
        legacy = self.repo / "lib/keep"
        legacy.parent.mkdir()
        legacy.write_text("keep")
        unrelated = self.root / ".venv/keep"
        unrelated.parent.mkdir()
        unrelated.write_text("keep")
        self.run_script("venvfix.sh", "test-python")
        self.assertEqual(sentinel.read_text(), "keep")
        self.assertEqual(legacy.read_text(), "keep")
        self.assertEqual(unrelated.read_text(), "keep")
        self.assertTrue((self.repo / "bin/setup.sh").exists())
        self.assertTrue((self.repo / ".venv/bin/podman-compose").is_file())

    def test_all_helpers_use_the_sagepod_container(self):
        self.run_script("run-bash.sh", "-c", "echo test")
        self.run_script("check_cryptominisat_version.sh")
        self.run_script("bin/verify.sh")
        for call in self.calls("podman"):
            args = call["args"]
            if args[:1] == ["exec"]:
                self.assertIn("sagepod", args)
                self.assertNotIn("sagemath", args)

    def test_root_is_rejected_before_host_changes(self):
        self.run_script("bin/setup.sh", success=False, TEST_UID="0")
        self.assertFalse(self.calls("podman"))
        self.assertFalse((self.home / "Jupyter").exists())

    def test_invalid_arguments_fail_before_actions(self):
        for script, args in [("bin/build-image.sh", ["--sage-tag"]),
                             ("man-up.sh", ["--typo"]),
                             ("man-down.sh", ["--typo"]),
                             ("bin/setup.sh", ["--typo"]),
                             ("bin/venvfix.sh", ["python3", "extra"])]:
            with self.subTest(script=script):
                self.run_script(script, *args, success=False)
        self.assertFalse(self.calls())


@unittest.skipUnless(importlib.util.find_spec("podman_compose"),
                     "Install requirements.txt to test real Compose rendering")
class ComposeTests(unittest.TestCase):
    def test_default_and_custom_configuration(self):
        import yaml
        for overrides, tag, port, container in [({}, "10.10", "8889", "sagepod"),
                ({"SAGE_TAG": "10.8", "PORT": "8890", "CONTAINER_NAME": "sagepod-test"},
                 "10.8", "8890", "sagepod-test")]:
            with self.subTest(tag=tag), tempfile.TemporaryDirectory() as directory:
                env = {k: v for k, v in os.environ.items() if k not in
                       ("SAGE_TAG", "PORT", "CONTAINER_NAME", "SAGEPOD_NETWORK_MODE")}
                env.update(HOME=directory, **overrides)
                result = subprocess.run([sys.executable, "-m", "podman_compose", "--dry-run",
                    "-p", "sagepod", "-f", str(SOURCE / "podman-compose.yml"), "config"],
                    cwd=directory, env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                config = yaml.safe_load(result.stdout)
                service = config["services"]["sagemath"]
                self.assertEqual(service["image"], f"localhost/sagepod-sagemath:{tag}-pycryptosat")
                self.assertEqual(service["container_name"], container)
                self.assertEqual(service["ports"], [f"{port}:8888"])
                self.assertEqual(len(service["volumes"]), 6)
                self.assertIn(f"{directory}/.sagepod-local:/home/sage/.local:Z,U", service["volumes"])
                self.assertNotIn("sagequeue", result.stdout)


if __name__ == "__main__":
    unittest.main()
