"""Fetch pinned CC0 VSCO recordings used by the CQ score (no songs/reference audio)."""
from pathlib import Path
import concurrent.futures, hashlib, json, urllib.request, urllib.parse
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tools/cq_audio/samples'
COMMIT='440300901dfe9275fd84e0b7763af1f8443ae62e'
BASE=f'https://raw.githubusercontent.com/sgossner/VSCO-2-CE/{COMMIT}/'
SOURCES=[]
def pitched(group,folder,pattern,notes):
    for note in notes.split():
        midi=(int(note[-1])+2)*12+{'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}[note[0]]+(1 if '#' in note else 0)
        SOURCES.append(dict(name=f'{group}_{note}',group=group,midi=midi,path=folder+'/'+pattern.format(note=note)))
for velocity,label in [(1,'horn_soft'),(3,'horn')]:
    pitched(label,'Brass/F Horn/sus',f'MOHorn_sus_{{note}}_v{velocity}_1.wav','D2 A2 C3')
pitched('trombone','Brass/Tenor Trombone/sus','tenortbn_sus_{note}_v3_1.wav','D2 F2 C3')
pitched('trumpet','Brass/Trumpet/sus','Sum_SHTrumpet_sus_{note}_v3_rr1.wav','C3 G3 D4')
pitched('violin_short','Strings/Violin Section/Spic','VlnEns_Spic_{note}_v2_rr1.wav','D3 A3 C4 G4')
pitched('violin','Strings/Violin Section/susVib','VlnEns_susVib_{note}_v1.wav','D3 A3 C4')
pitched('cello','Strings/Cello Section/susvib','susvib_{note}_v3_1.wav','D2 A2')
pitched('cello_short','Strings/Cello Section/spic','spic_{note}_v2_RR1.wav','D2 A2')
for name,path in {
 'bass_drum':'BDrumNewhit_v5_rr1_Sum.wav', 'snare':'Snare2-HitSN_v5_rr1_Sum.wav',
 'snare_soft':'Snare2-HitSN_v1_rr1_Sum.wav','cymbal':'cymbal-crash1_mf_rr1.wav',
 'timpani':'Timpani/Timpani3_Hit_v3_rr1_Sum.wav',
}.items():SOURCES.append(dict(name=name,group=name,midi=None,path='Percussion/'+path))
def fetch(row):
    url=BASE+urllib.parse.quote(row['path']);dest=OUT/(row['name']+'.wav')
    if not dest.exists():dest.write_bytes(urllib.request.urlopen(url,timeout=45).read())
    return dict(row,url=url,sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),bytes=dest.stat().st_size)
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(fetch,SOURCES))
    (OUT.parent/'samples.json').write_text(json.dumps(rows,indent=2)+'\n')
    (OUT.parent/'VSCO-LICENSE.txt').write_bytes(urllib.request.urlopen(BASE+'LICENSE').read())
    print('Fetched',len(rows),'CC0 recordings:',sum(r['bytes'] for r in rows),'bytes')
if __name__=='__main__':main()
