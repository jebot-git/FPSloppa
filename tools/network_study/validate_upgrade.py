"""Run bounded existing mechanics fixtures against the upgraded source. Preserve earlier logs."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "test-results/network-upgrade"
UNITS = ["replication_protocol", "network_delivery", "local_prediction", "quake_movement", "water", "stairs",
         "vr_crouch_water", "movement_timing", "melee", "network_workers", "asset_publication"]
NETWORK = [("address_fallback_network", ["server", "client"]), ("network_runner", ["server", "shooter", "target", "spectator"]),
           ("team_network", ["server", "red", "blue", "observer"]), ("physical_network", ["server", "client"]),
           ("stance_network", ["server", "client"]), ("frigate_network", ["server", "client"]),
           ("voice_network", ["server", "sender", "receiver"]),
           ("team_radio_network", ["server", "sender", "teammate", "enemy"]),
           ("weapon_clearance_network", ["server", "client"]),
           ("weapon_variants_network", ["server", "client"])]


def run_case(name, roles, variant="ut99"):
    processes, handles, rows = [], [], []
    try:
        for role in roles:
            tag = name + ("-"+variant if name=="weapon_variants_network" else "")
            path = OUT / f"{tag}-{role or 'unit'}.log"
            handle = path.open("w"); handles.append(handle)
            cmd = ["godot", "--headless", "--xr-mode", "off", "--path", str(ROOT),
                   "--script", f"res://deathmatch/tests/{name}.gd"]
            if role:
                cmd += ["--", role]
                if name == "weapon_variants_network": cmd += [variant, "27931" if variant=="ut99" else "27932"]
            process = subprocess.Popen(cmd, stdout=handle, stderr=subprocess.STDOUT,
                                       env={**os.environ, "XDG_DATA_HOME": "/tmp/fpsloppa-network-regressions",
                                            "XDG_CONFIG_HOME": "/tmp/fpsloppa-network-regressions/config"})
            processes.append((process, path))
            if role == "server":
                until = time.monotonic()+10
                while time.monotonic()<until and process.poll() is None:
                    if "DM_HOST_READY" in path.read_text(): break
                    time.sleep(.05)
        deadline = time.monotonic()+100
        for process, path in processes:
            process.wait(timeout=max(1, deadline-time.monotonic()))
            content = path.read_text()
            errors = [line for line in content.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:", "FAIL "))]
            rows.append(dict(log=path.name, exit=process.returncode, errors=errors, checks=content.count("PASS ")))
        return dict(case=name, passed=all(r["exit"]==0 and not r["errors"] for r in rows), roles=rows)
    except subprocess.TimeoutExpired:
        return dict(case=name, passed=False, error="timeout", roles=rows)
    finally:
        for process, _ in processes:
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
        for handle in handles: handle.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("group", choices=["unit", "network"])
    parser.add_argument("--case")
    parser.add_argument("--variant",default="ut99",choices=["quake","ut99"])
    args = parser.parse_args()
    cases = [(name,[""]) for name in UNITS] if args.group=="unit" else NETWORK
    if args.case: cases = [case for case in cases if case[0]==args.case]
    assert cases
    results = []
    for name, roles in cases:
        result = run_case(name, roles,args.variant); results.append(result)
        print(json.dumps(result), flush=True)
        label=(args.case+"-"+args.variant if args.case=="weapon_variants_network" else args.case) or args.group+"-suite"
        (OUT / label).with_suffix(".json").write_text(json.dumps(results,indent=2)+"\n")
    raise SystemExit(0 if all(r["passed"] for r in results) else 1)


if __name__ == "__main__": main()
