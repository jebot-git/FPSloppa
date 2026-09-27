"""Original short mechanical Foley synthesis; deterministic and dedicated to CC0."""
import math, random, struct, wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tools/cs16/reload_audio';OUT.mkdir(exist_ok=True);(OUT/'.gdignore').touch()
# Delay, gain, noise decay, metallic resonance.
CUES={
 'mag_out':[(0,.48,.020,850),(.045,.25,.024,420)],
 'mag_in':[(0,.28,.028,320),(.074,.68,.018,1250)],
 'rack_back':[(0,.35,.052,650),(.052,.52,.020,1550)],
 'rack_close':[(0,.28,.025,980),(.032,.65,.026,480)],
 'empty_lock':[(0,.7,.019,1900),(.020,.38,.016,1100)],
 'snip':[(0,.14,.009,2100),(.038,.75,.012,2850),(.052,.20,.009,3700),(.118,.12,.016,1750)],
}
for name,impulses in CUES.items():
 rng=random.Random(name);rate=24000;data=[]
 for i in range(int(rate*.22)):
  t=i/rate;value=0
  for delay,gain,decay,freq in impulses:
   at=t-delay
   if at>=0:
    envelope=math.exp(-at/decay)*min(1,at/.0008)
    value+=gain*envelope*(rng.uniform(-1,1)*.66+math.sin(math.tau*freq*at)*.24+math.sin(math.tau*freq*1.63*at)*.10)
  data.append(max(-32767,min(32767,round(value*24000))))
 with wave.open(str(OUT/(name+'.wav')),'wb') as out:
  out.setparams((1,2,rate,0,'NONE','not compressed'));out.writeframes(struct.pack('<'+'h'*len(data),*data))
print('Wrote',len(CUES),'original mechanical Foley cues')
