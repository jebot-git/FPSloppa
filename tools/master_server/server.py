#!/usr/bin/env python3
"""Small FPSloppa directory. Run behind HTTPS; only numeric loopback permits HTTP."""
import argparse
import hashlib
import hmac
import ipaddress
import json
import os
import re
import secrets
import socket
import ssl
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

WIRE = "fpsloppa-query-1"
MAX_PACKET = 1200
MAX_SERVERS = 256
LEASE_SECONDS = 90
MODES = {"dm", "tdm", "ctf", "koth", "ig", "if", "ft", "cc", "tf", "tb", "as"}


def integer(value, low, high):
    return type(value) in (int, float) and low <= value <= high and int(value) == value


def plain(value, limit):
    return isinstance(value, str) and 0 < len(value) <= limit and all(ord(c) >= 32 and ord(c) != 127 for c in value)


def validate_status(value):
    if not isinstance(value, dict):
        raise ValueError("Invalid status")
    fields = {"name": 80, "map": 80, "map_title": 80, "protocol": 80, "version": 40}
    if any(not plain(value.get(key), limit) for key, limit in fields.items()):
        raise ValueError("Invalid status text")
    if value.get("mode") not in MODES or value.get("weapon_rules") not in {"doom", "quake", "ut99"}:
        raise ValueError("Invalid rules")
    if value.get("state") not in {"match", "lobby", "intermission", "loading"}:
        raise ValueError("Invalid state")
    counts = ["humans", "spectators", "bots", "reserved", "open_slots"]
    if not integer(value.get("capacity"), 1, 32) or not integer(value.get("game_port"), 1024, 65535):
        raise ValueError("Invalid capacity or port")
    if any(not integer(value.get(key), 0, 32) for key in counts):
        raise ValueError("Invalid counts")
    if value["humans"] + value["spectators"] + value["reserved"] + value["open_slots"] != value["capacity"]:
        raise ValueError("Inconsistent free slots")
    if value["humans"] + value["spectators"] + value["bots"] > value["capacity"]:
        raise ValueError("Inconsistent population")
    # An allowlist prevents accidentally exposing arbitrary/private server fields.
    return {key: value[key] for key in [*fields, *counts, "capacity", "game_port", "mode", "weapon_rules", "state"]}


def query_status(address, port, timeout=1.5):
    """Prove query endpoint reachability; does not prove gameplay-port reachability."""
    ip = ipaddress.ip_address(address)
    nonce = secrets.token_hex(16)
    with socket.socket(socket.AF_INET6 if ip.version == 6 else socket.AF_INET, socket.SOCK_DGRAM) as peer:
        peer.settimeout(timeout)
        peer.connect((str(ip), port))
        request = {"wire": WIRE, "kind": "hello", "nonce": nonce, "padding": "x" * 96}
        peer.send(json.dumps(request, separators=(",", ":")).encode())
        challenge = receive(peer, nonce, "challenge")
        cookie = challenge.get("cookie")
        if not isinstance(cookie, str) or not re.fullmatch(r"[0-9a-f]{64}", cookie):
            raise ValueError("Invalid challenge")
        request = {"wire": WIRE, "kind": "status", "nonce": nonce, "cookie": cookie}
        peer.send(json.dumps(request, separators=(",", ":")).encode())
        return validate_status(receive(peer, nonce, "status").get("status"))


def receive(peer, nonce, kind):
    raw = peer.recv(MAX_PACKET + 1)
    if len(raw) > MAX_PACKET:
        raise ValueError("Oversized query response")
    row = json.loads(raw)
    if not isinstance(row, dict) or row.get("wire") != WIRE or row.get("nonce") != nonce or row.get("kind") != kind:
        raise ValueError("Invalid query response")
    return row


