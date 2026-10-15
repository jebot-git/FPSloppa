"""Test all 45 audio imports in an isolated PCK with no loose source audio."""
import argparse,json,re,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main(godot):
 with tempfile.TemporaryDirectory(prefix='cq-field-pack-') as temp:
  stage=Path(temp);base=ROOT/'deathmatch/audio/cq_field';rows=[]
  def add(path,name=None):rows.append({'path':'res://'+(name or path.relative_to(ROOT).as_posix()),'source':str(path)})
  add(base/'manifest.json')
  for imported in sorted(base.glob('*.import')):
   add(imported)
   for target in sorted(set(re.findall(r'res://(\.godot/imported/[^"\n]+)',imported.read_text()))):add(ROOT/target)
  project=stage/'project.godot';project.write_text('config_version=5\n[application]\nconfig/name="CQ field audio import validation"\n')
  add(project,'project.godot');add(ROOT/'deathmatch/tests/cq_field_pack.gd','pack_test.gd')
  pack=stage/'audio.pck';manifest=stage/'manifest.json';manifest.write_text(json.dumps({'output':str(pack),'files':rows}))
  subprocess.run([godot,'--headless','--xr-mode','off','--path',str(ROOT),'--script','deathmatch/server/package.gd','--',str(manifest)],check=True,timeout=60)
  subprocess.run([godot,'--headless','--xr-mode','off','--path',str(stage),'--main-pack',str(pack),'--script','res://pack_test.gd'],check=True,timeout=60)
if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--godot',default='godot');main(parser.parse_args().godot)
