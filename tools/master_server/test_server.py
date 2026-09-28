import hashlib
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
import http.client
import json
import ipaddress
import os
from pathlib import Path
import subprocess
import socket
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

from server import Directory, LEASE_SECONDS, LocalDiscovery, MAX_SERVERS, Server, WIRE, local_query_endpoints, validate_status

TOKEN = "ab" * 32


def status():
    return dict(name="Test arena", map="qsrc_dm1", map_title="The Place", protocol="test-1",
                version="test", mode="dm", weapon_rules="doom", state="match", game_port=27777,
                capacity=8, humans=2, spectators=1, bots=5, reserved=2, open_slots=3)


class DirectoryTests(unittest.TestCase):
    def test_deferred_tribes_mode_and_arsenal_rejected(self):
        row = status()
        row.update(mode="st", weapon_rules="tribes", map="ctf_stonehenge")
        with self.assertRaises(ValueError):
            validate_status(row)
        row.update(mode="dm")
        with self.assertRaises(ValueError):
            validate_status(row)


    def setUp(self):
        self.now = 100.0
        self.probes = []

        def probe(address, port):
            self.probes.append((address, port))
            return status()

        self.directory = Directory({"arena": hashlib.sha256(TOKEN.encode()).hexdigest()},
                                   clock=lambda: self.now, probe=probe)

    def test_verified_registration_and_expiry(self):
        self.directory.heartbeat("arena", "8.8.8.8", {"game_port": 27777, "query_port": 27779})
        row = self.directory.listing()["servers"][0]
        self.assertEqual(self.probes, [("8.8.8.8", 27779)])
        self.assertEqual(row["open_slots"], 3)  # Five bots can yield; downloads already reserve seats.
        self.now += LEASE_SECONDS - 1
        self.assertEqual(len(self.directory.listing()["servers"]), 1)
        self.now += 1
        self.assertEqual(self.directory.listing()["servers"], [])

    def test_replacement_renewal_and_tokens(self):
        self.assertEqual(self.directory.authenticate(TOKEN), "arena")
        self.assertIsNone(self.directory.authenticate("cd" * 32))
        self.directory.heartbeat("arena", "8.8.8.8", {"game_port": 27777, "query_port": 27779})
        self.now += 80
        self.directory.heartbeat("arena", "1.1.1.1", {"game_port": 27777, "query_port": 27779})
        self.now += 20
        rows = self.directory.listing()["servers"]
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["address"], "1.1.1.1")

    def test_no_arbitrary_probe_targets(self):
        for ip in ["127.0.0.1", "::1", "10.1.2.3", "169.254.169.254", "224.0.0.1"]:
            with self.assertRaises(ValueError):
                self.directory.heartbeat("arena", ip, {"game_port": 27777, "query_port": 27779})
        with self.assertRaises(ValueError):
            self.directory.heartbeat("arena", "8.8.8.8", {"game_port": 27777, "query_port": 27779, "address": "10.0.0.1"})
        self.assertEqual(self.probes, [])

    def test_failed_probe_does_not_renew(self):
        self.directory.heartbeat("arena", "8.8.8.8", {"game_port": 27777, "query_port": 27779})
        self.now += 80

        def failed(*_args):
            raise OSError("unreachable")

        self.directory.probe = failed
        with self.assertRaises(OSError):
            self.directory.heartbeat("arena", "8.8.8.8", {"game_port": 27777, "query_port": 27779})
        self.now += 10
        self.assertEqual(self.directory.listing()["servers"], [])

    def test_schema_and_public_field_allowlist(self):
        row = status()
        row["rcon_password"] = "private"
        self.assertNotIn("rcon_password", validate_status(row))
        for key, value in [("humans", -1), ("capacity", 33), ("open_slots", 8), ("bots", 32),
                           ("name", "x\nforged log"), ("protocol", "x" * 81), ("game_port", True), ("reserved", 1.2)]:
            row = status()
            row[key] = value
            with self.assertRaises(ValueError, msg=key):
                validate_status(row)

    def test_rate_limit_expires(self):
        self.assertTrue(self.directory.permit("client", 1, 60))
        self.assertFalse(self.directory.permit("client", 1, 60))
        self.now += 60
        self.assertTrue(self.directory.permit("client", 1, 60))

    def test_local_status_refresh_version_and_expiry(self):
        self.directory.local_status("8.8.8.8", 27779, status())
        row = dict(status(), version="new-build", humans=3, bots=4, open_slots=2)
        self.now += 80
        self.directory.local_status("8.8.8.8", 27779, row)
        self.now += 20
        listing = self.directory.listing()["servers"]
        self.assertEqual(len(listing), 1)
        self.assertEqual(listing[0]["version"], "new-build")
        self.assertEqual(listing[0]["humans"], 3)
        self.assertEqual(listing[0]["age_seconds"], 20)
        self.assertEqual(listing[0]["source"], "local")
        self.now += LEASE_SECONDS
        self.assertEqual(self.directory.listing()["servers"], [])

    def test_local_and_authenticated_discovery_deduplicate_both_orders(self):
        for local_first in (True, False):
            self.directory.rows.clear()
            if local_first:
                self.directory.local_status("8.8.8.8", 27779, status())
            self.directory.heartbeat("arena", "8.8.8.8", {"game_port": 27777, "query_port": 27779})
            self.directory.local_status("8.8.8.8", 27779, status())
            rows = self.directory.listing()["servers"]
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["id"], "arena")

    def test_local_validation_and_capacity(self):
        for port in (0, 27777, 65536):
            with self.assertRaises(ValueError):
                self.directory.local_status("127.0.0.1", port, status())
        with self.assertRaises(ValueError):
            self.directory.local_status("127.0.0.1", 27779, dict(status(), version=""))
        for offset in range(MAX_SERVERS):
            self.directory.local_status("127.0.0.1", 30000 + offset, status())
        with self.assertRaises(ValueError):
            self.directory.local_status("127.0.0.1", 31000, status())
        self.directory.local_status("127.0.0.1", 30000, dict(status(), version="updated"))
        self.assertEqual(len(self.directory.listing()["servers"]), MAX_SERVERS)


