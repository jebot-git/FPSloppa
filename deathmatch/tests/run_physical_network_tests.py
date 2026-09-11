"""Exercise physical VR ability RPCs between a real ENet server and client."""
from pathlib import Path
import json
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
LOGS = ROOT / "test-results" / "physical-interactions"


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    processes, handles = [], []
    try:
        for role in ("server", "client"):
            handle = (LOGS / f"network-{role}.log").open("w")
            handles.append(handle)
            processes.append((role, subprocess.Popen([
                "godot", "--headless", "--xr-mode", "off", "--path", str(ROOT),
                "--log-file", str(LOGS / f"engine-{role}.log"), "--script",
                "res://deathmatch/tests/physical_network.gd", "--", role,
                "--client-config", str(LOGS / f"client-{role}.cfg")],
                stdout=handle, stderr=subprocess.STDOUT)))
            if role == "server":
                deadline = time.monotonic() + 8
                while time.monotonic() < deadline and processes[-1][1].poll() is None:
                    if "DM_HOST_READY" in (LOGS / "network-server.log").read_text():
                        break
                    time.sleep(.05)
        rows = []
        deadline = time.monotonic() + 60
        for role, process in processes:
            process.wait(timeout=max(1, deadline - time.monotonic()))
            output = (LOGS / f"network-{role}.log").read_text()
            rows.append({"role": role, "exit_code": process.returncode,
                         "passed": process.returncode == 0 and "PHYSICAL_NETWORK_RESULT" in output
                         and not any(token in output for token in ("ERROR:", "FAIL ")),
                         "checks": output.count("PASS ")})
            print(output)
        (LOGS / "network.json").write_text(json.dumps(rows, indent=2) + "\n")
        return 0 if all(row["passed"] for row in rows) else 1
    finally:
        for _, process in processes:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        for handle in handles:
            handle.close()


if __name__ == "__main__":
    raise SystemExit(main())
