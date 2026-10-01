"""Audition the mastered new cues with existing reports; timeline in JSON."""
from pathlib import Path
import wave,json,subprocess,re
import numpy as np
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'test-results/weapon-actions-20261001';RATE=32000
trims={k:float(v) for k,v in re.findall(r'"([^"]+)":\s*(-?[\d.]+)',(ROOT/'deathmatch/audio/weapon_levels.gd').read_text())}
A='deathmatch/audio/weapon-actions/';M='deathmatch/audio/modes/';D='deathmatch/audio/doom-style/'
rows=[];audio=[]
def read(path):return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(ROOT/path),'-ar',str(RATE),'-ac','1','-f','f32le','-']),dtype='<f4')
def segment(label,cues):
 x=np.zeros(5*RATE);start=sum(len(a) for a in audio)/RATE
 for path,times in cues:
  y=read(path)*10**((trims.get('res://'+path,0)+(-6 if path.startswith(A) else -4))/20)
  for at in times:
   index=round(at*RATE);n=min(len(y),len(x)-index);x[index:index+n]+=y[:n]
 audio.append(x);rows.append({'label':label,'start':start,'end':start+5,'cues':cues})
segment('Doom chainsaw: raise, idle, cut, settle',[(A+'saw_ready.wav',[0]),(A+'saw_idle.wav',[.7,1.92]),(D+'weapon_1.wav',[2.5,2.65,2.8]),(A+'saw_settle.wav',[3.1])])
segment('UT Impact Hammer: pull, charge, release',[(A+'hammer_start.wav',[0]),(A+'hammer_charge.wav',[.2]),(M+'ut99_weapon_0_v0.wav',[1.8])])
segment('UT Bio Rifle: valve, filling, shot, reservoir settle',[(A+'bio_valve.wav',[0]),(A+'bio_charge.wav',[.2]),(M+'ut99_weapon_1_alt_v0.wav',[1.85]),(A+'bio_settle.wav',[2.1])])
segment('UT rocket launcher: chamber load sequence',[(A+'rocket_load.wav',[0,.5,1,1.5,2,2.5]),(M+'ut99_weapon_6_v0.wav',[3]),(A+'launcher_close.wav',[3.55])])
segment('UT minigun: burst and mechanical wind-down',[(A+'rotor_run.wav',[.1]),(M+'ut99_weapon_5_v0.wav',list(np.arange(.2,1.5,.10))),(A+'rotor_stop.wav',[1.75])])
segment('UT pulse gun: energy burst and discharge',[(A+'pulse_run.wav',[.1]),(M+'ut99_weapon_7_v0.wav',list(np.arange(.2,1.4,.12))),(A+'pulse_stop.wav',[1.7])])
segment('Quake lightning: energise, sustain, release',[(A+'lightning_start.wav',[.1]),(A+'lightning_run.wav',[.1]),(M+'quake_weapon_8_v0.wav',list(np.arange(.2,1.4,.1))),(A+'lightning_stop.wav',[1.7])])
segment('Tribes disc launcher: fire and mechanism reseat',[(M+'tribes_weapon_3_v0.wav',[.1]),(A+'disc_reseat.wav',[.88])])
segment('Tribes mortar: fire and breech reset',[(M+'tribes_weapon_7_v0.wav',[.1]),(A+'mortar_reseat.wav',[1.45])])
segment('CS AWP: handling, fire and automatic bolt cycle',[(A+'rifle_draw.wav',[0]),(M+'cs16_weapon_9_v0.wav',[.5]),(A+'bolt_cycle.wav',[1.11])])
x=np.concatenate(audio);peak=float(np.max(np.abs(x)));assert peak<1,peak
with wave.open(str(OUT/'weapon-actions-audition.wav'),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(np.round(x*32767).astype('<i2').tobytes())
(OUT/'audition-timeline.json').write_text(json.dumps(rows,indent=2)+'\n');print('Audition seconds',len(x)/RATE,'peak',20*np.log10(peak))
