"""Prepare approved CC0 main-menu/lobby themes using the mode soundtrack pipeline."""
from pathlib import Path
import argparse,json
from prepare_mode_music import prepare,OUT
CONTEXTS=OUT.parent/'contexts'
MANIFEST=OUT.parent/'contexts.json'
TRACKS=[('title','Shadows Awaken Within','vitalezzz','shadows-awaken-within','shadows_awaken_within.wav',False),
        ('lobby','Singularity — Calm','vitalezzz','singularity-0','singularity_calm.wav',True)]
def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--only',nargs='+')
 parser.add_argument('--cache',type=Path,default=Path.home()/'.cache/fpsloppa-oga-mode-music')
 args=parser.parse_args();args.cache.mkdir(parents=True,exist_ok=True);CONTEXTS.mkdir(parents=True,exist_ok=True)
 previous={r['key']:r for r in json.loads(MANIFEST.read_text())} if MANIFEST.exists() else {}
 for track in TRACKS:
  if not args.only or track[0] in args.only:previous[track[0]]=prepare(track,args.cache,previous,CONTEXTS)
 MANIFEST.write_text(json.dumps([previous[t[0]] for t in TRACKS if t[0] in previous],indent=2,ensure_ascii=False)+'\n')
if __name__=='__main__':main()
