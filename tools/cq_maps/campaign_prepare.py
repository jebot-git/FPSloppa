"""Prepare/validate campaign collision, navigation and presentation caches."""
import argparse,concurrent.futures,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def prepare(i):
    folder=ROOT/f'maps/CampaignDistricts/district_{i:02}'
    with (folder/'prepare.log').open('w') as log:
        result=subprocess.run(['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','tools/cq_maps/prepare.gd','--',str(i),'--campaign'],stdout=log,stderr=subprocess.STDOUT,timeout=110)
    text=(folder/'prepare.log').read_text()
    if result.returncode or 'CQ_DISTRICT_PREPARED ' not in text or 'SCRIPT ERROR' in text:raise RuntimeError(f'd{i:02} preparation failed; see {folder}/prepare.log')
    return json.loads((folder/'validation.json').read_text())

def main():
    p=argparse.ArgumentParser();p.add_argument('--build-log',type=Path);p.add_argument('--districts',type=int,nargs='+',default=list(range(81)));p.add_argument('--jobs',type=int,default=2);a=p.parse_args()
    pending=set(a.districts);running={};failed=[];started=time.monotonic()
    with concurrent.futures.ThreadPoolExecutor(max_workers=a.jobs) as pool:
        while pending or running:
            ready=set(a.districts)
            if a.build_log:
                ready={json.loads(line.split(' ',1)[1])['district'] for line in a.build_log.read_text().splitlines() if line.startswith('CAMPAIGN_BUILT ')}
            for i in sorted(pending & ready)[:max(0,a.jobs-len(running))]:pending.remove(i);running[pool.submit(prepare,i)]=i
            for f in list(running):
                if not f.done():continue
                i=running.pop(f)
                try:print('CAMPAIGN_PREPARED',json.dumps(f.result()),flush=True)
                except Exception as e:failed.append(i);print('CAMPAIGN_PREPARE_FAILED',i,str(e),flush=True)
            if time.monotonic()-started>3600:raise SystemExit('Preparation deadline exceeded: '+str(pending))
            if pending or running:time.sleep(1)
    if failed:raise SystemExit('Failed maps: '+str(failed))
if __name__=='__main__':main()
