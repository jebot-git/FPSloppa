"""Regression tests against the authored, compiled BSP30 fixture."""
import copy
import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path
from bsp import BSP, ConversionError, entity_bytes, pack, parse_entities
from convert import convert, main
from textures import Wads, texture

FIXTURE = Path(sys.argv.pop(1)) if len(sys.argv) > 1 and not sys.argv[1].startswith('-') else Path('test-results/cs16-map-converter/fixture')


def ext(raw):
    end = max(sum(struct.unpack_from('<ii', raw, 4+i*8)) for i in range(15))
    end = (end+3)&~3
    result = {}
    for i in range(struct.unpack_from('<I', raw, end+4)[0]):
        name, at, size = struct.unpack_from('<24sII', raw, end+8+i*32)
        result[name.rstrip(b'\0').decode()] = raw[at:at+size]
    return result


class ConverterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = (FIXTURE/'de_fixture.bsp').read_bytes()
        cls.source = BSP(cls.raw)
        cls.output, cls.report = cls.run_convert(cls.raw)

    @staticmethod
    def run_convert(raw, sites=None):
        return convert(raw, Wads([FIXTURE/'external.wad']), 'Fixture', sites)

    def with_entities(self, entities):
        lumps=self.source.lumps.copy();lumps[0]=entity_bytes(entities)
        result=bytearray(pack(lumps,{}));struct.pack_into('<i',result,0,30);return bytes(result)

    def test_repeated_editor_version_does_not_change_gameplay_keys(self):
        self.assertEqual(parse_entities(b'{"classname" "worldspawn" "mapversion" "220" "mapversion" "221"}')[0]['mapversion'],'221')
        with self.assertRaises(ConversionError):
            parse_entities(b'{"classname" "worldspawn" "origin" "0 0 0" "origin" "1 0 0"}')

    def test_texture_count_is_bounded_before_unused_slot_scan(self):
        lumps=self.source.lumps.copy();lumps[2]=struct.pack('<i',2147483647)
        with self.assertRaises(ConversionError):
            self.run_convert(struct.pack('<i',30)+pack(lumps,{})[4:])

    def test_unused_negative_texture_slot(self):
        lumps=self.source.lumps.copy();old=lumps[2];count=struct.unpack_from('<i',old)[0]
        offsets=struct.unpack_from('<'+'i'*count,old,4)
        lumps[2]=struct.pack('<i',count+1)+struct.pack('<'+'i'*(count+1),*[p+4 for p in offsets],-1)+old[4+4*count:]
        output,report=self.run_convert(struct.pack('<i',30)+pack(lumps,{})[4:])
        self.assertEqual(report['textures'][-1]['source'],'unused-slot')
        self.assertEqual(report['textures'][-1]['output_name'],'skip')
        # An absent slot used by real faces is still rejected, even with replacements.
        texinfo=bytearray(lumps[6]);index=self.source.faces[0][4]
        struct.pack_into('<i',texinfo,index*40+32,count);lumps[6]=bytes(texinfo)
        with self.assertRaises(ConversionError):
            convert(struct.pack('<i',30)+pack(lumps,{})[4:],Wads([FIXTURE/'external.wad']),'Broken',replace_missing=True)

    def test_geometry_preserved(self):
        target=BSP(self.output,29)
        for i in [1,3,4,5,6,9,10,11,12,13,14]:self.assertEqual(target.lumps[i],self.source.lumps[i])

    def test_rgb_and_face_offsets(self):
        target=BSP(self.output,29);rgb=ext(self.output)['RGBLIGHTING']
        self.assertEqual(rgb,self.source.lumps[8]);self.assertEqual(len(target.lumps[8])*3,len(rgb))
        for a,b in zip(self.source.faces,target.faces):
            self.assertEqual(a[:-1],b[:-1]);self.assertEqual(b[-1],-1 if a[-1]==-1 else a[-1]//3)

    def test_palette_and_all_four_mips(self):
        target=BSP(self.output,29);table=target.lumps[2];palettes=ext(self.output)['FSL_PALETTES']
        for i,row in enumerate(self.report['textures']):
            at=struct.unpack_from('<i',table,4+i*4)[0]
            for mip in range(4):
                start=struct.unpack_from('<I',table,at+24+mip*4)[0]
                if row['name']=='testfloor':self.assertEqual(set(table[at+start:at+start+(32>>mip)**2]),{230})
            if row['name']=='testfloor':self.assertEqual(palettes[8+i*768+230*3:8+i*768+231*3],bytes([37,149,231]))
        self.assertEqual(self.report['used_wads'],['external.wad'])

    def test_objectives_and_spawn_roles(self):
        layout=self.report['layout'];self.assertEqual([len(x) for x in layout['starts']],[2,2])
        self.assertEqual(len(layout['sites']),2);self.assertTrue(all(abs(p[1]-.05)<1e-6 for points in layout['starts'] for p in points))
        rows=BSP(self.output,29).entities
        self.assertEqual(sum(e['classname']=='info_player_team1' for e in rows),2)
        self.assertEqual(sum(e['classname']=='info_player_team2' for e in rows),2)
        self.assertFalse(any(e['classname']=='func_bomb_target' for e in rows))
        door=next(e for e in rows if e['classname']=='func_door')
        self.assertEqual(door['_de_reset'],'1');self.assertEqual(float(door['angle']),90)
        self.assertNotIn('wad',rows[0])

    def test_explicit_site_order(self):
        ids=[i for i,e in enumerate(self.source.entities) if e['classname']=='func_bomb_target']
        _,r=self.run_convert(self.raw,{'A':{'entity':ids[1]},'B':{'entity':ids[0]}})
        self.assertEqual(r['layout']['sites'],list(reversed(self.report['layout']['sites'])))

    def test_missing_wad_is_error(self):
        with self.assertRaisesRegex(ConversionError,'Missing textures'):convert(self.raw,Wads([]),'Fixture')

    def test_unsafe_wad_reference_not_followed(self):
        rows=copy.deepcopy(self.source.entities);rows[0]['wad']='../../private.wad'
        with self.assertRaisesRegex(ConversionError,'Missing textures'):convert(self.with_entities(rows),Wads([]),'Fixture')

    def test_bad_lump_bounds(self):
        raw=bytearray(self.raw);struct.pack_into('<i',raw,12,len(raw)+1)
        with self.assertRaises(ConversionError):BSP(raw)

    def test_cyclic_nodes(self):
        raw=bytearray(self.raw);at,_=struct.unpack_from('<ii',raw,44);struct.pack_into('<h',raw,at+4,0)
        with self.assertRaisesRegex(ConversionError,'Cyclic'):BSP(raw)

    def test_nonfinite_vertices(self):
        raw=bytearray(self.raw);at,_=struct.unpack_from('<ii',raw,28);struct.pack_into('<f',raw,at,float('nan'))
        with self.assertRaises(ConversionError):BSP(raw)

    def test_bad_light_offset(self):
        raw=bytearray(self.raw);at,_=struct.unpack_from('<ii',raw,60);struct.pack_into('<i',raw,at+16,2)
        with self.assertRaisesRegex(ConversionError,'lightmap offset'):self.run_convert(raw)

    def test_palette_truncated(self):
        with self.assertRaises(ConversionError):texture(bytes(40))

    def test_no_ct_spawns(self):
        rows=[e for e in self.source.entities if e['classname']!='info_player_start']
        with self.assertRaisesRegex(ConversionError,'Both T and CT'):self.run_convert(self.with_entities(rows))

    def test_one_site_needs_override(self):
        rows=copy.deepcopy(self.source.entities)
        rows.pop(next(i for i,e in enumerate(rows) if e['classname']=='func_bomb_target'))
        with self.assertRaisesRegex(ConversionError,'Found 1 bomb targets'):self.run_convert(self.with_entities(rows))

    def test_unsupported_entities_reported(self):
        rows=copy.deepcopy(self.source.entities);rows.append({'classname':'func_ladder','model':'*1'})
        _,report=self.run_convert(self.with_entities(rows));self.assertTrue(any('func_ladder' in s and 'omitted' in s for s in report['warnings']))

    def test_no_silent_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            destination=Path(directory)/'de_fixture_fps.bsp';destination.write_bytes(b'previous map')
            with self.assertRaisesRegex(ConversionError,'Refusing to replace'):
                main([str(FIXTURE/'de_fixture.bsp'),'--wad',str(FIXTURE/'external.wad'),'--output',directory])
            self.assertEqual(destination.read_bytes(),b'previous map')

    def test_parser_rejects_bad_entities(self):
        for raw in [b'{ "classname" "worldspawn"',b'{ "classname" "worldspawn" "classname" "other" }',b'junk']:
            with self.assertRaises(ConversionError):parse_entities(raw)

    def test_touching_site_components(self):
        from entities import site_groups
        rows=copy.deepcopy(self.source.entities)
        first=next(e for e in rows if e['classname']=='func_bomb_target')
        rows.append(first.copy())
        bsp=BSP(self.with_entities(rows))
        groups=site_groups(bsp,[(i,e) for i,e in enumerate(rows) if e['classname']=='func_bomb_target'])
        self.assertEqual([len(group) for group in groups],[2,1])
        _,report=self.run_convert(self.with_entities(rows))
        self.assertEqual([len(group) for group in report['layout']['volumes']],[2,1])

    def test_explicit_components_reject_duplicates(self):
        ids=[i for i,e in enumerate(self.source.entities) if e['classname']=='func_bomb_target']
        with self.assertRaisesRegex(ConversionError,'repeated'):
            self.run_convert(self.raw,{'A':{'entities':[ids[0],ids[0]]},'B':{'entity':ids[1]}})

    def test_missing_texture_replacement_is_explicit(self):
        _,report=convert(self.raw,Wads([]),'Fixture',replace_missing=True)
        replaced=[r for r in report['textures'] if r['source'].startswith('generated:')]
        self.assertEqual([r['name'] for r in replaced],['testwall'])
        self.assertTrue(any('approximations' in w for w in report['warnings']))
        # Supplying real WAD art still wins over the fallback.
        self.assertEqual(self.output,convert(self.raw,Wads([FIXTURE/'external.wad']),'Fixture',replace_missing=True)[0])

    def test_replacement_materials_and_cutout_mips(self):
        from replacements import COLOURS, generate, category
        self.assertEqual(category('+0lab1_comp3'),'screen')
        self.assertEqual(category('crate07'),'wood')
        for kind in COLOURS:
            mips,palette,_=generate('{test',32,48,kind)
            self.assertEqual(len(palette),768)
            self.assertEqual([len(m) for m in mips],[1536,384,96,24])
            self.assertEqual((mips,palette,kind),generate('{test',32,48,kind))
        mips,_,_=generate('{rail1c',48,32)
        self.assertIn(255,mips[0]);self.assertTrue(any(p!=255 for p in mips[0]))
        self.assertEqual(generate('test',32,32,'wood')[2],'wood')

    def test_identical_duplicate_editor_keys(self):
        rows=parse_entities(b'{ "classname" "worldspawn" "mapversion" "220" "mapversion" "220" "classname" "worldspawn" }')
        self.assertEqual(rows,[{'classname':'worldspawn','mapversion':'220'}])

    def test_deterministic(self):
        self.assertEqual(self.output,self.run_convert(self.raw)[0])
        self.assertEqual(json.loads(ext(self.output)['FSL_DE']),self.report['layout'])


if __name__=='__main__':unittest.main()
