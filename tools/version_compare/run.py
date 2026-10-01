#!/usr/bin/env python3
"""Sequential ABBA comparison of two prepared, isolated Godot release projects."""
from pathlib import Path
import hashlib,json,os,subprocess,statistics,time,sys
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/version-comparison'
PROJECTS={'0.20':Path('/tmp/fps-version-020'),'current':Path('/tmp/fps-version-current')}
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def distribution(values):
 s=sorted(values)
 return dict(median=statistics.median(s),mean=statistics.mean(s),p95=s[min(len(s)-1,int(len(s)*.95))],p99=s[min(len(s)-1,int(len(s)*.99))])
def main():
 OUT.mkdir(exist_ok=True)
 manifest={'baseline_commit':subprocess.check_output(['git','rev-parse','0.20v^{}'],cwd=ROOT,text=True).strip(),'current_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'current_includes_working_tree':True,'fixture_sha256':digest(ROOT/'tools/version_compare/fixture.gd'),'runtime_sha256':digest(PROJECTS['0.20']/'FPSloppa'),'native_sha256':{k:digest(v/'addons/fps_native/bin/libfpsloppa_native.so') for k,v in PROJECTS.items()},'cpu':subprocess.check_output(['lscpu'],text=True),'scope':'8 animated VRM avatars; 1440x900 Vulkan Mobile; vsync off; 6s warmup +20s capture; unarmed and armed; no game map, AI, networking, audio, XR or compositor; CPU means main-thread scheduler time per frame, excludes worker threads; render CPU is a separate viewport query; disk cache disabled for controlled setup; no resource loading during capture.'}
 assert digest(PROJECTS['current']/'FPSloppa')==manifest['runtime_sha256']
 sources={p.relative_to(ROOT).as_posix():digest(p) for parent in ['deathmatch','addons/vrm','addons/Godot-MToon-Shader','addons/fps_native/src'] for p in (ROOT/parent).rglob('*') if p.is_file() and p.suffix in ['.gd','.gdshader','.scn','.glb','.png','.cpp','.h']}
 (OUT/'current-sources.json').write_text(json.dumps(sources,indent=2))
 manifest['current_sources_sha256']=digest(OUT/'current-sources.json')
 (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
 only_unarmed='--unarmed-only' in sys.argv
 rows=[r for r in json.loads((OUT/'runs.json').read_text()) if r['variant']=='armed'] if only_unarmed else []
 if only_unarmed:
  manifest['armed_fixture_sha256']=json.loads((OUT/'armed-manifest.json').read_text())['fixture_sha256']
  manifest['fixture_note']='Unarmed rerun removes fallback gun instances. Armed workload unchanged; its original manifest is retained.'
  (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
 for variant in (['unarmed'] if only_unarmed else ['unarmed','armed']):
  for index,version in enumerate(['0.20','current','current','0.20']):
   project=PROJECTS[version];name=f'{variant}-{index}-{version}';dest=OUT/name
   command=[str(project/'FPSloppa'),'--xr-mode','off','--audio-driver','Dummy','--',str(dest),variant,'20','--no-avatar-disk-cache']
   env=dict(os.environ,XDG_DATA_HOME='/tmp/fps-version-user-'+version)
   print('START',name,flush=True)
   with dest.with_suffix('.log').open('w') as log:
    completed=subprocess.run(command,cwd=project,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=75)
   text=dest.with_suffix('.log').read_text()
   if completed.returncode or 'ERROR:' in text or 'WARNING:' in text or 'leaked' in text:raise RuntimeError(name+': exit '+str(completed.returncode)+' '+text)
   report=json.loads(Path(str(dest)+'.json').read_text());meta=report['metadata'];frames=report['frames']
   assert meta['native_pose'] and meta['sleeping']==0 and meta['measured_seconds']>=19.99
   assert meta['main_cpu_ms_per_frame']>0 and all(f[2]>0 for f in frames)
   row=dict(version=version,variant=variant,run=index,frames=len(frames),metadata=meta,**{k:distribution([f[i] for f in frames]) for i,k in enumerate(report['columns'])})
   rows.append(row);(OUT/'runs.json').write_text(json.dumps(rows,indent=2))
   print('DONE',name,'mainCPU',round(meta['main_cpu_ms_per_frame'],3),'renderCPU',round(row['render_cpu_ms']['median'],3),'GPU',round(row['gpu_ms']['median'],3),'frame',round(row['frame_ms']['median'],3),flush=True)
 for name,sha in sources.items():assert digest(ROOT/name)==sha, 'Source changed during capture: '+name
 comparisons={}
 for variant in ['unarmed','armed']:
  stats={}
  for version in PROJECTS:
   group=[r for r in rows if r['version']==version and r['variant']==variant]
   stats[version]={'main_cpu_ms_per_frame':statistics.mean(r['metadata']['main_cpu_ms_per_frame'] for r in group),**{key:statistics.mean(r[key]['median'] for r in group) for key in ['frame_ms','render_cpu_ms','gpu_ms','draw_calls','primitives']},'frame_p95_ms':statistics.mean(r['frame_ms']['p95'] for r in group)}
  comparisons[variant]={'versions':stats,'change_percent':{k:100*(stats['current'][k]/stats['0.20'][k]-1) for k in stats['0.20']}}
 (OUT/'summary.json').write_text(json.dumps({'manifest':manifest,'comparisons':comparisons,'runs':rows},indent=2))
 print(json.dumps(comparisons,indent=2),flush=True)
if __name__=='__main__':main()
