"""Read and check Jupyter's current server information inside the container."""

import argparse
import json
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener

CONTAINER_PORT = 8888


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Never forward a login token to a redirect target.
        return None


def server_url(info, host, port, path):
    scheme = "https" if info.get("secure") else "http"
    base = "/" + info.get("base_url", "/").strip("/")
    path = quote(base.rstrip("/") + "/" + path, safe="/%")
    return f"{scheme}://{host}:{port}{path}"


def probe_server(info, timeout=2):
    """Reject stale tokens; report password-only servers without guessing a password."""
    token = info.get("token", "")
    headers = {"Authorization": "token " + token} if token else {}
    url = server_url(info, "127.0.0.1", info["port"], "api/status")
    opener = build_opener(ProxyHandler({}), NoRedirect())
    try:
        with opener.open(Request(url, headers=headers), timeout=timeout) as response:
            model = json.load(response)
        if isinstance(model, dict) and {"started", "last_activity", "kernels", "connections"} <= model.keys():
            return "token" if token else "no-token"
    except HTTPError as error:
        if error.code in (401, 403) and not token and info.get("password"):
            return "password"
    except (OSError, URLError, ValueError):
        pass
    return None


def login_url(host_port, wait=30):
    from jupyter_server.serverapp import list_running_servers

    deadline = time.monotonic() + wait
    while True:
        verified = set()
        password_urls = set()
        try:
            servers = list(list_running_servers())
        except (OSError, ValueError):
            servers = []  # A server can still be writing its runtime file.
        for info in servers:
            if info.get("port") != CONTAINER_PORT or info.get("sock"):
                continue
            timeout = 2 if wait == 0 else max(0.1, min(2, deadline - time.monotonic()))
            mode = probe_server(info, timeout=timeout)
            if mode is None:
                continue
            url = server_url(info, "localhost", host_port, "tree")
            if info.get("token"):
                url += "?" + urlencode({"token": info["token"]})
            if mode == "password":
                password_urls.add(url)
            else:
                verified.add(url)
        candidates = verified or password_urls
        if len(candidates) == 1:
            if not verified:
                print("Jupyter requires its configured password; no login token is active.", file=sys.stderr)
            return candidates.pop()
        if len(candidates) > 1:
            raise RuntimeError("Multiple Jupyter login URLs were found; inspect the running servers.")
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError(
                "No responding Jupyter server with usable login information was found on container port 8888. "
                "Check the container logs and retry bin/jupyter-url.sh."
            )
        time.sleep(min(1, remaining))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", required=True, type=int)
    parser.add_argument("--wait", default=30, type=int)
    args = parser.parse_args()
    if not 1 <= args.port <= 65535 or args.wait < 0:
        parser.error("port must be between 1 and 65535; wait must be nonnegative")
    try:
        print(login_url(args.port, args.wait))
    except (ImportError, RuntimeError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
