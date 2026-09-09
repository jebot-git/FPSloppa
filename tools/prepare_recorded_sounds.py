"""Trim/clean CC0 field recordings into immediate mono weapon transients.
Sources and licenses: deathmatch/audio/recorded/SOURCES.md.
Requires ffmpeg and downloaded gunshots.zip extracted to ~/.cache.
"""
from pathlib import Path
import subprocess
out=Path(__file__).resolve().parents[1]/'deathmatch/audio/recorded'
for weapon,source,times,length in [(2,'cz',[.34,2.82,4.12,5.54],.65),(3,'shotty',[.24],.45),(4,'shotty',[.24],.45),(5,'sks',[.39,2.34,3.38,4.24],.5)]:
 for variant,start in enumerate(times):
  filters='highpass=f=90,afftdn=nf=-25,alimiter=limit=0.85:level=false,afade=t=out:st='+str(length-.12)+':d=0.12,atrim=start=0.03,asetpts=PTS-STARTPTS'
  if weapon==4: filters+=',asetrate=42000,aresample=48000'
  subprocess.run(['ffmpeg','-v','error','-y','-ss',str(start),'-i',str(Path.home()/'.cache'/f'{source}.wav'),'-t',str(length),'-ac','1','-ar','48000','-af',filters,str(out/f'weapon_{weapon}_{variant}.wav')],check=True)
