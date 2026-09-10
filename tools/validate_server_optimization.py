"""Check collision correctness and measure server load without replacing audit data."""
import argparse
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
TESTS = ["capsule_equivalence", "projectile_targets", "hit_detection",
         "lag_reliability", "projectile_ordering", "rocket_jump", "combat", "fortress"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", default="final")
    parser.add_argument("--players", type=int, nargs="+", default=[8, 16, 32])
    parser.add_argument("--skip-tests", action="store_true")
    parser.add_argument("--ticks", type=int, default=720)
    parser.add_argument("--memory", action="store_true")
    args = parser.parse_args()
    if args.ticks < 121 or any(count < 1 or count > 32 for count in args.players):
        parser.error("Use at least 121 ticks and between 1 and 32 players")
    if not args.stage or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_" for c in args.stage):
        parser.error("Stage must contain only letters, digits, hyphens or underscores")
    folder = ROOT / "test-results/server-optimization"
    folder.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, XDG_DATA_HOME="/tmp/fpsloppa-server-optimization-profile")
    godot = os.environ.get("GODOT_BIN", "godot")
    rows = []

    def run(name, script, extra=(), timeout=90):
        path = folder / f"{args.stage}-{name}.log"
        command = [godot, "--headless", "--xr-mode", "off", "--path", str(ROOT),
                   "--script", f"res://deathmatch/tests/{script}.gd"]
        if extra:
            command.extend(["--", *extra])
        # subprocess.run kills and reaps its child if the timeout expires.
        with path.open("w") as log:
            try:
                result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                        env=env, timeout=timeout)
                code = result.returncode
            except subprocess.TimeoutExpired:
                code = 124
        output = path.read_text()
        passed = code == 0 and not any(token in output for token in
                                       ["SCRIPT ERROR:", "ERROR:", "FAIL ", "MISMATCH"])
        row = {"name": name, "passed": passed, "exit_code": code}

        def records(marker):
            return [json.loads(line[len(marker):]) for line in output.splitlines()
                    if line.startswith(marker)]

        if name.startswith("cpu"):
            loads = records("SERVER_LOAD_RESULT ")
            if loads:
                row["load"] = loads[-1]
            else:
                row["passed"] = False
            if args.memory:
                row["memory"] = records("SERVER_MEMORY_SAMPLE ")
                final = records("SERVER_MEMORY_FINAL ")
                row["memory_final"] = final[-1] if final else None
                if not row["memory"] or not final or any(sample["orphans"] for sample in row["memory"] + final):
                    row["passed"] = False
        rows.append(row)
        (folder / f"{args.stage}.json").write_text(json.dumps(rows, indent=2) + "\n")
        print(json.dumps(row), flush=True)
        return row["passed"]

    if not args.skip_tests:
        for name in TESTS:
            if not run(name, name):
                return 1
    for count in args.players:
        extra = [str(count), "--ticks", str(args.ticks)]
        if args.memory:
            extra.append("--memory")
        if not run(f"cpu{count}", "server_load_audit", extra,
                   timeout=max(180, args.ticks / 60 * 4 + 30)):
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