class Directory:
    def __init__(self, tokens, allow_loopback=False, clock=time.monotonic, probe=query_status):
        self.tokens = tokens
        self.allow_loopback = allow_loopback
        self.clock = clock
        self.probe = probe
        self.rows = {}
        self.limits = {}
        self.lock = threading.Lock()

    def authenticate(self, token):
        digest = hashlib.sha256(token.encode()).hexdigest()
        for server_id, expected in self.tokens.items():
            if hmac.compare_digest(digest, expected):
                return server_id
        return None

    def permit(self, key, limit, seconds):
        with self.lock:
            now = self.clock()
            self.limits = {k: v for k, v in self.limits.items() if v[0] > now}
            until, count = self.limits.get(key, (now + seconds, 0))
            if count >= limit or (key not in self.limits and len(self.limits) >= 4096):
                return False
            self.limits[key] = (until, count + 1)
            return True

    def heartbeat(self, server_id, address, payload):
        ip = ipaddress.ip_address(address)
        if ip.is_multicast or ip.is_unspecified or (not ip.is_global and not (self.allow_loopback and ip.is_loopback)):
            raise ValueError("A public source address is required")
        if not isinstance(payload, dict) or set(payload) != {"game_port", "query_port"}:
            raise ValueError("Expected game_port and query_port")
        if any(not integer(payload[key], 1024, 65535) for key in payload) or payload["game_port"] == payload["query_port"]:
            raise ValueError("Invalid ports")
        # Never probe an arbitrary address supplied in a heartbeat body.
        status = self.probe(str(ip), int(payload["query_port"]))
        status = validate_status(status)
        if status["game_port"] != payload["game_port"]:
            raise ValueError("Gameplay port disagrees with query endpoint")
        row = dict(status, id=server_id, address=str(ip), query_port=int(payload["query_port"]))
        with self.lock:
            self._expire()
            if server_id not in self.rows and len(self.rows) >= MAX_SERVERS:
                raise ValueError("Directory capacity reached")
            self.rows[server_id] = (self.clock(), row)

    def _expire(self):
        now = self.clock()
        self.rows = {key: row for key, row in self.rows.items() if now - row[0] < LEASE_SECONDS}

    def listing(self):
        with self.lock:
            self._expire()
            now = self.clock()
            return {"schema": 1, "servers": [dict(row, age_seconds=int(now - at)) for at, row in self.rows.values()]}


class Server(ThreadingHTTPServer):
    daemon_threads = True
    # Bound simultaneous clients, including slow HTTP readers and UDP probes.
    def __init__(self, address, directory, trust_loopback_proxy=False):
        self.directory = directory
        self.trust_loopback_proxy = trust_loopback_proxy
        self.workers = threading.BoundedSemaphore(32)
        if ":" in address[0]:
            self.address_family = socket.AF_INET6
        super().__init__(address, Handler)

    def process_request(self, request, client_address):
        request.settimeout(5)
        if not self.workers.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except Exception:
            self.workers.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.workers.release()

    def handle_error(self, request, client_address):
        # Do not dump request headers (registration credentials) or packet bodies.
        print("MASTER request failed", flush=True)


