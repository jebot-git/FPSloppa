"""Publish local DE bot/site review artifacts and machine-readable receipts."""
from pathlib import Path
import hashlib, json
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
AI=ROOT/'test-results/de-bot-review'
SITES=ROOT/'test-results/de-site-markings'
def read(path):return json.loads(path.read_text())
def save(path,data):path.write_text(json.dumps(data,indent=2)+'\n')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
STYLE='''<style>:root{color-scheme:dark;font:16px system-ui;background:#131a20;color:#e7edee}body{max-width:1400px;margin:32px auto;padding:0 20px}p{line-height:1.6;max-width:1000px}a{color:#8bd9cd}.grid{display:grid;grid-template-columns:1fr 1fr;gap:18px}figure{margin:0 0 22px;background:#202b34}img,video{width:100%;display:block}figcaption{padding:12px}td,th{padding:10px 20px;text-align:left;border-bottom:1px solid #52616a}h2{margin-top:36px}@media(max-width:700px){.grid{grid-template-columns:1fr}}</style>'''
def page(title,body):return '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'+title+'</title>'+STYLE+'<body><h1>'+title+'</h1>'+body+'</body></html>'
def main():
    audits=read(SITES/'surface-audit.json');body='<p>All ten sites: red ground crosses, red wall letters, solid wall backing, correct letter orientation and unobstructed wall views. Native game captures; no floating plant guides.</p>'
    for name in ['dust2','nuke','inferno','aztec','train']:
        map_id='de_'+name+'_rebuilt';body+='<h2>'+name.title()+'</h2><div class="grid">'
        sheet=Image.new('RGB',(1280,848),(25,28,32));draw=ImageDraw.Draw(sheet)
        for index,(site,kind) in enumerate([('a','cross'),('a','letter'),('b','cross'),('b','letter')]):
            filename=f'{map_id}-{site}-{kind}.png';image=Image.open(SITES/filename);image.thumbnail((640,400))
            x=index%2*640;y=index//2*424;sheet.paste(image,(x,y));caption=f'{name.title()} · {site.upper()} · {kind}'
            draw.text((x+8,y+405),caption,fill='white')
            body+=f'<figure><a href="{filename}"><img loading="lazy" src="{filename}" alt="{caption}"></a><figcaption>{caption}</figcaption></figure>'
        body+='</div>';sheet.save(SITES/(name+'-review.jpg'))
    body+='<p><a href="../../docs/validation/de-site-markings-2026-09-26.json">Validation receipt</a></p>'
    (SITES/'index.html').write_text(page('DE site markings',body))
    comparison=read(AI/'comparison.json')
    body='<p>Reviewed original match videos, telemetry and recorded states. Fixed competing site-goal reservations, off-mesh defense positions, skipped perception during bomb interactions, and guns left holstered after bomb recovery.</p><p>Six rounds on each of five maps, 6v6, side swap after three. These complete comparison runs use ordinary 60 Hz physics with real-time pacing disabled. Spawn exit means moving eight metres from the initial live-round position.</p><table><tr><th>Map</th><th>Longest exit before</th><th>After</th></tr>'
    for row in comparison:body+=f'<tr><td>{row["map"]}</td><td>{row["before"]["max_spawn_exit_seconds"]:.2f} s</td><td>{row["after"]["max_spawn_exit_seconds"]:.2f} s</td></tr>'
    body+='</table><h2>Real-time verification clips</h2><p>Two 60-second ENet 6v6 clips with a live spectator. These short clips show the AI fixes before the final paint-color adjustment; they are not complete six-round matches.</p><div class="grid">'
    for name in ['train','nuke']:
        url=f'../../recordings/de-bot-fixes-2026-09-26/de_{name}_rebuilt/match.mp4'
        body+=f'<figure><video controls preload="metadata" src="{url}"></video><figcaption>{name.title()} · 60 seconds · actual live client</figcaption></figure>'
    body+='</div><p><a href="../../docs/DE-BOT-REVIEW-2026-09-26.md">Findings and fixes</a> · <a href="comparison.json">Raw comparison</a> · <a href="../de-site-markings/index.html">All ten site markings</a></p>'
    (AI/'index.html').write_text(page('DE bot behavior review',body))
    tests=[]
    for name in ['regression','defusal-bots','bomb-recovery','tactics','teamplay','cs16-bots']:
        text=(AI/(name+'.log')).read_text();assert 'SCRIPT ERROR' not in text and not any(l.startswith('FAIL ') for l in text.splitlines())
        tests.append(dict(name=name,checks=sum(l.startswith('PASS ') for l in text.splitlines()),passed=True))
    for role in ['server','carrier','rescuer','defender']:
        assert read(ROOT/f'test-results/defusal/bomb-recovery-network-{role}.json')['passed']
        text=(ROOT/f'test-results/defusal/bomb-recovery-network-{role}.log').read_text()
        tests.append(dict(name='network-'+role,checks=sum(l.startswith('PASS ') for l in text.splitlines()),passed=True))
    ai_receipt=dict(passed=True,tests=tests,checks=sum(t['checks'] for t in tests),comparison=comparison,completed_rounds=30,simulation='60 Hz physics, accelerated wall-clock pacing, seed 7129',recording_audit=read(AI/'demo-audit.json'),live_clips=read(ROOT/'recordings/de-bot-fixes-2026-09-26/series.json')['maps'])
    save(ROOT/'docs/validation/de-bot-review-2026-09-26.json',ai_receipt)
    traversals=[]
    for name in ['dust2','nuke','inferno','aztec','train']:
        text=(AI/(name+'-traversal.log')).read_text();assert 'SCRIPT ERROR' not in text and not any(l.startswith('FAIL ') for l in text.splitlines())
        traversals.append(dict(map='de_'+name+'_rebuilt',checks=sum(l.startswith('PASS ') for l in text.splitlines()),passed=True))
    text=(SITES/'maps-test.log').read_text();assert 'SCRIPT ERROR' not in text and not any(l.startswith('FAIL ') for l in text.splitlines())
    manifest=read(ROOT/'deathmatch/assets/base_manifest.json');assert sha(SITES/'Base-Assets.zip')==manifest['sha256']
    save(ROOT/'docs/validation/de-site-markings-2026-09-26.json',dict(passed=True,sites=audits,native_views=20,traversals=traversals,map_objective_checks=sum(l.startswith('PASS ') for l in text.splitlines()),materials=read(ROOT/'test-results/de-texturing/source-audit.json'),package=dict(path='test-results/de-site-markings/Base-Assets.zip',sha256=manifest['sha256'],bytes=(SITES/'Base-Assets.zip').stat().st_size)))
    print('DE_REVIEW_PUBLISHED',ai_receipt['checks'],'AI/bomb checks;',len(audits),'sites;',sum(r['checks'] for r in traversals),'traversal checks')

if __name__=='__main__':main()
