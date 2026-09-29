"""Parity and gameplay regressions for ST query batching and native channels."""
from pathlib import Path
import json,os,re,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/native-st-batch/checks'
SUITES=['native_st_steering','native_avatar_channels','st_query_batches','native_preparation','native_acceleration','native_bots','native_st_bots','native_rewind','native_shot_history','tribes_physics','tribes_arsenal','st_speed_control','st_ski_safety','st_ski_chain','st_rolling_launch','st_obstacle_control','st_carrier_approach','st_carrier_escape','st_capture_entry','st_capture_readiness','st_stonehenge_carrier_hold','st_raindance_entrance','st_raindance_routes','st_construction_routes','st_carrier_routes','st_route_cache','frame_smoothness','render_motion','st_targeting']
FALLBACK=['st_speed_control','st_ski_safety','st_carrier_approach','st_raindance_routes','frame_smoothness']
POSITIONAL_REPORTS={'st_ski_chain','st_carrier_escape','st_capture_entry'}
def main():
    OUT.mkdir(parents=True,exist_ok=True);reports={}
    for name,reference in [(x,False) for x in SUITES]+[(x,True) for x in FALLBACK]:
        source=(ROOT/'deathmatch/tests'/(name+'.gd')).read_text()
        for path in re.findall(r'FileAccess.open\("res://(test-results/[^"\n]+)"',source):(ROOT/path).parent.mkdir(parents=True,exist_ok=True)
        label=name+('-fallback' if reference else '');log=OUT/(label+'.log')
        flags=['--gdscript-st-steering','--gdscript-avatar-channels','--reference-nav-queries','--reference-mine-scan'] if reference else []
        # These fixtures consume the first user argument as a report filename.
        # Keep configuration switches out of that position.
        report_args=[str(OUT/(label+'.json'))] if name in POSITIONAL_REPORTS else []
        command=['godot','--headless',*(['--fixed-fps','60'] if name not in ['render_motion','st_query_batches'] else []),'--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/tests/'+name+'.gd','--',*report_args,*flags,'--client-config','/tmp/fps-st-batch-validation.cfg']
        started=time.monotonic()
        with log.open('w') as stream:
            proc=subprocess.Popen(command,cwd=ROOT,env=dict(os.environ,XDG_DATA_HOME='/tmp/fps-st-batch-validation'),stdout=stream,stderr=subprocess.STDOUT)
            try:
                while proc.poll() is None:
                    if 'SCRIPT ERROR' in log.read_text() or time.monotonic()-started>300:
                        proc.terminate();proc.wait(timeout=15);raise RuntimeError(label+' script error or timeout; see '+str(log))
                    time.sleep(.2)
            finally:
                if proc.poll() is None:proc.kill();proc.wait()
        text=log.read_text()
        if proc.returncode or 'FAIL ' in text or 'SCRIPT ERROR' in text:raise RuntimeError(label+' failed; see '+str(log))
        rows=[]
        for line in text.splitlines():
            if ' {' not in line:continue
            try:row=json.loads(line[line.index('{'):])
            except json.JSONDecodeError:continue
            if isinstance(row,dict) and 'failures' in row:
                if row['failures']:raise RuntimeError(label+' assertions failed')
                rows.append(row)
        reports[label]={'passed':True,'results':rows,'elapsed_seconds':time.monotonic()-started}
        (OUT/'checks.json').write_text(json.dumps(reports,indent=2)+'\n');print(label,'PASS',flush=True)
if __name__=='__main__':main()
