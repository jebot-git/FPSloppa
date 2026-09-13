"""HTML contact gallery linking unchanged engine screenshots with map hashes."""
from pathlib import Path
import html,json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/threewave'
cards=[]
for p in sorted((ROOT/'maps/CTFStudies').glob('ctf_*/manifest.json')):
    m=json.loads(p.read_text());key=m['id']
    r=json.loads((OUT/key/'views.json').read_text())
    assert r['sha256']==hashlib.sha256((ROOT/'maps'/(key+'.bsp')).read_bytes()).hexdigest()
    images=sorted((OUT/key).glob('views-*.png'));assert len(images)>=4
    cards.append('<article><h2>'+html.escape(m['title'])+'</h2><p>'+html.escape(key)+' · '+str(m['brushes'])+' authored structural/detail brushes · original reference '+html.escape(m['original_reference'])+'</p><div>'+''.join('<a href="'+key+'/'+s.name+'"><img src="'+key+'/'+s.name+'" loading="lazy" alt="'+html.escape(s.stem)+'"></a>' for s in images)+'</div></article>')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>FPSloppa CTF Studies</title><style>body{max-width:1500px;margin:32px auto;padding:0 20px;background:#181b1d;color:#e5e1d8;font:16px system-ui}h1,h2{font-weight:600}article{margin:32px 0}div{display:grid;grid-template-columns:repeat(2,1fr);gap:12px}img{width:100%;display:block}a{color:#c7b794}p{color:#aaa}@media(max-width:750px){div{grid-template-columns:1fr}}</style><h1>Original-series CTF studies</h1><p>Unedited FPSloppa engine screenshots. Natural masonry, rock and timber; Makkon and LibreQuake material artwork. These are authored adaptations, not original BSP conversions.</p>'''+''.join(cards)+'</html>'
(OUT/'index.html').write_text(page);print(OUT/'index.html')
