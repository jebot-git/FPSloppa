"""Package only Pressureworks and Vesper Abbey for TF distribution."""
from pathlib import Path
import argparse,hashlib,json,zipfile
from map_distribution import ROOT,TF_MAPS,tf_files

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir',type=Path,default=ROOT.parent/'Builds')
    args=parser.parse_args();args.output_dir.mkdir(parents=True,exist_ok=True)
    version=(ROOT/'VERSION').read_text().strip()
    path=args.output_dir/f'FPSloppa-{version}-Original-TF-Arenas.zip'
    files=tf_files()+[Path('TF.md'),Path('tools/generate_tf_maps.py')]
    files += [p.relative_to(ROOT) for folder in ['pressureworks','vesper'] for p in (ROOT/'tools'/folder).iterdir() if p.suffix in {'.py','.gd'}]
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as z:
        for source in sorted(set(files)):z.write(ROOT/source,source)
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None
        assert {Path(n).stem for n in z.namelist() if n.endswith('.bsp')}==set(TF_MAPS)
        assert z.read('maps/tf_maplist.txt').decode().split()==list(TF_MAPS)
    receipt={'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':path.stat().st_size,'maps':list(TF_MAPS)}
    (args.output_dir/f'FPSloppa-{version}-TF-checksums.json').write_text(json.dumps([receipt],indent=2)+'\n')
    print(path);print(json.dumps(receipt))
if __name__=='__main__':main()
