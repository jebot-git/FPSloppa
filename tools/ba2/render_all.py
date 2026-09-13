"""Resume verified video frames with three bounded, independent Blender workers."""
import os,signal,subprocess,time
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/ba2/walk'
BLENDER='/home/blux/blender-5.2.0-linux-x64/blender'
first=0
while first<357:
    try:
        with Image.open(OUT/f'frames/{first:04d}.png') as image:image.verify()
    except (OSError,ValueError):break
    first+=1
workers=[];begin=time.monotonic();last=0
try:
    for i in range(3):
        start=first+(357-first)*i//3;stop=first+(357-first)*(i+1)//3
        if start==stop:continue
        path=OUT/f'render-worker-{i}.log';log=path.open('w')
        proc=subprocess.Popen([BLENDER,'--background','--factory-startup','-noaudio','--threads','6','--disable-autoexec','--python',str(ROOT/'tools/ba2/render_walk.py'),'--','--start',str(start),'--stop',str(stop)],stdout=log,stderr=subprocess.STDOUT,cwd=ROOT)
        workers.append({'proc':proc,'path':path,'log':log,'done':False})
    while not all(w['done'] for w in workers):
        for w in workers:
            if w['done']:continue
            content=w['path'].read_text()
            if 'BA2_WALK_RENDER_COMPLETE' in content:
                # The files are closed before this marker. Blender's sandbox
                # audio shutdown can hang, so reap only this completed worker.
                p=w['proc']
                if p.poll() is None:p.send_signal(signal.SIGINT)
                try:p.wait(timeout=5)
                except subprocess.TimeoutExpired:p.kill();p.wait()
                w['done']=True
            elif 'Traceback (most recent call last)' in content or w['proc'].poll() is not None:raise RuntimeError(w['path'].read_text()[-3000:])
        elapsed=time.monotonic()-begin
        if elapsed-last>20:
            print('BA2_VIDEO_FRAMES',len(list((OUT/'frames').glob('*.png'))),'/357',flush=True);last=elapsed
        if elapsed>1200:raise TimeoutError('BA-2 video rendering exceeded 20 minutes')
        time.sleep(.25)
    for i in range(357):
        with Image.open(OUT/f'frames/{i:04d}.png') as image:image.verify()
    (OUT/'render.log').write_text('Resumed verified frames using three independent six-thread workers.\nBA2_WALK_RENDER_COMPLETE\n')
    print('BA2_VIDEO_ALL_FRAMES_COMPLETE',flush=True)
finally:
    for w in workers:
        if w['proc'].poll() is None:w['proc'].terminate();w['proc'].wait(timeout=5)
        w['log'].close()
