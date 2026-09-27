"""Local ENet dead-player voice/text isolation, with real Opus encoding/decoding."""
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "test-results/defusal"
OUT.mkdir(parents=True, exist_ok=True)
processes, logs = [], []
try:
    for role in ["server", "sender", "dead", "alive", "observer"]:
        log = (OUT / f"voice-network-{role}.log").open("w")
        logs.append(log)
        env = dict(os.environ, XDG_CONFIG_HOME=f"/tmp/fps-devoice-{role}", XDG_DATA_HOME=f"/tmp/fps-devoice-{role}")
        proc = subprocess.Popen(["godot", "--headless", "--xr-mode", "off", "--path", str(ROOT), "--script", "deathmatch/tests/defusal_voice_network.gd", "--", role], stdout=log, stderr=subprocess.STDOUT, env=env)
        processes.append((role, proc))
        if role == "server":
            time.sleep(1)
    for role, proc in processes:
        proc.wait(timeout=40)
        text = (OUT / f"voice-network-{role}.log").read_text()
        print(role, proc.returncode, "\n".join(text.splitlines()[-14:]))
        assert proc.returncode == 0 and "DEFUSAL_VOICE_NETWORK_RESULT" in text and "FAIL " not in text and "SCRIPT ERROR" not in text
finally:
    for _, proc in processes:
        if proc.poll() is None:
            proc.terminate()
    for log in logs:
        log.close()
