"""Recorded weapon machinery/charge/recovery cues; no gameplay audio timing changes.
Requires the Audacity-edited stems from edit_weapon_action_stems.py.
"""
from pathlib import Path
import sys,json,hashlib,subprocess,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from build_mode_audio import band
RATE=32000;SOURCE=ROOT/'tools/audio-sources/weapon-actions';OUT=ROOT/'deathmatch/audio/weapon-actions';OUT.mkdir(parents=True,exist_ok=True)
sources={};report=[]
def read(path):
 path=ROOT/path;sources[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
 x=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-ac','1','-ar',str(RATE),'-f','f32le','-']),dtype='<f4').astype(float)
 return x/max(np.max(np.abs(x)),1e-9)
def piece(x,duration,start=0,pitch=1):
 n=round(duration*RATE);positions=start*RATE+np.arange(n)*pitch
 return np.interp(positions,np.arange(len(x)),x,left=0,right=0)
def stretch(x,duration,p0=1,p1=1,offset=0):
 n=round(duration*RATE);positions=np.cumsum(np.linspace(p0,p1,n))+offset*RATE
 return np.interp(positions%len(x),np.arange(len(x)),x)
def combine(duration,*layers):
 result=np.zeros(round(duration*RATE))
 for x,delay,gain in layers:
  start=round(delay*RATE);n=min(len(x),len(result)-start)
  if n>0:result[start:start+n]+=x[:n]*gain
 return result
def save(name,x,loop=False,target=-23):
 x=x-np.mean(x)
 if loop:
  # Equal-gain overlap: tail-to-head crossfade, no silence at repeat boundary.
  edge=min(round(.065*RATE),len(x)//5);a=np.linspace(0,1,edge)
  x=np.r_[x[edge:-edge],x[-edge:]*(1-a)+x[:edge]*a]
  x[-1]=x[0]
 else:
  edge=min(96,len(x)//8);x[:edge]*=np.linspace(0,1,edge)
  edge=min(round(.025*RATE),len(x)//4);x[-edge:]*=np.linspace(1,0,edge)
 window=min(len(x),RATE//20);integral=np.r_[0,np.cumsum(x*x)];body=np.sqrt(np.max(integral[window:]-integral[:-window])/window)
 x*=min(10**(-6/20)/max(np.max(np.abs(x)),1e-9),10**(target/20)/max(body,1e-9))
 path=OUT/(name+'.wav')
 with wave.open(str(path),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(np.round(x*32767).astype('<i2').tobytes())
 report.append({'name':name,'loop':loop,'seconds':len(x)/RATE,'target_body_dbfs':target,'peak_dbfs':20*np.log10(max(np.max(np.abs(x)),1e-9)),'boundary_step':float(abs(x[0]-x[-1])),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
E='tools/audio-sources/weapon-actions/edited/'
motor=read(E+'motor.wav');wet=read(E+'liquid.wav');air=read(E+'pressure.wav');mech=read(E+'mechanism.wav')
metal=read('deathmatch/audio/recorded/impactMetal_light_002.ogg');pump=read('tools/audio-sources/natural-weapons/shotguncock.wav')
saw=read(E+'saw_idle.wav');ready=read(E+'saw_ready.wav')
save('saw_idle',stretch(saw,1.35),True,-28);save('saw_ready',piece(ready,min(.7,len(ready)/RATE)),target=-21)
save('saw_settle',stretch(saw,.28,1.25,.70)*np.linspace(1,0,round(.28*RATE)),target=-24)
rotor=band(stretch(motor,1.7,.95,1.03,.4),95,4200)+.18*band(stretch(saw,1.7,.55,.6),400,3300)
save('rotor_run',rotor,True,-28)
save('rotor_start',stretch(rotor,.26,.4,1.2)*np.linspace(.25,1,round(.26*RATE)),target=-22)
save('rotor_stop',stretch(rotor,.50,1.05,.3)*np.linspace(1,0,round(.50*RATE)),target=-22)
hammer=band(stretch(motor,1.6,.55,.55,1),70,1900)+.13*band(stretch(air,1.6,1.3,1.3,3),500,4500)
save('hammer_charge',hammer,True,-24);save('hammer_start',combine(.22,(piece(mech,.18,.05,.8),0,.8),(piece(air,.18,3),.04,.2)),target=-22)
save('pressure_release',band(piece(air,.30,5,1.7),450,6000)*np.linspace(1,0,round(.30*RATE)),target=-24)
save('bio_charge',band(stretch(wet,1.7,.70,.76),70,4000),True,-24)
save('bio_valve',combine(.22,(piece(mech,.12,.1),0,.25),(piece(wet,.20,.07,.65),.02,.8)),target=-23)
save('bio_settle',piece(wet,.30,.22,.6)*np.linspace(1,0,round(.30*RATE)),target=-24)
save('rocket_load',combine(.22,(piece(mech,.15,.04,.8),0,.65),(piece(metal,.1,0,.7),.10,.22)),target=-21)
save('launcher_close',combine(.30,(piece(pump,.21,.06,.8),0,.75),(piece(metal,.11,0,.6),.16,.3)),target=-22)
electric=band(stretch(motor,1.5,2.6,2.6,2),500,5500)+.18*band(stretch(metal,1.5,1.15,1.15),1500,6200)
save('pulse_run',electric,True,-29);save('pulse_stop',stretch(electric,.4,1,.45)*np.linspace(1,0,round(.4*RATE)),target=-22)
save('energy_select',combine(.24,(piece(mech,.17,.1,1.15),0,.6),(piece(electric,.20,.1),.04,.18)),target=-23)
save('lightning_start',combine(.14,(piece(metal,.13,0,1.3),0,.35),(piece(electric,.14),0,.6)),target=-23)
save('lightning_run',band(stretch(electric,1.4,.60,.60),150,3500),True,-29)
save('lightning_stop',piece(electric,.19,.45)*np.linspace(1,0,round(.19*RATE)),target=-25)
save('disc_reseat',combine(.4,(stretch(motor,.3,1.5,.5,1),0,.2),(piece(mech,.16,.08),.2,.8),(piece(metal,.10,0,1.2),.28,.25)),target=-22)
save('plasma_vent',combine(.28,(band(piece(air,.28,4,1.4),250,4500),0,.55),(piece(metal,.17,0,.7),.05,.15)),target=-25)
save('laser_reset',combine(.23,(piece(electric,.18,.3,1.5),0,.35),(piece(mech,.14,.06,1.2),.09,.4)),target=-24)
save('mortar_reseat',combine(.52,(piece(pump,.35,0,.65),0,.7),(piece(metal,.16,0,.48),.30,.4)),target=-21)
save('elf_run',band(stretch(electric,1.65,.8,.8),200,3400),True,-28)
save('repair_run',band(stretch(motor,1.7,1.8,1.8,.6),300,2800)+.1*band(stretch(air,1.7,1.2,1.2,3),1200,4200),True,-30)
save('flame_ignite',combine(.20,(piece(metal,.09,0,1.5),0,.16),(band(piece(air,.20,3,1.6),100,4800),0,.85)),target=-23)
save('flame_out',band(piece(air,.32,4,.75),100,2900)*np.linspace(1,0,round(.32*RATE)),target=-24)
save('pistol_draw',piece(mech,.18,.02,1.25),target=-23)
save('rifle_draw',combine(.25,(piece(mech,.2,.06,.9),0,.85),(piece(metal,.08,0,.8),.17,.12)),target=-23)
save('bolt_cycle',combine(.42,(piece(mech,.18,.02,.85),0,.75),(piece(pump,.19,.15,1.0),.21,.7)),target=-22)
(OUT/'manifest.json').write_text(json.dumps({'sample_rate':RATE,'files':report,'sources':sources,'mastering':'Audacity MCP edited stems; 50ms RMS role targets with -6 dBFS sample ceiling; gapless overlap for loops'},indent=2)+'\n')
(OUT/'catalog.gd').write_text('extends RefCounted\n# Generated by tools/build_weapon_actions.py.\nconst SOUNDS = '+json.dumps({r['name']:{'path':'res://deathmatch/audio/weapon-actions/'+r['name']+'.res','loop':r['loop']} for r in report},indent='\t')+'\n')
print('Authored',len(report),'weapon action cues')
