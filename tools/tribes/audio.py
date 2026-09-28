"""Original deterministic CC0 weapon Foley; no retail sound samples."""
import math,random,wave,struct
from pathlib import Path
out=Path('tools/tribes/refined')
for w in list(range(12))+['explosion','bounce']:
 r=random.Random(str(w));rate=24000;length=.7 if w=='explosion' else .12 if w in [2,6,8,11,'bounce'] else .35
 data=[]
 for i in range(int(rate*length)):
  t=i/rate;env=math.exp(-t/(length*.22))*min(1,t/.0015);noise=r.uniform(-1,1)
  freq=90 if w in [4,7,9,'explosion'] else 550 if w in [0,1,3,5,6,8,11] else 260
  sweep=math.sin(math.tau*(freq*t-(freq*.5/length)*t*t))
  value=(noise*(.70 if w in [2,4,7,9,10,'explosion','bounce'] else .18)+sweep*.4+math.sin(math.tau*freq*1.97*t)*.1)*env*.7
  data.append(int(max(-1,min(1,value))*32767))
 name='weapon_'+str(w) if isinstance(w,int) else w
 with wave.open(str(out/(name+'.wav')),'wb') as f:f.setparams((1,2,rate,0,'NONE',''));f.writeframes(struct.pack('<'+'h'*len(data),*data))