class QueryResponder:
    """Real UDP cookie exchange, with mutable game metadata."""
    def __init__(self, game_port):
        self.status = dict(status(), game_port=game_port)
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.bind(("127.0.0.1", 0))
        self.socket.settimeout(.1)
        self.port = self.socket.getsockname()[1]
        self.stopped = threading.Event()
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def run(self):
        while not self.stopped.is_set():
            try:
                raw, address = self.socket.recvfrom(1201)
            except socket.timeout:
                continue
            request = json.loads(raw)
            if request.get("wire") != WIRE:
                continue
            response = dict(wire=WIRE, nonce=request["nonce"])
            if request["kind"] == "hello":
                response.update(kind="challenge", cookie="ab" * 32)
            elif request.get("cookie") == "ab" * 32:
                response.update(kind="status", status=self.status)
            else:
                continue
            self.socket.sendto(json.dumps(response).encode(), address)

    def close(self):
        self.stopped.set()
        self.thread.join(timeout=2)
        self.socket.close()


class DiscoveryTests(unittest.TestCase):
    def test_tokenless_cli_discovers_games_and_serves_dashboard(self):
        game = QueryResponder(27777)
        self.addCleanup(game.close)
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            ready = folder / "ready"
            with (folder / "master.log").open("w+") as log:
                process = subprocess.Popen([
                    sys.executable, str(Path(__file__).with_name("server.py")),
                    "--port", "0", "--allow-loopback", "--parent-pid", str(os.getpid()),
                    "--ready-file", str(ready), "--local-query-ports", str(game.port)],
                    stdout=log, stderr=subprocess.STDOUT)
                try:
                    deadline = time.monotonic() + 10
                    found = False
                    while process.poll() is None and time.monotonic() < deadline:
                        if ready.exists() and ready.read_text():
                            with closing(http.client.HTTPConnection("127.0.0.1", int(ready.read_text()), timeout=2)) as connection:
                                connection.request("GET", "/v1/servers")
                                response = connection.getresponse()
                                data = json.loads(response.read())
                                found = any(row["game_port"] == 27777 and row["query_port"] == game.port
                                            and row["version"] == "test" for row in data.get("servers", []))
                            if found:
                                break
                        time.sleep(.25)
                    log.flush(); log.seek(0)
                    self.assertTrue(found, log.read())
                    with closing(http.client.HTTPConnection("127.0.0.1", int(ready.read_text()), timeout=2)) as connection:
                        connection.request("GET", "/")
                        response = connection.getresponse()
                        self.assertEqual(response.status, 200)
                        self.assertIn(b"Live servers", response.read())
                finally:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill(); process.wait(timeout=5)

    def test_linux_socket_table_decoding(self):
        def encoded(address):
            packed = ipaddress.ip_address(address).packed
            return "".join(f"{int.from_bytes(packed[i:i + 4], sys.byteorder):08X}" for i in range(0, len(packed), 4))

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "udp").write_text("header\n" + "\n".join([
                f"1: {encoded('0.0.0.0')}:6C83 00000000:0000 07",
                f"2: {encoded('192.168.1.2')}:6C84 00000000:0000 07",
                f"3: {encoded('127.0.0.1')}:6C85 {encoded('8.8.8.8')}:0035 01",
                f"4: {encoded('127.0.0.1')}:0035 00000000:0000 07",
                "bad line"]))
            (root / "udp6").write_text(f"header\n1: {encoded('::')}:6C86 {'0' * 32}:0000 07\n"
                                       f"2: {encoded('::1')}:6C87 {'0' * 32}:0000 07\n")
            self.assertEqual(local_query_endpoints(root), {
                ("127.0.0.1", 7779), ("::1", 7779), ("127.0.0.1", 27779),
                ("192.168.1.2", 27780), ("::1", 27782), ("::1", 27783)})
        self.assertEqual(local_query_endpoints(Path("/nonexistent/proc")), {("127.0.0.1", 7779), ("::1", 7779)})

    def test_real_udp_discovery_multiple_games_refresh_and_failure(self):
        games = [QueryResponder(27777), QueryResponder(27787)]
        for game in games:
            self.addCleanup(game.close)
        endpoints = {("127.0.0.1", game.port) for game in games}
        if sys.platform.startswith("linux"):
            self.assertTrue(endpoints.issubset(local_query_endpoints()))
        now = [100.0]
        directory = Directory({}, clock=lambda: now[0])
        scanner = LocalDiscovery(directory, "8.8.8.8", discover=lambda: endpoints)
        with ThreadPoolExecutor(max_workers=2) as workers:
            scanner.scan(workers)
            rows = directory.listing()["servers"]
            self.assertEqual({row["game_port"] for row in rows}, {27777, 27787})
            self.assertTrue(all(row["address"] == "8.8.8.8" and row["version"] == "test" for row in rows))
            games[0].status = dict(games[0].status, version="0.99", humans=3, bots=4, open_slots=2)
            now[0] += 10
            scanner.scan(workers)
            changed = next(row for row in directory.listing()["servers"] if row["game_port"] == 27777)
            self.assertEqual((changed["version"], changed["humans"], changed["open_slots"]), ("0.99", 3, 2))
            # Malformed and unreachable endpoints must not replace or renew rows.
            games[0].status = dict(games[0].status, version="")
            now[0] += LEASE_SECONDS
            scanner.scan(workers)
            self.assertEqual([row["game_port"] for row in directory.listing()["servers"]], [27787])
            with patch("server.query_status", side_effect=OSError("offline")):
                now[0] += LEASE_SECONDS
                scanner.scan(workers)
            self.assertEqual(directory.listing()["servers"], [])

    def test_explicit_ports_and_bounded_rotating_scans(self):
        scanner = LocalDiscovery(Directory({}), "127.0.0.1", ports=[17779], discover=lambda: set())
        with ThreadPoolExecutor(max_workers=1) as workers, patch.object(scanner, "probe") as probe:
            scanner.scan(workers)
            self.assertEqual({call.args[0] for call in probe.call_args_list}, {("127.0.0.1", 17779), ("::1", 17779)})
            endpoints = {("127.0.0.1", port) for port in range(20000, 21000)}
            scanner.discover = lambda: endpoints
            scanner.ports = []
            probe.reset_mock()
            scanner.scan(workers)
            self.assertEqual(probe.call_count, 512)
            scanner.scan(workers)
            self.assertEqual({call.args[0] for call in probe.call_args_list}, endpoints)


