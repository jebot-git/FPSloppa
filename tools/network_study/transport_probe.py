"""Bounded, real ENet datagram-loss experiment; no live server or game config changes."""
from pathlib import Path
import importlib.util
import json
import os
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("lag_proxy", ROOT / "tools/validate_lag_network.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def main():
    folder = ROOT / "test-results/network-study"
    results = []
    for name, rtt, jitter, loss in [("clean", 0, 0, 0), ("impaired", 100, 10, .02)]:
        proxy = module.Proxy(rtt, jitter, loss)
        thread = threading.Thread(target=proxy.run)
        processes, logs = [], []
        thread.start()
        try:
            for role in ["server", "client"]:
                path = folder / f"transport-{name}-{role}.log"
                log = path.open("w")
                logs.append(log)
                proc = subprocess.Popen([
                    os.environ.get("GODOT_BIN", "godot"), "--headless", "--xr-mode", "off",
                    "--path", str(ROOT), "--script", "res://tools/network_study/transport_probe.gd", "--", role,
                ], stdout=log, stderr=subprocess.STDOUT,
                    env={**os.environ, "XDG_DATA_HOME": "/tmp/fpsloppa-network-study"})
                processes.append((role, proc, path))
                if role == "server": time.sleep(.6)
            for role, proc, path in processes:
                proc.wait(timeout=65)
                text = path.read_text()
                if proc.returncode or "SCRIPT ERROR" in text or "ERROR:" in text:
                    raise RuntimeError(f"{name}/{role}: {text[-3000:]}")
                if role == "client":
                    record = next(json.loads(line.removeprefix("TRANSPORT_PROBE "))
                                  for line in text.splitlines() if line.startswith("TRANSPORT_PROBE "))
            result = {"name": name, "rtt_ms": rtt, "jitter_each_direction_ms": jitter,
                      "datagram_loss": loss, "seed": 4817, "results": record, "proxy": dict(proxy.counts)}
            results.append(result)
            (folder / "transport.json").write_text(json.dumps(results, indent=2) + "\n")
            print(json.dumps(result), flush=True)
        finally:
            for _, proc, _ in processes:
                if proc.poll() is None:
                    proc.terminate()
                    try: proc.wait(timeout=5)
                    except subprocess.TimeoutExpired: proc.kill(); proc.wait()
            proxy.stop = True
            thread.join(timeout=5)
            for log in logs: log.close()


if __name__ == "__main__": main()
