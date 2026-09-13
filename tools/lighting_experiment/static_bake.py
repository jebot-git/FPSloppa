#!/usr/bin/env python3
"""Stage targeted static refinements without changing geometry or authored entities."""
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.lighting_experiment.preserve_layout import preserve
from tools.lighting_experiment.bake import sha, verify

OUT = ROOT/'test-results/static-rendering'
LIGHT = Path('/tmp/hislop-ericw/ericw-tools-v0.18-Linux/bin/light')
FLAGS = ['-threads','8','-extra4','-bspxlit','-bounce','1',
         '-bouncecolorscale','0.20','-sunsamples','128','-sunlight_penumbra','6',
         '-dirt','1','-dirtdepth','32','-dirtscale','0.5','-minlight_dirt','1']

def main():
    report = {'compiler': str(LIGHT), 'compiler_sha256': sha(LIGHT.read_bytes()), 'maps': []}
    for name, bounce_scale in [('tf_pressureworks','1.15'),('tf_vesper','1.20')]:
        source = ROOT/'maps'/(name+'.bsp')
        original = source.read_bytes()
        snapshot = OUT/'original'/source.name
        snapshot.parent.mkdir(parents=True,exist_ok=True)
        if snapshot.exists():assert snapshot.read_bytes()==original, 'Baseline changed'
        else:snapshot.write_bytes(original)
        target = OUT/'candidate'/source.name
        target.parent.mkdir(exist_ok=True)
        target.write_bytes(original)
        flags = FLAGS+['-bouncescale',bounce_scale]
        start = time.monotonic()
        with (target.with_suffix('.log')).open('w') as log:
            subprocess.run([str(LIGHT),*flags,str(target)],stdout=log,stderr=subprocess.STDOUT,check=True)
        normalized, layout = preserve(original,target.read_bytes())
        target.write_bytes(normalized)
        checks = verify(original,normalized)
        report['maps'].append({'id':name,'flags':flags,'seconds':time.monotonic()-start,
            'original_sha256':sha(original),'sha256':sha(normalized), **layout, **checks})
        print(name, 'validated geometry/styles,', round(time.monotonic()-start,2), 's',flush=True)
    (OUT/'bake.json').write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':main()
