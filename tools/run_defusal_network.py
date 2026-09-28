"""Real ENet DE purchases, planting, code/cutter defusal, late join and recording."""
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "test-results/defusal"
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "network.fpsdemo").unlink(missing_ok=True)
processes, logs = [], []
try:
    for role, delay in [("server", 1), ("attacker", 1), ("defender", 6), ("viewer", 0)]:
        if role == "viewer":
            # A fixed startup delay can join before planting on a slower host.
            # Wait for the authoritative event to exercise an actual late join.
            deadline = time.monotonic() + 25
            while "PASS Remote arming and site placement" not in (OUT / "network-server.log").read_text():
                if time.monotonic() >= deadline or processes[0][1].poll() is not None:
                    raise RuntimeError("Server did not reach the first plant before late viewer join")
                time.sleep(.05)
        log = open(OUT / f"network-{role}.log", "w")
        logs.append(log)
        env = dict(os.environ, XDG_CONFIG_HOME=f"/tmp/fps-denet-{role}", XDG_DATA_HOME=f"/tmp/fps-denet-{role}")
        proc = subprocess.Popen(["godot", "--headless", "--xr-mode", "off", "--path", str(ROOT), "--script", "deathmatch/tests/defusal_network.gd", "--", role], stdout=log, stderr=subprocess.STDOUT, env=env)
        processes.append((role, proc))
        time.sleep(delay)
    for role, proc in processes:
        proc.wait(timeout=60)
        content = (OUT / f"network-{role}.log").read_text()
        print(role, proc.returncode, "\n".join(content.splitlines()[-26:]))
        assert proc.returncode == 0 and f"DEFUSAL_NETWORK_RESULT {role} []" in content and "SCRIPT ERROR" not in content
finally:
    for _, proc in processes:
        if proc.poll() is None:
            proc.terminate()
    for log in logs:
        log.close()
