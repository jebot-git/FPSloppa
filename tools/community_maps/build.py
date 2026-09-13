"""Install the reviewed, freely distributable community map adaptations."""
from pathlib import Path
import argparse
import json
import re
import shutil
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools'))
from makkon.theme import makkon, wad_textures, bsp_textures, replace, lumps, repack, name, sha
from community_maps.archive import members, read_member

SELECTIONS = {
    'dm_anctomb_slop': {
        'maya1_9':'may_brk1_0', 'maya1_3':'may_brk1_3', 'maya2_2':'may_bnd1_2',
        'city4_7':'med_csl_brk14b', 'maya2_9':'may_trm1_2', 'sky_tele':'sky_star',
        'maya1_7':'may_brk_old', '*04mwat2':'*water2', 'maya3_3':'may_flr1_1',
        'maya1_4':'may_blok1_1', 'maya2_3':'may_bnd1_1', '*teleport':'*tele3',
        'maya1_5':'may_brk1_3', 'maya2_4':'may_trm1_1', 'met5_2':'metal_iron1_04',
        **{f'+{frame}_fall':'+0water_f1' for frame in range(8)},
    },
    'dm_anchall_slop': {
        'city4_7':'med_csl_brk14b', '*lava1':'*lava1', 'wmet4_4':'metal_iron1_04',
        'skypk1':'sky_star','wbrick1_5':'med_csl_brk7_2', 'wizwood1_8':'med_wood2',
        'nmetal2_1':'metal_iron1_01', 'window01_3':'med_glass5',
        'window01_1':'med_glass5', 'window1_3':'med_glass5',
        '+ashoot':'+aindb01_blk1', **{f'+{frame}shoot':'+0indb01_blk1' for frame in range(4)},
    },
    'dm_battlef_slop': {
        'wizwood1_2':'med_wood2', 'wswamp1_2':'med_rock10b', 'tech01_6':'ind_w02_blu1',
        'wgrass1_1':'med_rock10b','ground1_2':'med_rock10b','tech04_7':'ind_w04_grey1',
        'door02_3':'tek_door1','*water0':'*water2','tech04_3':'ind_w06_rst2',
        'sky4':'sky_star','*teleport':'*tele3','dung01_2':'med_csl_brk7_2',
    },
    'dm_lasercade_slop': {
        'glowwall':'tlight12', '16_gold_1':'ind_w01_ylw1', 'void':'met_blc_trim64',
        'grid':'ind_w04_blu1', 'grey':'ind_w02_grey1', 'smallgrid':'ind_dp01_grey1',
        'light1_grt':'tlight12', 'corner':'ind_w01_red1', 'light1_sml':'tlight12',
        'greengarpet':'ind_dp01_grn1', '*tele01':'*water2', 'poster01':'ind_dct2_blu1',
        'corner2':'ind_w01_blu1', 'logo':'ind_cont2_prpl1', 'sign':'ind_cont1_ylw1',
        '+0button_0':'+0indb01_blk1', '+abutton_0':'+aindb01_blk1',
        '{floorgrate':'{ind_grt1_blk1', '{netting':'{ind_fnc1_blk1',
        'cab':'ind_cont2_blk1', 'moreposter':'ind_dct2_red1',
        **{f'+{frame}scrn{suffix}':'comp1_6' for frame in range(10) for suffix in ['a','b']},
    },
    'dm_auhdm2_slop': {
        'rtex273':'metal_iron1_05', 'rtex330':'metal_iron1_13', '19':'metal_iron1_10',
        'r34':'metal_iron1_01', 'rtex254':'metal_iron1_04', 'exce13':'metal_iron1_c1',
        '16':'metal_iron1_11', '20':'metal_iron1_14', 'rtex331':'metal_iron1_12',
        'light3_7':'tlight12', 'rtex329':'metal_iron1_07', 'qlight':'tlight12',
        'skykbad':'sky_star', 'ceilingtech':'metal_iron1_c1', 'rtex081':'metal_iron1_06',
        'rtex255':'metal_iron1_08', 'quizas':'ind_dp01_grey1', 'marker2_2':'metal_iron1_09',
        'rtex276':'metal_iron1_02', 'dirt2':'med_rock10b', '*viscera_liq1':'*water2',
    },
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bake', action='store_true')
    args = parser.parse_args()
    originals, sources = makkon()
    wad_path = ROOT/'tools/fortressone/librequake.wad'
    wad = wad_path.read_bytes()
    wad_hash = sha(wad)
    for key, raw in wad_textures(wad).items():
        originals[key] = raw
        sources[key] = dict(author='LibreQuake contributors', source='https://github.com/lavenderdotpet/LibreQuake',
            wad='tools/fortressone/librequake.wad', wad_sha256=wad_hash, sha256=sha(raw), license='BSD-3-Clause')
    for donor in ['maps/lqdm1', 'maps/lqdm2', 'maps/lqdm3', 'maps/as_hislop_tiny', 'optional-map-pack/lqdm10']:
        backup = ROOT/'tools/makkon/local/maintained-originals'/(Path(donor).name+'.bsp')
        data = (backup if backup.is_file() else ROOT/(donor+'.bsp')).read_bytes()
        bsp_hash = sha(data)
        for raw in bsp_textures(data):
            if raw is None:continue
            key = name(raw)
            if key in originals and 'Makkon' in sources[key].get('author',''):continue
            originals[key] = raw
            sources[key] = dict(author='LibreQuake contributors', source='https://github.com/lavenderdotpet/LibreQuake',
                bsp=donor+'.bsp', bsp_sha256=bsp_hash, sha256=sha(raw), license='BSD-3-Clause')
    # Invisible compiler textures keep their semantic names; only LibreQuake
    # pixels are renamed here. Makkon records are always copied byte-for-byte.
    for key in ['clip','trigger','skip']:
        originals[key] = struct.pack('16s', key.encode())+originals['met_blc_trim64'][16:]
        sources[key] = dict(sources['met_blc_trim64'], sha256=sha(originals[key]), donor='met_blc_trim64', edit='tool texture header name only')
    approved = json.loads((Path(__file__).with_name('approved.json')).read_text())
    catalog_path = ROOT/'deathmatch/maps/manifest.json'
    catalog = json.loads(catalog_path.read_text())
    results = []
    for row in approved:
        if 'slipseer.com' in row['source']:
            assert row['rating'] >= 3
        archive = Path(__file__).with_name('local')/row['archive']
        assert sha(archive.read_bytes()) == row['sha256']
        folder = ROOT/'maps/Community'/row['id']
        folder.mkdir(parents=True, exist_ok=True)
        listing=members(archive)
        bsp = row.get('bsp_member') or next(n for n in listing if n.lower().endswith('.bsp'))
        data = read_member(archive,bsp)
        readme = row.get('readme_member') or next(n for n in listing if n.lower().endswith('.txt'))
        (folder/'ORIGINAL-README.txt').write_bytes(read_member(archive,readme))
        lit = next((n for n in listing if n.lower().endswith('.lit')), None)
        lighting = read_member(archive,lit) if lit else None
        mapping = dict(SELECTIONS[row['id']], clip='clip', trigger='trigger', skip='skip')
        old_names = [name(raw) for raw in bsp_textures(data) if raw]
        assert set(old_names) <= mapping.keys(), 'Unreviewed original textures remain'
        replacements = {old: originals[mapping[old]] for old in old_names}
        updated = replace(data, replacements)
        assert all(raw in originals.values() for raw in bsp_textures(updated) if raw)
        parts, extra = lumps(updated)
        parts[0] = re.sub(rb'("message"\s*")[^"]*"', lambda m: m[1]+(row['title']+' (FPSloppa edition)').encode()+b'"', parts[0], count=1)
        parts[0] = parts[0].replace(b'{',b'{\n"_fpsloppa_bake" "1"\n"_fpsloppa_atlas" "2048"',1)
        if lighting:
            assert lighting[:8] == b'QLIT\x01\0\0\0' and len(lighting) == 8+len(parts[8])*3
            extra = [(key,value) for key,value in extra if key.rstrip(b'\0') != b'RGBLIGHTING']
            extra.append((b'RGBLIGHTING',lighting[8:]))
        updated = repack(parts, extra)
        path = ROOT/'maps'/(row['id']+'.bsp')
        path.write_bytes(updated)
        provenance = {new:sources[new] for old in old_names for new in [mapping[old]]}
        (folder/'texture-sources.json').write_text(json.dumps(provenance, indent=2)+'\n')
        notice = dict(row, installed_sha256=sha(updated), bytes=len(updated), original_bsp_sha256=sha(data),
            changes='All embedded images replaced with licensed original Makkon/LibreQuake textures. Title identifies adaptation; baked lighting enabled, original .lit embedded as BSPX RGBLIGHTING where supplied. Geometry, collision, VIS, lightmap data, gameplay entities and item placement unchanged. Quake-specific player skin, music and bot data omitted.',
            limitations='Full Quake button/relay/counter logic is not emulated. Direct touch triggers can activate doors; other doors use proximity and platforms use timed cycles. Animated arcade, waterfall and shootable-button frames become static counterparts. Multiplayer balance needs playtesting.')
        (folder/'manifest.json').write_text(json.dumps(notice, indent=2)+'\n')
        for p in (ROOT/'maps').glob('LibreQuake-*.txt'):shutil.copy2(p, folder/p.name)
        shutil.copy2(ROOT/'tools/makkon/Makkon_License.txt', folder/'Makkon_License.txt')
        new_row = dict(id=row['id'], title=row['title']+' (Community)', modes=['dm','tdm','ig','ft','cc'],
            path='res://maps/'+path.name, scene='res://maps/cache/'+row['id']+'.scn',
            sha256=sha(updated), recommended_players=row['recommended_players'], author=row['author'])
        catalog = [r for r in catalog if r['id'] != row['id']]+[new_row]
        results.append(notice)
    catalog_path.write_text(json.dumps(catalog, indent=2)+'\n')
    # New layouts are selectable; keep established default server rotations until
    # humans have evaluated flow/balance. A ready-made opt-in DM list is supplied.
    (ROOT/'maps/community_dm_maplist.txt').write_text('\n'.join(r['id'] for r in approved)+'\n')
    if args.bake:
        subprocess.run(['godot','--headless','--xr-mode','off','--path',str(ROOT),
            '--log-file', str(ROOT/'test-results/community-bake.log'),
            '--script','res://tools/community_maps/bake.gd'], check=True, cwd=ROOT)
    print(json.dumps(results, indent=2))


if __name__ == '__main__':main()
