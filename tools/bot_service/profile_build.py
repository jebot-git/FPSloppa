#!/usr/bin/env python3
"""Instrument an isolated console resource pack; never edit production game scripts."""
from pathlib import Path
import argparse,json,re,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/katabatic'))
from performance import instrument

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 base=ROOT/'Builds/BotServiceServer'
 shutil.copy2(base/'FPSloppaServer.x86_64',out/'FPSloppaServer.x86_64')
 (out/'addons').symlink_to(base/'addons',target_is_directory=True)
 work=out/'instrumentation';work.mkdir()
 manifest=json.loads((ROOT/'test-results/console-server-package/pack.json').read_text());manifest['output']=str(out/'FPSloppaServer.pck')
 methods={'deathmatch/arena.gd':['_physics_process','_server_tick'],'deathmatch/bots.gd':['tick'],'deathmatch/bot_service/server.gd':['_process','consume']}
 for row in manifest['files']:
  path=row['path'].removeprefix('res://')
  if path not in methods:continue
  source=instrument(Path(row['source']).read_text(),path,methods[path])
  if path=='deathmatch/arena.gd':source=source.replace('func _ready() -> void:', 'func _ready() -> void:\n\tadd_child(preload("res://bot_profile_reader.gd").new())')
  target=work/path.replace('/','_');target.write_text(source);row['source']=str(target)
 profile=work/'kat_profile.gd';profile.write_text('''extends RefCounted
static var enabled:=false
static var starts:=0
static var ends:=0
static var rows: Dictionary={}
static func add(label: String,elapsed: int):
 if not enabled or Time.get_ticks_msec()<starts or Time.get_ticks_msec()>=ends:return
 if not rows.has(label):rows[label]=[]
 if rows[label].size()<12000:rows[label].append(elapsed/1000.0)
''')
 reader=work/'bot_profile_reader.gd';reader.write_text('''extends Node
const P=preload("res://kat_profile.gd")
var path:=""
var next:=0
func _ready():
 var args:=OS.get_cmdline_user_args();var index:=args.find("--bot-benchmark-output")
 if index<0:set_process(false);return
 path=args[index+1];P.enabled=true;P.starts=Time.get_ticks_msec()+30000;P.ends=P.starts+30000
func _process(_delta: float):
 if Time.get_ticks_msec()<P.starts or Time.get_ticks_msec()<next:return
 next=Time.get_ticks_msec()+5000
 var result: Dictionary={}
 for key in P.rows:
  var rows: Array=P.rows[key].duplicate();rows.sort()
  if rows.is_empty():continue
  var total:=0.0
  for value in rows:total+=value
  result[key]={"count":rows.size(),"mean":total/rows.size(),"median":rows[rows.size()/2],"p95":rows[int(rows.size()*.95)],"p99":rows[int(rows.size()*.99)],"max":rows[-1]}
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
''')
 for name,file in [('kat_profile.gd',profile),('bot_profile_reader.gd',reader)]:manifest['files'].append({'path':'res://'+name,'source':str(file)})
 pack=work/'pack.json';pack.write_text(json.dumps(manifest,indent=2))
 subprocess.run(['godot','--headless','--xr-mode','off','--log-file',str(work/'pack.log'),'--path',str(ROOT),'--script','res://deathmatch/server/package.gd','--',str(pack)],check=True)
 print(out/'FPSloppaServer.x86_64')
if __name__=='__main__':main()
