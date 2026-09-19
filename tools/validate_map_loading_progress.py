"""Regress stalled map transitions with seven ready clients and one delayed peer."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT_BIN") or shutil.which("godot")
LOGS = ROOT / "test-results" / "map-loading-progress"
LOGS.mkdir(parents=True, exist_ok=True)


def command(script, *args):
    return [GODOT, "--headless", "--xr-mode", "off", "--path", str(ROOT),
            "--script", f"res://deathmatch/tests/{script}.gd", "--", *args]


with tempfile.TemporaryDirectory(prefix="fpsloppa-transition-") as temp:
    unit_env = dict(os.environ, XDG_DATA_HOME=str(Path(temp) / "unit"))
    unit = subprocess.run(command("map_loading_progress"), env=unit_env,
                          capture_output=True, text=True, timeout=40)
    text = unit.stdout + unit.stderr
    (LOGS / "unit.log").write_text(text)
    if unit.returncode or "MAP_LOADING_PROGRESS_RESULT []" not in text or "ERROR:" in text:
        raise SystemExit(text)
    print("PASS seven ready players / eighth loading regression", flush=True)
    processes = []
    handles = []
    try:
        for role in ["server", *[f"fast{i}" for i in range(7)], "slow"]:
            path = LOGS / f"{role}.log"
            handle = path.open("w")
            handles.append(handle)
            env = dict(os.environ, XDG_DATA_HOME=str(Path(temp) / role))
            proc = subprocess.Popen(command("map_loading_network", role), env=env,
                                    stdout=handle, stderr=subprocess.STDOUT)
            processes.append((role, proc, path))
            if role == "server":
                deadline = time.monotonic() + 20
                while "DM_HOST_READY" not in path.read_text():
                    if proc.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError(path.read_text())
                    time.sleep(.05)
        failed = []
        for role, proc, path in processes:
            proc.wait(timeout=90)
            text = path.read_text()
            ok = (proc.returncode == 0 and "MAP_LOADING_NETWORK_RESULT" in text
                  and "FAIL " not in text and "ERROR:" not in text)
            print("PASS" if ok else "FAIL", role, flush=True)
            if not ok:
                failed.append(role)
                print(text[-6000:])
        if failed:
            raise SystemExit("Failed: " + ", ".join(failed))
    finally:
        for _, proc, _ in processes:
            if proc.poll() is None:
                proc.terminate()
                proc.wait(timeout=5)
        for handle in handles:
            handle.close()
