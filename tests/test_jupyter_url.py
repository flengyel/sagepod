"""Check login URL discovery against an HTTP server that enforces a token."""

from contextlib import redirect_stderr
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import io
import json
from pathlib import Path
import sys
import threading
from types import ModuleType
import unittest
from unittest.mock import Mock, patch
from urllib.parse import parse_qs, urlsplit


SPEC = importlib.util.spec_from_file_location(
    "jupyter_url", Path(__file__).resolve().parents[1] / "bin/jupyter_url.py"
)
URL_HELPER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(URL_HELPER)


class LoginURLTests(unittest.TestCase):
    def setUp(self):
        self.token = "fresh.Token+/='"
        self.requests = []
        self.redirect = False
        self.invalid_json = False
        test = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                test.requests.append((self.path, self.headers.get("Authorization")))
                if test.redirect:
                    self.send_response(302)
                    self.send_header("Location", "/different-server")
                    self.end_headers()
                    return
                if self.headers.get("Authorization") != "token " + test.token:
                    self.send_response(403)
                    self.end_headers()
                    return
                self.send_response(200)
                self.end_headers()
                model = {"started": "2026-10-30T12:00:00Z", "last_activity": "2026-10-30T12:00:00Z",
                         "kernels": 0, "connections": 0}
                self.wfile.write(b"<html>Login</html>" if test.invalid_json else json.dumps(model).encode())

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(thread.join)
        self.addCleanup(self.server.shutdown)
        self.info = {"port": self.server.server_port, "base_url": "/", "secure": False,
                     "token": self.token, "password": False, "pid": 1}
        serverapp = ModuleType("jupyter_server.serverapp")
        self.list_servers = serverapp.list_running_servers = Mock(return_value=[self.info])
        modules = {"jupyter_server": ModuleType("jupyter_server"), "jupyter_server.serverapp": serverapp}
        self.modules = patch.dict(sys.modules, modules)
        self.modules.start()
        self.addCleanup(self.modules.stop)
        port = patch.object(URL_HELPER, "CONTAINER_PORT", self.server.server_port)
        port.start()
        self.addCleanup(port.stop)

    def test_current_token_is_checked_and_url_encoded_on_localhost(self):
        url = URL_HELPER.login_url(8889, wait=0)
        parsed = urlsplit(url)
        self.assertEqual(parsed.netloc, "localhost:8889")
        self.assertEqual(parsed.path, "/tree")
        self.assertEqual(parse_qs(parsed.query), {"token": [self.token]})
        self.assertNotIn("'", url)
        self.assertEqual(self.requests, [("/api/status", "token " + self.token)])

    def test_stale_runtime_token_is_rejected_in_favor_of_current_token(self):
        self.list_servers.return_value = [self.info | {"token": "obsolete"}, self.info]
        url = URL_HELPER.login_url(9010, wait=0)
        self.assertEqual(parse_qs(urlsplit(url).query), {"token": [self.token]})
        self.assertEqual([auth for _, auth in self.requests], ["token obsolete", "token " + self.token])

    def test_rejected_token_never_produces_a_login_url(self):
        self.list_servers.return_value = [self.info | {"token": "obsolete"}]
        with self.assertRaisesRegex(RuntimeError, "No responding Jupyter server"):
            URL_HELPER.login_url(8889, wait=0)

    def test_waits_for_server_information(self):
        self.list_servers.side_effect = [[], [self.info]]
        with patch.object(URL_HELPER.time, "sleep") as sleep:
            url = URL_HELPER.login_url(8889, wait=2)
        self.assertIn("localhost:8889", url)
        sleep.assert_called_once()

    def test_password_only_server_reports_password_instead_of_old_token(self):
        self.list_servers.return_value = [self.info | {"token": "", "password": True}]
        error = io.StringIO()
        with redirect_stderr(error):
            url = URL_HELPER.login_url(8889, wait=0)
        self.assertEqual(url, "http://localhost:8889/tree")
        self.assertIn("configured password", error.getvalue())

    def test_base_url_is_preserved_and_proxy_environment_is_ignored(self):
        self.info["base_url"] = "/sage/"
        with patch.dict("os.environ", {"http_proxy": "http://127.0.0.1:1", "no_proxy": ""}):
            url = URL_HELPER.login_url(8890, wait=0)
        self.assertEqual(urlsplit(url).path, "/sage/tree")
        self.assertEqual(self.requests[0][0], "/sage/api/status")

    def test_redirect_does_not_forward_the_token(self):
        self.redirect = True
        self.assertIsNone(URL_HELPER.probe_server(self.info))
        self.assertEqual(len(self.requests), 1)

    def test_html_response_is_not_accepted_as_authenticated_status(self):
        self.invalid_json = True
        self.assertIsNone(URL_HELPER.probe_server(self.info))


if __name__ == "__main__":
    unittest.main()
