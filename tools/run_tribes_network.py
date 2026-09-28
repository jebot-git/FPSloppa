"""Tribes movement integration against a real local ENet server, pilot and late spectator."""
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "test-results/tribes"
OUT.mkdir(parents=True, exist_ok=True)
processes, logs = [], []
try:
    for role, delay in [("server", 2), ("pilot", 3), ("viewer", 0)]:
        log = open(OUT / f"network-{role}.log", "w")
        logs.append(log)
        env = dict(os.environ, XDG_CONFIG_HOME=f"/tmp/fps-tribesnet-{role}", XDG_DATA_HOME=f"/tmp/fps-tribesnet-{role}")
        proc = subprocess.Popen(["godot", "--headless", "--xr-mode", "off", "--path", str(ROOT), "--script", "deathmatch/tests/tribes_network.gd", "--", role], stdout=log, stderr=subprocess.STDOUT, env=env)
        processes.append((role, proc))
        time.sleep(delay)
    for role, proc in processes:
        proc.wait(timeout=105)
        content = (OUT / f"network-{role}.log").read_text()
        print(role, proc.returncode, "\n".join(content.splitlines()[-24:]))
        assert proc.returncode == 0 and f"TRIBES_NETWORK_RESULT {role} []" in content and "SCRIPT ERROR" not in content
finally:
    for _, proc in processes:
        if proc.poll() is None:
            proc.terminate()
    for log in logs:
        log.close()
