"""Explicit map selection shared by TF and base-asset distribution builders."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
TF_MAPS={'tf_pressureworks':'Pressureworks','tf_vesper':'VesperAbbey'}
AS_MAPS=('as_hislop','as_frigate')
DOC_SUFFIXES={'.md','.txt','.json','.png','.mp4','.map','.wad'}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def distributable(path):
    p=Path(path)
    if p.parts[:2]==('maps','Community'):return False
    if p.name.startswith(('as_hislop_tiny','as_frigate_tiny','tf_ironspan','tf_relayworks')):return False
    if p.parts[:2]==('maps','HiSlop') or p.parts[:2]==('maps','Frigate'):
        if 'Tiny' in p.parts:return False
    if p.name.startswith('lqdm') and p.suffix in {'.bsp','.lit','.scn','.res'}:return False
    if p.name.startswith('dm_') and p.suffix in {'.bsp','.lit','.scn','.res'}:return False
    return True

def tf_files():
    """Preserve the tested BSP/source/navigation and original artwork receipts."""
    files=[Path('maps/tf_maplist.txt')]
    assert (ROOT/files[0]).read_text().split()==list(TF_MAPS),'Unexpected TF rotation'
    for id,folder in TF_MAPS.items():
        base=ROOT/'maps'/folder
        manifest=json.loads((base/'manifest.json').read_text())
        acceptance=json.loads((base/'validation.json').read_text())
        audit=json.loads((base/'texture-audit.json').read_text())
        bsp=Path('maps')/(id+'.bsp');nav=Path('maps/navigation')/(id+'.res')
        current=sha(ROOT/bsp)
        assert current==manifest['sha256'],id+': BSP manifest mismatch'
        if current!=acceptance['sha256']:
            # A lighting-only rebake can retain collision/navigation and art
            # acceptance without pretending the old playtest ran on new bytes.
            proof=json.loads((ROOT/'docs/validation/lighting-ao-distribution.json').read_text())
            row=next(r for r in proof['maps'] if r['id']==id)
            assert row['original_sha256']==acceptance['sha256']==audit['bsp_sha256'],id+': AO lineage mismatch'
            if row['sha256']!=current:
                refinement=json.loads((ROOT/'docs/validation/static-rendering.json').read_text())
                updated=next(r for r in refinement['bakes']['maps'] if r['id']==id)
                assert updated['original_sha256']==row['sha256'],id+': static refinement lineage mismatch'
                if updated['sha256']!=current:
                    assets=json.loads((ROOT/'docs/validation/static-assets.json').read_text())
                    fine=next(item for item in assets['density'] if item['map']==id)
                    assert fine['source_sha256']==updated['sha256'] and fine['candidate_sha256']==current,id+': selective density lineage mismatch'
                    assert fine['geometry_unchanged'] and fine['unselected_light_samples_unchanged'] and fine['original_styles_preserved'],id+': density preservation mismatch'
                    assert assets['verify']['failures']==[] and assets['render']['failures']==[],id+': static assets checks failed'
                    files.append(Path('docs/validation/static-assets.json'))
                assert updated['geometry_vis_collision_textures_entities_unchanged'],id+': refinement changed geometry'
                assert refinement['import_failures']==[] and refinement['render_failures']==[],id+': refinement checks failed'
                files.append(Path('docs/validation/static-rendering.json'))
            assert row['geometry_vis_collision_textures_entities_unchanged'] and row['navigation_sha256']==sha(ROOT/nav),id+': AO preservation mismatch'
            assert proof['validation']['import_failures']==[] and proof['validation']['render_failures']==[],id+': AO checks failed'
            files.append(Path('docs/validation/lighting-ao-distribution.json'))
        else:
            assert current==audit['bsp_sha256'],id+': art receipt mismatch'
        assert not acceptance['failures'] and all(row['unchanged'] for row in audit['textures']),id+': failed acceptance/art audit'
        assert sha(ROOT/nav)==acceptance['navigation_sha256'],id+': navigation changed'
        assert sha(base/(id+'.map'))==manifest['source_sha256'],id+': source changed'
        files.extend([bsp,nav])
        files.extend(p.relative_to(ROOT) for p in base.iterdir() if p.suffix in DOC_SUFFIXES)
    return sorted(set(files))

def rotation(mode):
    return [word for line in (ROOT/"maps"/(mode+"_maplist.txt")).read_text().splitlines() for word in line.split("#",1)[0].split()]

def check_selection(paths):
    names={str(p) for p in paths}
    assert all(distributable(p) for p in names),'Retired TF or Tiny AS asset selected'
    assert {Path(p).stem for p in names if p.startswith('maps/tf_') and p.endswith('.bsp')}==set(TF_MAPS)
    assert {Path(p).stem for p in names if p.startswith('maps/as_') and p.endswith('.bsp')}==set(AS_MAPS)
    assert rotation('as')==list(AS_MAPS)

    quake={'qsrc_dm'+str(i) for i in range(1,8)}
    cc={'cc_hyperborea','cc_psychofuge','cc_ghostquarter','cc_basement'}
    assert {Path(p).stem for p in names if p.startswith('maps/qsrc_dm') and p.endswith('.bsp')}==quake
    assert {Path(p).stem for p in names if p.startswith('maps/cc_') and p.endswith('.bsp')}==cc
    for mode in ['dm','tdm','ig','ft','if']:assert rotation(mode)==['qsrc_dm'+str(i) for i in range(1,8)]
    assert set(rotation('cc'))==cc
    ctf={'ctf_tideworks','ctf_crucible','ctf_confluence','ctf_deepvault','ctf_crownreach','ctf_skyfracture'}
    assert {Path(p).stem for p in names if p.startswith('maps/ctf_') and p.endswith('.bsp')}==ctf
    assert set(rotation('ctf'))==ctf
