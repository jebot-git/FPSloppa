"""Prepare the CC0 source snippets listed in music/SOURCES.md from a download directory.
Usage: python3 tools/prepare_instrument_samples.py /tmp/entryway-instruments
The names guitar.wav, mute.wav, bass.wav and kick/snare/hat/crash.flac are expected.
Use --vsco for piano/flute/strings/anvil.wav instead (pinned in vsco-sources.json).
"""
from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[1]/'deathmatch/audio/music/samples'
vsco='--vsco' in sys.argv
entries=[('piano',6),('flute',6),('strings',6),('anvil',6)] if vsco else [('guitar',1.5),('mute',.55),('bass',2),('kick',.6),('snare',.5),('hat',.15),('crash',1.1)]
for name,seconds in entries:
    source=Path(sys.argv[1])/(name+('.wav' if vsco or name in ('guitar','mute','bass') else '.flac'))
    subprocess.run(['ffmpeg','-y','-v','error','-i',str(source),'-t',str(seconds),'-ac','1','-ar','22050','-map_metadata','-1','-c:a','pcm_s16le',str(root/(name+'.wav'))],check=True)