class Handler(BaseHTTPRequestHandler):
    server_version = "FPSloppaDirectory/1"

    def log_message(self, *_args):
        pass

    def reply(self, code, body):
        raw = json.dumps(body, separators=(",", ":"), ensure_ascii=True).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(raw)
        self.close_connection = True

    def source(self):
        address = self.client_address[0]
        if self.server.trust_loopback_proxy and ipaddress.ip_address(address).is_loopback:
            # Proxy must OVERWRITE this header with the immediate client's IP.
            address = self.headers.get("X-Real-IP", "")
        return str(ipaddress.ip_address(address))

    def do_GET(self):
        if self.path != "/v1/servers":
            self.reply(404, {"error": "Not found"})
            return
        try:
            address = self.source()
        except ValueError:
            self.reply(400, {"error": "Invalid source address"})
            return
        if not self.server.directory.permit(("list", address), 30, 60):
            self.reply(429, {"error": "Rate limited"})
            return
        self.reply(200, self.server.directory.listing())

    def do_POST(self):
        if self.path != "/v1/heartbeat":
            self.reply(404, {"error": "Not found"})
            return
        directory = self.server.directory
        try:
            address = self.source()
        except ValueError:
            self.reply(400, {"error": "Invalid source address"})
            return
        if not directory.permit(("auth", address), 60, 60):
            self.reply(429, {"error": "Rate limited"})
            return
        authorization = self.headers.get("Authorization", "")
        token = authorization.removeprefix("Bearer ") if authorization.startswith("Bearer ") else ""
        if not re.fullmatch(r"[0-9a-fA-F]{32,256}", token):
            self.reply(401, {"error": "Invalid registration token"})
            return
        server_id = directory.authenticate(token)
        if server_id is None:
            self.reply(401, {"error": "Invalid registration token"})
            return
        if not directory.permit(("heartbeat", server_id), 12, 60):
            self.reply(429, {"error": "Rate limited"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if self.headers.get("Transfer-Encoding") or not 1 <= length <= 1024:
                raise ValueError("Invalid request length")
            payload = json.loads(self.rfile.read(length))
            directory.heartbeat(server_id, address, payload)
        except (ValueError, TypeError, KeyError, OSError):
            self.reply(400, {"error": "Invalid heartbeat or unreachable query endpoint"})
            return
        self.reply(200, {"ok": True, "expires_in": LEASE_SECONDS})


def load_tokens(path):
    rows = json.loads(path.read_text())
    if not isinstance(rows, dict) or not 1 <= len(rows) <= MAX_SERVERS:
        raise ValueError("Expected 1–256 server IDs mapped to SHA-256 token digests")
    for key, value in rows.items():
        if not isinstance(key, str) or not re.fullmatch(r"[a-zA-Z0-9_-]{1,64}", key):
            raise ValueError("Invalid server ID")
        if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{64}", value):
            raise ValueError("Expected SHA-256 token digest")
    if len(set(rows.values())) != len(rows):
        raise ValueError("Use a different token for each server ID")
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--tokens", type=Path, required=True, help="JSON mapping server IDs to SHA-256 token digests")
    parser.add_argument("--cert", help="TLS certificate chain PEM (alternative to a reverse proxy)")
    parser.add_argument("--key", help="TLS private key PEM")
    parser.add_argument("--trust-loopback-proxy", action="store_true")
    parser.add_argument("--allow-loopback", action="store_true", help="LOCAL TESTS ONLY: allow loopback server listings")
    parser.add_argument("--parent-pid", type=int, help=argparse.SUPPRESS)
    parser.add_argument("--ready-file", type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    bind = ipaddress.ip_address(args.bind)
    if bool(args.cert) != bool(args.key) or (not bind.is_loopback and not args.cert):
        parser.error("A public bind requires --cert and --key; otherwise use a loopback HTTPS reverse proxy")
    if args.trust_loopback_proxy and not bind.is_loopback:
        parser.error("Proxy trust requires a loopback bind")
    if args.parent_pid is not None and (not bind.is_loopback or not args.allow_loopback or args.parent_pid != os.getppid()):
        parser.error("Parent-managed mode requires local testing and the actual parent PID")
    if args.ready_file and args.parent_pid is None:
        parser.error("Readiness files are only supported in parent-managed test mode")
    server = Server((args.bind, args.port), Directory(load_tokens(args.tokens), args.allow_loopback), args.trust_loopback_proxy)
    if args.cert:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(args.cert, args.key)
        server.socket = context.wrap_socket(server.socket, server_side=True, do_handshake_on_connect=False)
    print("MASTER_READY port=" + str(server.server_port), flush=True)
    if args.ready_file:
        args.ready_file.write_text(str(server.server_port))
    stopped = threading.Event()
    def watch_parent():
        while not stopped.wait(.5):
            if os.getppid() != args.parent_pid:
                server.shutdown()
                return
    if args.parent_pid is not None:
        threading.Thread(target=watch_parent, daemon=True).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        stopped.set()
        server.server_close()
        if args.parent_pid is not None:
            args.tokens.unlink(missing_ok=True)
            if args.ready_file:
                args.ready_file.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
