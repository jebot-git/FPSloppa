"""Verify, document and package the 40-map collection (no private/original maps)."""
from pathlib import Path
import hashlib
import html
import json
import re
import shutil
import struct
import tempfile
import zipfile
from generate_arena_pack import MODES, wad_entries

ROOT=Path(__file__).resolve().parents[1]
PACK=ROOT/'optional-arena-pack'
BUILDS=ROOT.parent/'Builds'
PREFIX='FPSloppa-Arena-Collection-1'
NOTICES=('LibreQuake-COPYING.txt','LibreQuake-CREDITS.txt','LibreQuake-README-IMPORTANT-LICENCE-INFO.txt','Freedoom-COPYING.txt','Freedoom-CREDITS.txt')
TACTICS={
 'dm':'Rotate between the separated armor and megahealth rooms. Use the alternate circuit to approach a weapon holder from another height.',
 'tdm':'Coordinate a weapon-room push while another player takes the side circuit. The mirrored supply locations offer both sides the same starting opportunities.',
 'ctf':'Choose a different return route after taking the flag. Upper and lower approaches reconnect before the flag room; avoid funneling the whole team through one entry.',
 'koth':'The center room has four approaches. Contest from two sides and watch the adjoining high route; supplies are dispersed outside the hold area.',
 'ig':'Use the intermediate cover and ramp elevation to break rail sightlines. Spawn recesses are offset from corridor centerlines; exposing a corner still carries risk.',
 'ft':'Approach frozen teammates behind cover, with another player watching a second exit. Wide links leave room to move around bodies instead of creating a single-file choke.',
 'cc':'Keep moving through the short circuits and intercept at a second exit. No mandatory jumps or damaging liquids interrupt chainsaw pursuit; mode rules suppress pickups.',
 'tf':'Attack through a different entrance from the main push. Defenders have room for a sentry away from the flag and spawns, while two resupply areas reduce a single-station bottleneck.',
}

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def verify(rows):
    report=json.loads((ROOT/'test-results/arena-pack-validation.json').read_text())
    assert not report['failures'] and len(report['maps'])==40,'Run full map validation first'
    checked={r['id']:r for r in report['maps']}
    assert all(checked[r['id']].get('sha256')==r['sha256'] for r in rows),'Validation is stale; run it on the current BSPs'
    assert all(sum(r['mode']==m for r in rows)>=5 for m in MODES)
    donors=wad_entries(PACK/'source/arena-librequake.wad')
    results=[];shapes=set()
    for row in rows:
        name=row['id'];raw=(PACK/(name+'.bsp')).read_bytes()
        assert digest(PACK/(name+'.bsp'))==row['sha256'],name+' changed since manifest'
        source=(PACK/'source'/(name+'.map')).read_text()
        # Ignore textures/entities when checking structural uniqueness.
        planes='\n'.join(' '.join(re.findall(r'\([^)]*\)',line)) for line in source.splitlines() if line.lstrip().startswith('('))
        shape=hashlib.sha256(planes.encode()).hexdigest();assert shape not in shapes,'Duplicate geometry: '+name;shapes.add(shape)
        offset,size=struct.unpack_from('<ii',raw,20);count=struct.unpack_from('<i',raw,offset)[0];names=[]
        for i in range(count):
            rel=struct.unpack_from('<i',raw,offset+4+i*4)[0];assert rel>=0
            at=offset+rel;texture=raw[at:at+16].split(b'\0')[0].decode();donor=donors[texture]
            width,height=struct.unpack_from('<II',raw,at+16);assert (width,height)==struct.unpack_from('<II',donor,16)
            for mip in range(4):
                dest=struct.unpack_from('<I',raw,at+24+mip*4)[0];src=struct.unpack_from('<I',donor,24+mip*4)[0];length=max(1,width>>mip)*max(1,height>>mip)
                assert rel+dest+length<=size and raw[at+dest:at+dest+length]==donor[src:src+length],texture
            names.append(texture)
        assert (PACK/'navigation'/(name+'.res')).is_file()
        results.append({'id':name,'sha256':row['sha256'],'geometry_only_sha256':shape,'textures':names,'all_four_mips_match_librequake':True})
    (PACK/'texture-validation.json').write_text(json.dumps(results,indent=2)+'\n')
    shutil.copy2(ROOT/'test-results/arena-pack-validation.json',PACK/'validation.json')
    bots=json.loads((ROOT/'test-results/arena-pack-bots.json').read_text())
    assert not bots['failures'] and len(bots['maps'])==40,'Run the live bot checks first'
    shutil.copy2(ROOT/'test-results/arena-pack-bots.json',PACK/'bot-validation.json')
    return {r['id']:r for r in report['maps']}