class HTTPTests(unittest.TestCase):
    def setUp(self):
        self.directory = Directory({"arena": hashlib.sha256(TOKEN.encode()).hexdigest()},
                                   allow_loopback=True, probe=lambda *_: status())
        self.server = Server(("127.0.0.1", 0), self.directory)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def request(self, method, path, body=None, token=TOKEN, extra=None):
        headers = {"Authorization": "Bearer " + token, **(extra or {})}
        with closing(http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=3)) as connection:
            connection.request(method, path, json.dumps(body) if body is not None else None, headers)
            response = connection.getresponse()
            return response.status, json.loads(response.read())

    def test_round_trip_and_source_header_not_trusted(self):
        code, _ = self.request("POST", "/v1/heartbeat", {"game_port": 27777, "query_port": 27779}, extra={"X-Real-IP": "8.8.8.8"})
        self.assertEqual(code, 200)
        code, rows = self.request("GET", "/v1/servers")
        self.assertEqual(code, 200)
        self.assertEqual(rows["servers"][0]["address"], "127.0.0.1")
        self.assertNotIn(TOKEN, json.dumps(rows))

    def test_auth_and_malformed_requests(self):
        self.assertEqual(self.request("POST", "/v1/heartbeat", {}, token="00" * 32)[0], 401)
        self.assertEqual(self.request("POST", "/v1/heartbeat", {"game_port": 7777})[0], 400)
        self.assertEqual(self.request("POST", "/v1/heartbeat", "x" * 1100)[0], 400)
        self.assertEqual(self.request("GET", "/missing")[0], 404)
        self.assertEqual(self.directory.listing()["servers"], [])

    def test_dashboard_assets_and_path_allowlist(self):
        for path, mime, snippet in [("/", "text/html", b"Live servers"),
                                    ("/index.html", "text/html", b"dashboard.js"),
                                    ("/dashboard.js", "text/javascript", b'fetch("v1/servers"'),
                                    ("/dashboard.css", "text/css", b"@media")]:
            with closing(http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=3)) as connection:
                connection.request("GET", path)
                response = connection.getresponse()
                body = response.read()
                self.assertEqual(response.status, 200)
                self.assertTrue(response.getheader("Content-Type").startswith(mime))
                self.assertEqual(int(response.getheader("Content-Length")), len(body))
                self.assertEqual(response.getheader("X-Content-Type-Options"), "nosniff")
                self.assertIn(snippet, body)
                self.assertNotIn(TOKEN.encode(), body)
        for path in ("/../server.py", "/%2e%2e/server.py", "/tokens.json", "/server.py"):
            self.assertEqual(self.request("GET", path)[0], 404)

    def test_tokenless_local_listing_does_not_allow_remote_registration(self):
        self.directory.tokens.clear()
        self.directory.local_status("127.0.0.1", 27779, status())
        code, body = self.request("GET", "/v1/servers")
        self.assertEqual(code, 200)
        self.assertEqual(body["servers"][0]["version"], "test")
        self.assertEqual(self.request("POST", "/v1/heartbeat", {"game_port": 27777, "query_port": 27779})[0], 401)


class CredentialTests(unittest.TestCase):
    def test_issue_without_disclosure_or_overwrite(self):
        with tempfile.TemporaryDirectory(prefix="fpsloppa-token-test-") as temporary:
            folder = Path(temporary)
            registry, environment = folder / "tokens.json", folder / "server.env"
            command = [sys.executable, str(Path(__file__).with_name("issue_token.py")), "arena",
                       "--tokens", str(registry), "--env-file", str(environment)]
            result = subprocess.run(command, capture_output=True, text=True, check=True)
            token = environment.read_text().strip().split("=", 1)[1]
            self.assertEqual(json.loads(registry.read_text())["arena"], hashlib.sha256(token.encode()).hexdigest())
            self.assertNotIn(token, result.stdout + result.stderr)
            self.assertEqual(environment.stat().st_mode & 0o777, 0o600)
            before = environment.read_bytes(), registry.read_bytes()
            repeated = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(repeated.returncode, 0)
            self.assertEqual(before, (environment.read_bytes(), registry.read_bytes()))


if __name__ == "__main__":
    unittest.main()
