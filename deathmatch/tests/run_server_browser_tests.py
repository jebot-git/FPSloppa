"""Real Godot server -> master -> browser -> ENet admission, including master outage."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("fpsloppa_master", ROOT / "tools/master_server/server.py")
master = importlib.util.module_from_spec(spec)
spec.loader.exec_module(master)


def free_udp():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as peer:
        peer.bind(("127.0.0.1", 0))
        return peer.getsockname()[1]


def wait_for(predicate, seconds=30):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(.05)
    raise AssertionError("Timed out waiting for integration fixture")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--server", type=Path, help="Optional freshly built console server executable")
    parser.add_argument("--visual", action="store_true", help="Render the browser and save a screenshot")
    args = parser.parse_args()
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot")
    logs = ROOT / "test-results/server-browser"
    logs.mkdir(parents=True, exist_ok=True)
    token = secrets.token_hex(32)
    directory = master.Directory({"integration": hashlib.sha256(token.encode()).hexdigest()}, allow_loopback=True)
    service = master.Server(("127.0.0.1", 0), directory)
    worker = threading.Thread(target=service.serve_forever, daemon=True)
    worker.start()
    stopped = False
    processes = []
    handles = []
    report = {}
    try:
        with tempfile.TemporaryDirectory(prefix="fpsloppa-browser-") as temporary:
            folder = Path(temporary)
            assets = folder / "assets"
            # Asset catalogs update maplists; never run that against the checkout.
            for row in json.loads((ROOT / "deathmatch/assets/base_manifest.json").read_text())["files"]:
                if row["path"] == "maps/qsrc_dm1.bsp" or row["path"].startswith("vrm/"):
                    target = assets / row["path"]
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(ROOT / row["path"], target)
            env = dict(os.environ, XDG_DATA_HOME=str(folder / "data"), XDG_CONFIG_HOME=str(folder / "config"),
                       XDG_CACHE_HOME=str(folder / "cache"), FPSLOPPA_MASTER_TOKEN=token)
            game_port, query_port = free_udp(), free_udp()
            while query_port == game_port:
                query_port = free_udp()
            url = f"http://127.0.0.1:{service.server_port}"
            cfg = folder / "server.cfg"
            cfg.write_text(f'set net_ip 127.0.0.1\nset net_port {game_port}\nset sv_query_port {query_port}\n'
                           f'set sv_public 1\nset sv_master_url "{url}"\nset sv_hostname "Browser Integration"\n'
                           'set sv_maxclients 2\nset sv_bot_fill 2\nset sv_voice 0\nset sv_gametypes "dm ctf"\n'
                           'set dm_maplist "qsrc_dm1"\nset ctf_maplist "qsrc_dm1"\n')
            base = [godot, "--headless", "--xr-mode", "off", "--audio-driver", "Dummy", "--path", str(ROOT)]
            command = ([str(args.server.resolve()), "--log-file", str(logs / "server-engine.log"), "--", "--config", str(cfg)]
                       if args.server else base + ["--log-file", str(logs / "server-engine.log"), "--", "--server", "--config", str(cfg)])
            command += ["--asset-root", str(assets)]
            handle = (logs / "server.log").open("w"); handles.append(handle)
            server = subprocess.Popen(command, env=env, stdout=handle, stderr=subprocess.STDOUT); processes.append(server)
            wait_for(lambda: bool(directory.listing()["servers"]) or server.poll() is not None)
            assert server.poll() is None, (logs / "server.log").read_text()[-5000:]
            assert directory.listing()["servers"], "Dedicated heartbeat did not register"
            time.sleep(1.1)  # Start query validation in a fresh rate-limit window.
            report["status"] = master.query_status("127.0.0.1", query_port)
            assert report["status"]["open_slots"] == 2 and report["status"]["bots"] == 2
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as peer:
                peer.settimeout(.25)
                for packet in [b"invalid", b"x" * 1300, json.dumps({"wire": master.WIRE, "kind": "status", "nonce": "ab" * 16, "cookie": "00" * 32}).encode()]:
                    peer.sendto(packet, ("127.0.0.1", query_port))
                    try:
                        peer.recv(1500)
                        raise AssertionError("Unauthenticated/invalid query received a response")
                    except socket.timeout:
                        pass
            report["invalid_queries_silent"] = True
            time.sleep(1.1)
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as owner, socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as other:
                nonce = secrets.token_hex(16)
                owner.settimeout(1)
                hello = json.dumps({"wire": master.WIRE, "kind": "hello", "nonce": nonce, "padding": "x" * 96}).encode()
                owner.sendto(hello, ("127.0.0.1", query_port))
                raw, _ = owner.recvfrom(1500)
                assert len(raw) <= len(hello), "Challenge amplifies unauthenticated input"
                challenge = json.loads(raw)
                request = json.dumps({"wire": master.WIRE, "kind": "status", "nonce": nonce, "cookie": challenge["cookie"]}).encode()
                other.settimeout(.25)
                other.sendto(request, ("127.0.0.1", query_port))
                try:
                    other.recv(1500)
                    raise AssertionError("Cookie replay from another port was accepted")
                except socket.timeout:
                    pass
                owner.sendto(request, ("127.0.0.1", query_port))
                assert json.loads(owner.recv(1500))["kind"] == "status"
            report["cookie_endpoint_binding"] = True
            client_env = dict(env)
            client_env.pop("FPSLOPPA_MASTER_TOKEN")
            control = logs / "control"
            for suffix in ["-stop-master", "-master-stopped"]:
                Path(str(control) + suffix).unlink(missing_ok=True)
            command = [godot] + ([] if args.visual else ["--headless"])
            command += ["--xr-mode", "off", "--audio-driver", "Dummy", "--path", str(ROOT), "--log-file", str(logs / "client-engine.log"),
                        "--script", "res://deathmatch/tests/server_browser.gd", "--", "--client-config", str(folder / "client.cfg"),
                        "--browser-master", url, "--browser-control", str(control), "--asset-root", str(assets)]
            handle = (logs / "client.log").open("w"); handles.append(handle)
            client = subprocess.Popen(command, env=client_env, stdout=handle, stderr=subprocess.STDOUT); processes.append(client)
            wait_for(lambda: Path(str(control) + "-stop-master").exists() or client.poll() is not None, 70)
            assert client.poll() is None, (logs / "client.log").read_text()[-6000:]
            service.shutdown(); service.server_close(); worker.join(); stopped = True
            Path(str(control) + "-master-stopped").write_text("stopped")
            client.wait(timeout=50)
            output = (logs / "client.log").read_text()
            assert client.returncode == 0 and "BROWSER_RESULT []" in output, output[-7000:]
            assert "SCRIPT ERROR:" not in output and "ERROR:" not in output, output[-7000:]
            assert token not in (logs / "server.log").read_text()
            assert server.poll() is None
            report.update(passed=True, packaged_server=bool(args.server), browser_join=True, browser_spectate=True,
                          master_outage_join=True, favorites_persist=True)
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate(); process.wait(timeout=10)
        for handle in handles:
            handle.close()
        if not stopped:
            service.shutdown(); service.server_close(); worker.join()
        (logs / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    print("SERVER_BROWSER_PASS", json.dumps(report))


if __name__ == "__main__":
    main()
