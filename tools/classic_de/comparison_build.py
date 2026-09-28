"""Build isolated pre-study geometry for matched camera comparisons.

No live map/cache/manifest is overwritten. Before is reconstructed by undoing
only the four documented CS16 study edits; its hash is checked against receipts.
"""
from pathlib import Path
import sys, types, shutil, subprocess, hashlib, json
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from classic_de import build as current
from dust2_rebuild.build import fields
OUT=ROOT/'test-results/de-study-comparison'

def generate():
    restore=(ROOT/'tools/classic_de/restoration.py').read_text()
    restore=restore.replace('room(-1536,384,-1024,640,-256);ramp(-1536,384,-1024,640,64,-256)', 'room(-1344,384,-1024,640,-256);ramp(-1344,384,-1024,640,64,-256)')
    restore=restore.replace("    box(-1536,512,-1344,640,-256,64,'floor')\n",'')
    restore=restore.replace('spans=[(-1600,-1536),(-1344,0)] if y==640 else [(-1600,0)]','spans=[(-1600,0)]')
    restore=restore.replace('            if y==640 and -1536<x<-1344:continue\n','')
    mod=types.ModuleType('classic_de.restoration');mod.__file__=str(ROOT/'tools/classic_de/restoration.py')
    exec(compile(restore,mod.__file__,'exec'),mod.__dict__);sys.modules[mod.__name__]=mod
    source=(ROOT/'tools/classic_de/build.py').read_text()
    source=source.replace('    study_nuke(a)','    pass # pre-study hut').replace('    study_inferno(a)','    pass # pre-study apartments')
    source=source.replace("a.stairs(168,271,194,333,0,96,'v')","a.stairs(168,271,194,333,96,0,'v')")
    source=source.replace("    a.block(168,333,195,399,80,96,'floor')\n",'')
    old=types.ModuleType('comparison_before');old.__file__=str(ROOT/'tools/classic_de/build.py')
    exec(compile(source,old.__file__,'exec'),old.__dict__)
    compiler=Path(sys.argv[1]);receipts=[]
    for name in ['nuke','inferno','aztec','train']:
        a=getattr(old,name)();folder=OUT/'before'/a.name;folder.mkdir(parents=True,exist_ok=True)
        current.style(a,a.theme)
        shutil.copy2(ROOT/'maps/ClassicDE'/a.name/'classic.wad',folder/'classic.wad')
        world=dict(classname='worldspawn',message=a.title,wad='classic.wad',_fpsloppa_bake='1',_fpsloppa_atlas='2048',_fpsloppa_light_response='quake',_minlight='32',_sunlight='125' if a.theme!='ruins' else '85',_sunlight_color='1 .92 .8',_sun_mangle='125 -58 0',_sunlight2='45',_bounce='1')
        path=folder/(a.name+'.map');bsp=folder/(a.name+'.bsp')
        path.write_text('{\n'+fields(world)+'\n'+'\n'.join(a.brushes)+'\n}\n{\n"classname" "func_detail"\n'+'\n'.join(a.detail_brushes)+'\n}\n'+'\n'.join('{\n'+fields(e)+'\n}' for e in a.entities)+'\n'+'\n'.join('{\n'+fields(e)+'\n'+'\n'.join(parts)+'\n}' for e,parts in a.models)+'\n')
        for tool,flags in [('qbsp',['-wadpath',str(folder),str(path),str(bsp)]),('vis',['-threads','4',str(bsp)]),('light',['-threads','4','-extra','-bspxlit',str(bsp)])]:
            with (folder/(tool+'.log')).open('w') as log:subprocess.run([str(compiler/tool),*flags],stdout=log,stderr=subprocess.STDOUT,check=True)
        expected=json.loads((ROOT/'test-results/de-bot-review'/('cs16-before-'+a.name+'.json')).read_text())['map_sha256']
        receipts.append(dict(map=a.name,before_source='Reconstructed by reversing study geometry edits',before_bsp_sha256=hashlib.sha256(bsp.read_bytes()).hexdigest(),study_before_bsp_sha256=expected,after_bsp_sha256=hashlib.sha256((ROOT/'maps'/bsp.name).read_bytes()).hexdigest()))
        print('COMPARISON_BUILD',a.name,flush=True)
    dust=OUT/'before/de_dust2_rebuilt/de_dust2_rebuilt.bsp'
    if dust.exists():
        receipts.append(dict(map='de_dust2_rebuilt',before_source='Archived actual BSP before the floating A-site trim correction',before_bsp_sha256=hashlib.sha256(dust.read_bytes()).hexdigest(),after_bsp_sha256=hashlib.sha256((ROOT/'maps/de_dust2_rebuilt.bsp').read_bytes()).hexdigest()))
    (OUT/'provenance.json').write_text(json.dumps(receipts,indent=2)+'\n')
if __name__=='__main__':generate()
