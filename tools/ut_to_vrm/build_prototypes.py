#!/usr/bin/env python3
"""Build three experimental VRMs from already extracted original Rumiko assets."""
import argparse
import json
from pathlib import Path
import subprocess

from prepare_rumiko import build
from rig_rumiko import rig


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('export_root',type=Path)
    parser.add_argument('output_directory',type=Path)
    parser.add_argument('--godot',default='godot')
    args=parser.parse_args()
    out=args.output_directory.resolve();out.mkdir(parents=True,exist_ok=True)
    converter=Path(__file__).resolve().parents[1]/'avatar_converter'
    results=[]
    for variant in ['purple','black','fur']:
        name='AsiaCarrera-Rumiko-'+variant
        build(args.export_root,out/(name+'-unrigged.glb'),variant='original-'+variant)
        rig(out/(name+'-unrigged.glb'),out/(name+'-rigged.glb'))
        work=out/('work-'+variant);work.mkdir()
        def job_run(job,action):
            job.update(action=action,work=str(work),result=str(work/(action+'.json')))
            path=work/(action+'-job.json');path.write_text(json.dumps(job,indent=2))
            cmd=[args.godot,'--headless','--log-file',str(work/'godot.log'),'--path',str(converter),'--','--job',str(path)]
            process=subprocess.run(cmd,capture_output=True,text=True)
            (work/(action+'.log')).write_text(process.stdout+process.stderr)
            result=json.loads(Path(job['result']).read_text())
            if process.returncode or 'error' in result:
                raise RuntimeError(result.get('error',f'Godot exited {process.returncode}'))
            return result
        inspected=job_run({'input':str(out/(name+'-rigged.glb'))},'inspect')
        if inspected['mapping_errors']:raise ValueError(inspected['mapping_errors'])
        results.append(job_run(dict(inspected,
            output=str(out/(name+'-experimental.vrm')),
            title='Asia Carrera Rumiko '+variant.title()+' - Experimental UT99 Rig',
            author='Asia Carrera (skin); Roger [666] Bacon (Rumiko mesh)',texture_limit=0),'export'))
    (out/'conversion-results.json').write_text(json.dumps(results,indent=2)+'\n')


if __name__=='__main__':main()
