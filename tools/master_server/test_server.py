import hashlib
from contextlib import closing
import http.client
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest

from server import Directory, LEASE_SECONDS, Server, validate_status

TOKEN = "ab" * 32


def status():
    return dict(name="Test arena", map="qsrc_dm1", map_title="The Place", protocol="test-1",
                version="test", mode="dm", weapon_rules="doom", state="match", game_port=27777,
                capacity=8, humans=2, spectators=1, bots=5, reserved=2, open_slots=3)


class DirectoryTests(unittest.TestCase):
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
