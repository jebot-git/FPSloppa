#!/usr/bin/env python3
"""Exercise real CQ admission and full client presentation on a separate local port."""
import argparse,json,os,signal,subprocess,time
from pathlib import Path
from run_suite import ROOT,source_manifest,digest
import sys
sys.path.insert(0,str(ROOT/'tools'))
from build_gameplay_native import require_build

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',default='godot');p.add_argument('--output',type=Path,required=True);p.add_argument('--port',type=int,default=27949);a=p.parse_args()
 out=a.output.resolve()
 if out.exists() and any(out.iterdir()):p.error('Output must be new/empty')
 out.mkdir(parents=True,exist_ok=True);library=require_build('linux',server=True);before=source_manifest();lib_hash=digest(library)
 config=(ROOT/'tools/voxel_battle/cq_classes.cfg').read_text().replace('"7777"',f'"{a.port}"');(out/'server.cfg').write_text(config+'\nset sv_voice "0"\n')
 base=[a.godot,'--verbose','--headless','--xr-mode','off','--path',str(ROOT)];jobs=[];results=[]
 try:
  with (out/'server.log').open('w') as log:
   server=subprocess.Popen(base+['res://tools/voxel_battle/class_arena.tscn','--','--server','--config',str(out/'server.cfg')],stdout=log,stderr=subprocess.STDOUT,start_new_session=True);jobs.append(server)
   deadline=time.monotonic()+60
   while 'CQ_RESIDENT_READY' not in (out/'server.log').read_text():
    if server.poll() is not None or time.monotonic()>deadline:raise RuntimeError('Arena startup failed')
    time.sleep(.1)
   for name in ['desktop','tracked']:
    with (out/f'{name}.log').open('w') as client_log:
     args=base+['--script','res://tools/authority_core/arena_driver.gd','--','--connect','127.0.0.1','--port',str(a.port),'--authority-client-report',str(out/f'{name}.json')]
     if name=='tracked':args+=['--authority-tracked']
     client=subprocess.Popen(args,stdout=client_log,stderr=subprocess.STDOUT,start_new_session=True);jobs.append(client)
     if client.wait(timeout=75):raise RuntimeError(f'{name} arena client failed')
    text=(out/f'{name}.log').read_text()
    if 'ERROR:' in text or 'WARNING:' in text:raise RuntimeError(f'{name} arena diagnostics; inspect log')
    results.append(json.loads((out/f'{name}.json').read_text()))
   if 'ERROR:' in (out/'server.log').read_text():raise RuntimeError('Arena server diagnostics')
 finally:
  for job in jobs:
   if job.poll() is None:
    os.killpg(job.pid,signal.SIGTERM)
    try:job.wait(timeout=5)
    except subprocess.TimeoutExpired:os.killpg(job.pid,signal.SIGKILL);job.wait()
 bot_config=out/'bots.cfg';bot_config.write_text(config.replace('sv_bot_fill "0"','sv_bot_fill "4"')+'\nset sv_voice "0"\n')
 with (out/'bots.log').open('w') as log:
  result=subprocess.run(base+['--script','res://tools/authority_core/bot_driver.gd','--','--server','--config',str(bot_config),'--authority-client-report',str(out/'bots.json')],stdout=log,stderr=subprocess.STDOUT,timeout=210)
 bot_log=(out/'bots.log').read_text()
 # Keep known authored-navmesh edge merge warnings in the evidence, without
 # confusing them with new authority/script errors or suppressing engine logs.
 warnings=[line for line in bot_log.splitlines() if line.startswith('WARNING:')]
 if result.returncode or 'ERROR:' in bot_log or any(not line.startswith('WARNING: Navigation region synchronization had ') for line in warnings):raise RuntimeError('Real map bot/navigation test failed')
 bot_result=json.loads((out/'bots.json').read_text());bot_result['authored_navmesh_warnings']=len(warnings);results.append(bot_result)
 if source_manifest()!=before or digest(library)!=lib_hash:raise RuntimeError('Source/library changed during arena test')
 (out/'summary.json').write_text(json.dumps({'cases':results,'source_sha256':before,'library_sha256':lib_hash},indent=2));print(json.dumps(results))
if __name__=='__main__':main()
