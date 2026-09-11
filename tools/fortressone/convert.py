"""Local-only FortressOne BSP29 adaptation; run with --help. CC0 tool."""
import argparse, hashlib, json, re, struct
from pathlib import Path
from texture_replace import convert, wad_textures
LIMIT=25_000_000
# Reviewed sources with no explicit modification prohibition. No redistribution grant assumed.
CANDIDATES={'bam4','openfire','2mach1','2castle1','turtler'}
def entities(raw):
    return [dict(re.findall(r'"([^"\n]*)"\s*"([^"\n]*)"', e)) for e in raw.decode('latin1').split('}') if '"classname"' in e]
def adapt(source, output):
    name=source.stem
    if name not in CANDIDATES:raise ValueError('Source has not passed the local-conversion rights review')
    raw=source.read_bytes()
    provenance=json.loads(Path(__file__).with_name('sources.json').read_text())
    expected=next(e['sha256'] for e in provenance['files'] if e['map']==name and e['upstream_path'].endswith('/maps/'+name+'.bsp'))
    if hashlib.sha256(raw).hexdigest()!=expected:raise ValueError('Source differs from reviewed FortressOne revision')
    if len(raw)>LIMIT:raise ValueError('BSP exceeds 25 MB')
    donors=wad_textures(Path(__file__).with_name('librequake.wad'))
    prepared=bytearray(raw);at,n=struct.unpack_from('<ii',raw,20);count=struct.unpack_from('<i',raw,at)[0]
    table=bytearray(struct.pack('<i',count)+bytes(count*4));missing=[]
    for i in range(count):
        rel=struct.unpack_from('<i',raw,at+4+i*4)[0]
        struct.pack_into('<i',table,4+i*4,len(table))
        if rel==-1:
            tile=donors['met_brn_block'];missing.append(i)
        else:
            w,h=struct.unpack_from('<II',raw,at+rel+16);last=struct.unpack_from('<I',raw,at+rel+36)[0]
            tile=raw[at+rel:at+rel+last+max(1,w>>3)*max(1,h>>3)]
        table.extend(tile)
    struct.pack_into('<ii',prepared,20,len(prepared),len(table));prepared.extend(table)
    converted,textures=convert(prepared,donors)
    # Verify conversion is idempotent: every source pixel must have been replaced.
    verified,_=convert(converted,wad_textures(Path(__file__).with_name('librequake.wad')))
    assert verified==converted
    offset,size=struct.unpack_from('<ii',raw,4)
    es=entities(raw[offset:offset+size]);changes=[]
    for e in es:e['classname']={'i_p_t':'info_player_teamspawn','i_t_g':'info_tfgoal'}.get(e['classname'],e['classname'])
    if name=='turtler':
        sidecar=source.with_suffix('.ent').read_bytes()
        expected=next(e['sha256'] for e in provenance['files'] if e['map']==name and e['upstream_path'].endswith('/maps/turtler.ent'))
        assert hashlib.sha256(sidecar).hexdigest()==expected,'Unreviewed entity sidecar'
        fixes={e['goal_no']:e['owned_by'] for e in entities(sidecar) if e['classname']=='item_tfgoal'}
        for e in es:
            if e['classname']=='item_tfgoal' and e['owned_by']!=fixes[e['goal_no']]:
                changes.append({'adaptation':'FortressOne sidecar flag ownership correction','goal_no':e['goal_no'],'before':e['owned_by'],'after':fixes[e['goal_no']]})
                e['owned_by']=fixes[e['goal_no']]
        es[0]['_fpsloppa_bake']='1';es[0]['_fpsloppa_atlas']='4096'
    flags={}
    for e in es:
        if e['classname']=='item_tfgoal' and ('flag' in e.get('mdl','').lower() or e.get('mdl','').lower()=='progs/tf_stan.mdl'):
            owner=int(e.get('owned_by',0)) or 3-int(e.get('team_no',0))
            assert owner in (1,2)
            flags[int(e['goal_no'])]=owner
            changes.append({'original':dict(e),'adaptation':'native flag','team':owner})
            e['classname']='item_flag_team1' if owner==2 else 'item_flag_team2'
    assert set(flags.values())=={1,2},'Two unambiguous flags required'
    caps=set();spawns={1:[],2:[]};result=[]
    for e in es:
        kind=e['classname']
        if kind=='info_player_deathmatch':continue
        if kind=='info_player_teamspawn':
            team=int(e.get('team_no',0))
            if team not in spawns:continue
            if e['origin'] in spawns[team]:continue
            spawns[team].append(e['origin'])
        if kind=='info_tfgoal' and int(e.get('items_allowed',0)) in flags:
            team=int(e.get('team_no',0)) or 3-flags[int(e['items_allowed'])]
            assert team in (1,2)
            changes.append({'original':dict(e),'adaptation':'native capture','team':team})
            e['classname']='info_tf_capture_red' if team==2 else 'info_tf_capture_blue';caps.add(team)
        result.append(e)
    assert caps=={1,2} and all(spawns.values())
    # Team respawn rooms become native resupply positions. No external sounds/models copied.
    for team,points in spawns.items():
        result.append({'classname':'info_tf_resupply_red' if team==2 else 'info_tf_resupply_blue','origin':points[0]})
    payload=('\n'.join('{\n'+'\n'.join('"'+k+'" "'+v+'"' for k,v in e.items())+'\n}' for e in result)+'\n\0').encode('latin1')
    # Rebuild all lumps, dropping unreferenced bytes rather than retaining old entities/assets.
    lumps=[struct.unpack_from('<ii',converted,4+i*8) for i in range(15)]
    rebuilt=bytearray(124);struct.pack_into('<i',rebuilt,0,29)
    for i,(at,n) in enumerate(lumps):
        data=payload if i==0 else converted[at:at+n]
        while len(rebuilt)%4:rebuilt.append(0)
        struct.pack_into('<ii',rebuilt,4+i*8,len(rebuilt),len(data));rebuilt.extend(data)
    assert len(rebuilt)<=LIMIT
    output.mkdir(parents=True,exist_ok=True);dest=output/('tf_fo_'+name+'.bsp')
    if dest.exists() and dest.read_bytes()!=rebuilt:raise ValueError('Refusing to overwrite differing conversion: '+str(dest))
    dest.write_bytes(rebuilt)
    report={'name':name,'path':str(dest.resolve()),'source_sha256':hashlib.sha256(raw).hexdigest(),'sha256':hashlib.sha256(rebuilt).hexdigest(),'size':len(rebuilt),'redistribution':'NOT CLEARED: local testing/server only; do not upload','entity_source':'embedded BSP entities; Turtler flag ownership corrected from pinned FortressOne sidecar' if name=='turtler' else 'embedded BSP entities (FortressOne sidecar not executed)','changes':changes,'team_spawns':spawns,'textures':textures,'all_mips_replaced':True,'missing_texture_slots_replaced':missing,'geometry_collision_lightmaps_preserved':True}
    dest.with_suffix('.conversion.json').write_text(json.dumps(report,indent=2)+'\n');print(dest)
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('bsp',type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args();adapt(a.bsp,a.output)