def diagram(row):
    rooms={tuple(r['grid']):r['position'] for r in row['rooms']};h=row['half_room'];margin=100
    xs=[v[0] for v in rooms.values()];ys=[v[1] for v in rooms.values()]
    x0=min(xs)-h-margin;y0=min(ys)-h-margin;w=max(xs)-min(xs)+2*(h+margin);height=max(ys)-min(ys)+2*(h+margin)
    parts=[f'<svg role="img" aria-label="Schematic floorplan for {html.escape(row["title"])}" viewBox="{x0} {y0} {w} {height}">']
    for a,b in row['links']:
        A=rooms[tuple(a)];B=rooms[tuple(b)];parts.append(f'<line x1="{A[0]}" y1="{A[1]}" x2="{B[0]}" y2="{B[1]}" stroke="#697889" stroke-width="{row["corridor_width"]}"/>')
    for x,y,z in rooms.values():
        color=['#34404d','#506074','#718398'][min(2,int(z)//32)]
        parts.append(f'<rect x="{x-h}" y="{y-h}" width="{h*2}" height="{h*2}" fill="{color}" stroke="#a1b4c5" stroke-width="8"/><text x="{x}" y="{y+24}" text-anchor="middle" font-size="65" fill="#dce7ef">{z/32:g}m</text>')
    for spawn in row['spawn_points']:
        x,y,_=spawn['position'];parts.append(f'<rect x="{x-15}" y="{y-15}" width="30" height="30" fill="#f2f4f6"/>')
    for p in row['pickups']:
        x,y,_=p['position'];color='#98d56b' if 'health' in p['kind'] else '#84c8fa' if 'armor' in p['kind'] else '#c7a5ef'
        parts.append(f'<circle cx="{x}" cy="{y}" r="22" fill="{color}"/>')
    for g in row['goals']:
        x,y,_=g['position'];color='#f7ca5b' if g['kind']=='hill' else '#ff776f' if g.get('team')==0 else '#65baff'
        label={'hill':'H','flag':'F','capture':'C','resupply':'R'}[g['kind']]
        parts.append(f'<circle cx="{x}" cy="{y}" r="52" fill="{color}"/><text x="{x}" y="{y+22}" text-anchor="middle" font-size="65" fill="#101820">{label}</text>')
    parts.append('</svg>');return ''.join(parts)

def documents(rows,validation):
    (PACK/'readmes').mkdir(exist_ok=True);(PACK/'atlas').mkdir(exist_ok=True)
    cards=[]
    for row in rows:
        v=validation[row['id']];ratio=f' Team approach ratio: {v["team_route_ratio"]:.3f}.' if 'team_route_ratio' in v else ''
        text=f'# {row["title"]}\n\nID: `{row["id"]}` · Mode: **{row["mode"].upper()}** · Theme: {row["theme"]}\n\nSuggested players: {row["recommended_players"][0]}–{row["recommended_players"][1]}. {len(row["rooms"])} rooms, {len(row["links"])} connections. {TACTICS[row["mode"]]}\n\nValidated: {v["triangles"]} render triangles, {v["spawn_checks"]} spawn checks, {v["portal_samples"]} ramp/capsule samples and {v["route_checks"]} bot-route queries.{ratio} This does not certify competitive balance or headset performance.\n\nCC0 original geometry; BSD LibreQuake textures. Retain the collection notices and texture provenance. See collection README.md and REFERENCES.md for installation, compiler and design references.\n'
        (PACK/'readmes'/(row['id']+'.md')).write_text(text)
        screenshot=PACK/'screenshots'/(row['id']+'.png');assert screenshot.is_file(),'Render all previews first'
        cards.append(f'<article data-mode="{row["mode"]}"><h2>{html.escape(row["title"])}</h2><p class="tag">{row["mode"].upper()} · {html.escape(row["id"])} · {row["recommended_players"][0]}–{row["recommended_players"][1]} players</p><a href="screenshots/{row["id"]}.png"><img loading="lazy" alt="In-game view of {html.escape(row["title"])}" src="screenshots/{row["id"]}.png"></a><details><summary>Floorplan and routes</summary>{diagram(row)}<p>Floor heights in metres. White: spawn; purple: supplies/weapons; green: health; blue: armor. F: flag, C: capture, R: resupply, H: hill. Cover is omitted from this schematic.</p></details><p>{TACTICS[row["mode"]]}</p><p class="small">{v["triangles"]:,} triangles · {v["route_checks"]:,} route checks</p></article>')
    page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>FPSloppa · Arena Collection 1</title><style>
body{margin:0;background:#10151b;color:#dce4ed;font:17px/1.5 system-ui,sans-serif}header,main,footer{max-width:1400px;margin:auto;padding:28px}h1{font-size:clamp(32px,5vw,60px);margin:.2em 0}h2{margin:0;font-size:25px}.intro{max-width:850px;color:#b8c9d5}.filters{display:flex;gap:8px;flex-wrap:wrap;margin:24px 0}button{font:inherit;border:1px solid #526477;color:#dce4ed;background:#1b2632;padding:12px 18px;border-radius:5px;cursor:pointer}button[aria-pressed=true]{background:#f2c066;color:#11171e;border-color:#f2c066}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,380px),1fr));gap:22px;padding-top:0}article{background:#1b232e;padding:20px;border:1px solid #354151;border-radius:8px}img{display:block;width:100%;aspect-ratio:1.6;object-fit:cover;border-radius:4px}.tag,.small{color:#a6bed0;font-size:14px}details{margin-top:14px}summary{cursor:pointer;color:#f2c066}svg{width:100%;background:#0d1218;margin-top:16px}details p{font-size:13px;color:#afc1ce}a{color:#f2c066}[hidden]{display:none}footer{color:#a6bed0}
</style><header><p class="tag">FPSloppa · ORIGINAL BSP MAP PACK</p><h1>Arena Collection 1</h1><p class="intro">40 new maps. Eight modes. Foundries, abbeys, reactors, relay stations and stone citadels, with original layouts and LibreQuake textures. Pick a mode to browse screenshots and route diagrams.</p><p class="intro">Automated geometry, spawn, objective and bot-route checks passed. Balance and headset performance need playtesting. Maps install into the external maps folder; they are not embedded in the game package.</p><nav class="filters" aria-label="Filter maps">'''
    page+='<button data-filter="all" aria-pressed="true">ALL · 40</button>'+''.join(f'<button data-filter="{m}" aria-pressed="false">{m.upper()} · 5</button>' for m in MODES)
    page+='</nav><p id="count" aria-live="polite">Showing 40 maps</p></header><main>'+''.join(cards)+'</main><footer>New geometry and documentation: CC0. LibreQuake textures: BSD-3-Clause. Original notices, source hashes and validation reports are supplied in the pack.</footer><script>document.querySelectorAll("button[data-filter]").forEach(button=>button.addEventListener("click",()=>{let count=0;document.querySelectorAll("article").forEach(card=>{card.hidden=button.dataset.filter!=="all"&&card.dataset.mode!==button.dataset.filter;if(!card.hidden)count++});document.querySelectorAll("button[data-filter]").forEach(b=>b.setAttribute("aria-pressed",String(b===button)));document.querySelector("#count").textContent=`Showing ${count} maps`;}));</script></html>'
    (PACK/'atlas/index.html').write_text(page)
    # Atlas paths are valid both in the working tree and when packaged.
    for screenshot in (PACK/'screenshots').glob('*.png'):
        dest=PACK/'atlas/screenshots'/screenshot.name;dest.parent.mkdir(exist_ok=True);shutil.copy2(screenshot,dest)

def runtime_zip(rows,label):
    files={};rotations={}
    for row in rows:
        name=row['id'];rotations.setdefault(row['mode'],[]).append(name)
        for ext in ('.bsp','.lit'):files['maps/'+name+ext]=PACK/(name+ext)
        files['maps/navigation/'+name+'.res']=PACK/'navigation'/(name+'.res')
        files['maps/arena-collection-1/readmes/'+name+'.md']=PACK/'readmes'/(name+'.md')
    for name in (*NOTICES,'texture-sources.json','texture-validation.json','validation.json','bot-validation.json','lighting-validation.json','README.md','REFERENCES.md'):
        files['maps/arena-collection-1/'+name]=PACK/name
    manifest={'collection':1,'files':[{'path':name,'sha256':digest(path),'size':path.stat().st_size} for name,path in sorted(files.items())],'rotations':rotations}
    path=BUILDS/(PREFIX+'-'+label+'.zip')
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for name,source in sorted(files.items()):z.write(source,name)
        z.writestr('install-manifest.json',json.dumps(manifest,indent=2)+'\n')
        z.write(ROOT/'tools/install_arena_pack.py','install_arena_pack.py');z.write(PACK/'README.md','README.md');z.write(ROOT/'MAP_LIGHTING.md','MAP_LIGHTING.md')
        for mode,names in rotations.items():z.writestr('rotations/'+mode+'_maplist.txt','\n'.join(names)+'\n')
        if label=='All-Modes':
            z.write(PACK/'atlas/index.html','atlas/index.html')
            for row in rows:z.write(PACK/'screenshots'/(row['id']+'.png'),'atlas/screenshots/'+row['id']+'.png')
    print(path,flush=True);return path

def main():
    rows=json.loads((PACK/'manifest.json').read_text());validation=verify(rows);documents(rows,validation);BUILDS.mkdir(exist_ok=True)
    archives=[runtime_zip(rows,'All-Modes')]
    for mode in MODES:archives.append(runtime_zip([r for r in rows if r['mode']==mode],mode.upper()))
    source=BUILDS/(PREFIX+'-Sources.zip')
    with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED) as z:
        for p in sorted((PACK/'source').iterdir()):
            if p.suffix in ('.map','.wad'):z.write(p,'optional-arena-pack/source/'+p.name)
        for name in (*NOTICES,'README.md','REFERENCES.md','manifest.json','texture-sources.json','texture-validation.json','validation.json','bot-validation.json','lighting-validation.json'):z.write(PACK/name,'optional-arena-pack/'+name)
        for name in ('generate_arena_pack.py','generate_tf_maps.py','install_arena_pack.py','package_arena_pack.py','validate_map_lighting.py'):z.write(ROOT/'tools'/name,'tools/'+name)
        for name in ('arena_pack.gd','arena_pack_preview.gd','arena_pack_bots.gd','baked_light.gd'):z.write(ROOT/'deathmatch/tests'/name,'deathmatch/tests/'+name)
        z.write(ROOT/'MAP_LIGHTING.md','MAP_LIGHTING.md')
    archives.append(source)
    (BUILDS/(PREFIX+'-SHA256SUMS.txt')).write_text(''.join(digest(p)+'  '+p.name+'\n' for p in archives))
    # Make the ready-to-install payload available for local source/preview installs.
    staging=BUILDS/(PREFIX+'-Install');staging.mkdir(exist_ok=True)
    with zipfile.ZipFile(archives[0]) as z:z.extractall(staging)
    print('INSTALL_SOURCE',staging)

if __name__=='__main__':main()
