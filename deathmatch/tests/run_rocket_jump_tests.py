"""Rocket physics, input timing and real ENet checks for the Quake hotfix."""
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "test-results/rocket-jump-hotfix"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    results = []
    for script, roles, marker, rules in [
        ("rocket_jump", ["local"], "ROCKET_JUMP_RESULT ", ""),
        ("fire_delivery", ["local"], "FIRE_DELIVERY_RESULT ", ""),
        ("rocket_cooldown", ["local"], "ROCKET_COOLDOWN_RESULT ", ""),
        ("rocket_tracked_melee", ["local"], "ROCKET_TRACKED_MELEE_RESULT ", ""),
        ("prediction_landings", ["local"], "PREDICTION_LANDINGS_RESULT ", ""),
        ("rocket_trigger_network", ["server", "client"], "ROCKET_TRIGGER_NETWORK_RESULT ", "quake"),
        ("rocket_trigger_network", ["server", "client"], "ROCKET_TRIGGER_NETWORK_RESULT ", "doom"),
    ]:
        jobs = []
        try:
            for role in roles:
                name = f"{script}-{role}" + (f"-{rules}" if rules else "")
                log = OUT / f"{name}.log"
                handle = log.open("w")
                command = ["godot", "--headless", "--xr-mode", "off", "--audio-driver", "Dummy",
                           "--path", str(ROOT), "--log-file", str(OUT / f"{name}-engine.log"),
                           "--script", f"res://deathmatch/tests/{script}.gd", "--"]
                if role != "local":
                    command += [role, rules]
                command += ["--client-config", str(OUT / f"{name}.cfg")]
                env = {**os.environ, "XDG_DATA_HOME": str(OUT / name / "user")}
                proc = subprocess.Popen(command, cwd=ROOT, env=env, stdout=handle, stderr=subprocess.STDOUT)
                jobs.append((proc, handle, log))
                if role == "server":
                    time.sleep(1)
            for proc, handle, log in jobs:
                proc.wait(timeout=95)
                handle.close()
                lines = log.read_text(errors="replace").splitlines()
                payload = next((json.loads(line[len(marker):]) for line in lines if line.startswith(marker)), None)
                failures = payload.get("failures", []) if isinstance(payload, dict) else payload
                errors = [line for line in lines if line.startswith(("ERROR:", "SCRIPT ERROR:"))]
                substantive = [line for line in errors if "resources still in use at exit" not in line]
                row = {"log":str(log.relative_to(ROOT)), "exit_code":proc.returncode,
                       "passed":payload is not None and not failures and proc.returncode == 0 and not substantive,
                       "result":payload, "errors":errors,
                       "warnings":[line for line in lines if line.startswith("WARNING:")],
                       "metrics":[json.loads(line.split(" ", 1)[1]) for line in lines if line.startswith("ROCKET_TRIGGER_METRICS ")]}
                results.append(row)
                print(log.name, "PASS" if row["passed"] else "FAIL", flush=True)
        finally:
            for proc, handle, _ in jobs:
                if proc.poll() is None:
                    proc.terminate()
                    try:
                        proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                        proc.wait()
                handle.close()
    report = {"passed":all(row["passed"] for row in results), "runs":results}
    (OUT / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
