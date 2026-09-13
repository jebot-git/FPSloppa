"""16 real clients against the explicitly staged remote console test server; always reap clients."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "test-results/network-upgrade/remote"
spec = importlib.util.spec_from_file_location("rcon",ROOT/"tools/rcon.py")
rcon = importlib.util.module_from_spec(spec); spec.loader.exec_module(rcon)
CASES = [("dm","qsrc_dm3","doom"),("tdm","qsrc_dm6","quake"),("ctf","ctf_crownreach","ut99"),
         ("koth","koth_alichar","doom"),("ig","qsrc_dm6","doom"),("if","qsrc_dm6","doom"),
         ("ft","qsrc_dm3","doom"),("cc","cc_basement","doom"),("tf","tf_vesper","quake"),
         ("as","as_frigate","ut99")]


def command(text):
    for attempt in range(8):
        try: return rcon.command("127.0.0.1",28778,(OUT.parent/"rcon.secret").read_text(),text)
        except (OSError,ValueError):
            if attempt==7: raise
            time.sleep(8)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    stop = OUT/"stop"; stop.unlink(missing_ok=True)
    status = OUT/"status.json"; status.unlink(missing_ok=True)
    scene = OUT/"client.tscn"
    scene.write_text((ROOT/"deathmatch/arena.tscn").read_text().replace("res://deathmatch/arena.gd","res://tools/network_study/remote_arena.gd"))
    demo = OUT/"match.fpsdemo"
    if demo.exists(): raise RuntimeError("Preserve the previous recording before rerunning")
    processes, handles, results = [], [], []
    def observed():
        try: return json.loads(status.read_text())
        except (FileNotFoundError,json.JSONDecodeError): return {}
    try:
        assert command("match dm qsrc_dm3 doom").get("ok")
        for index in range(16):
            options = dict(scene=str(scene),index=index,observer=index==15,host="45.147.228.101",port=7777,
                           stop=str(stop),status=str(status),demo=str(demo))
            log = (OUT/f"client-{index:02}.log").open("w"); handles.append(log)
            process = subprocess.Popen(["godot","--headless","--xr-mode","off","--max-fps","60","--path",str(ROOT),
                                        "--script","res://tools/remote_match/client.gd","--",json.dumps(options),"--asset-root",str(OUT.parent/"frozen-assets")],
                                       stdout=log,stderr=subprocess.STDOUT,env={**os.environ,"XDG_DATA_HOME":f"/tmp/fpsloppa-network-remote-{index:02}"})
            processes.append(process); time.sleep(.2)
        for number,(mode,map_id,rules) in enumerate(CASES):
            if number: assert command(f"match {mode} {map_id} {rules}").get("ok")
            deadline = time.monotonic()+100
            while time.monotonic()<deadline:
                row=observed()
                if row.get("active") and row.get("mode")==mode and row.get("map")==map_id and len(row.get("players",[]))==16: break
                if any(p.poll() is not None for p in processes): raise RuntimeError("Client exited during admission")
                time.sleep(.3)
            else: raise RuntimeError("Admission timeout "+str(row))
            started=time.monotonic(); samples=[]
            while time.monotonic()-started<(35 if mode in ["tf","as"] else 20):
                row=observed(); samples.append(row)
                if not row.get("active") or len(row.get("players",[]))!=16: raise RuntimeError("Roster lost "+str(row))
                if any(p.poll() is not None for p in processes): raise RuntimeError("Client exited")
                time.sleep(.5)
            results.append(dict(mode=mode,map=map_id,rules=rules,samples=samples))
            (OUT/"rounds.json").write_text(json.dumps(results,indent=2)+"\n")
            print("REMOTE_MODE_OK",mode,"players",len(row["players"]),"scores",row["scores"],flush=True)
    finally:
        stop.touch()
        for process in processes:
            try: process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.terminate()
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
        for handle in handles: handle.close()
        errors={p.name:[line for line in p.read_text(errors="replace").splitlines() if line.startswith(("ERROR:","SCRIPT ERROR:"))] for p in OUT.glob("client-*.log")}
        report=dict(exits=[p.returncode for p in processes],errors=errors,completed=[r["mode"] for r in results])
        (OUT/"result.json").write_text(json.dumps(report,indent=2)+"\n")
        print("REMOTE_REAPED",report["exits"],flush=True)
    if any(report["exits"]) or any(errors.values()) or len(results)!=len(CASES): raise SystemExit(1)


if __name__=="__main__": main()
