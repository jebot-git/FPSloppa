"""Summarize the retained protocol-34 live test; never interpret demo gaps as packet loss."""
from pathlib import Path
import datetime
import json
import statistics

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "test-results/network-upgrade/remote"

def read_rows(path):
    rows, invalid = [], 0
    for line in path.read_text().splitlines():
        try: rows.append(json.loads(line))
        except ValueError: invalid += 1
    return rows, invalid

def stats(values):
    values = sorted(v for v in values if v is not None)
    if not values: return {}
    return dict(samples=len(values), min=values[0], median=statistics.median(values),
                p95=values[min(len(values)-1,int(len(values)*.95))], max=values[-1])

def main():
    invalid_journal_lines = 0
    for index in range(16):
        target = OUT/f"client-network-{index:02}.jsonl"
        if target.exists(): continue
        source = Path(f"/tmp/fpsloppa-network-remote-{index:02}/godot/app_userdata/FPSloppa/client-network.jsonl")
        rows, invalid = read_rows(source); invalid_journal_lines += invalid
        rows = rows[max(i for i,r in enumerate(rows) if r["stage"]=="connect_start"):]
        target.write_text("".join(json.dumps(r)+"\n" for r in rows))
    rows, invalid_server_lines = read_rows(OUT/"server.jsonl")
    rows = rows[max(i for i,r in enumerate(rows) if r["event"]=="server_started"):]
    health = [r for r in rows if r["event"]=="health" and r["data"]["transport_peers"]==16]
    start = datetime.datetime.fromisoformat(health[0]["utc"]).timestamp()
    end = datetime.datetime.fromisoformat(health[-1]["utc"]).timestamp()
    processes, invalid_process_lines = read_rows(OUT/"process-verified.jsonl")
    processes = [r for r in processes if start<=r["time"]<=end]
    result = dict(full_capacity_health_samples=len(health), process_window_seconds=end-start,
                  process={k:stats([r[k] for r in processes]) for k in ["cpu_percent","rss_kib","udp_drops","threads","fds"]},
                  engine={k:stats([r["data"][k] for r in health]) for k in ["physics_ms","process_ms","orphan_nodes"]},
                  replication_final=health[-1]["data"]["replication"],
                  mode_health={mode:sum(r["mode"]==mode for r in health) for mode in sorted({r["mode"] for r in health})},
                  skipped_invalid_lines=dict(journals_before_session_filter=invalid_journal_lines,server=invalid_server_lines,process=invalid_process_lines))
    clients=[]
    for index in range(16):
        records,_=read_rows(OUT/f"client-network-{index:02}.jsonl")
        samples=[r["data"] for r in records if r["stage"]=="network_health"]
        if samples:
            clients.append(dict(client=index,samples=len(samples),
                                interpolation_ms=stats([r["interpolation_ms"] for r in samples]),
                                sample_age_ms=stats([r["sample_age_ms"] for r in samples]),
                                **{k:samples[-1]["replication"][k] for k in ["received_packets","player_updates","player_update_gaps"]},
                                prediction_final=samples[-1]["prediction"]))
    result["clients"]=clients
    (OUT/"performance.json").write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps({k:v for k,v in result.items() if k!="clients"},indent=2))

if __name__=="__main__": main()
