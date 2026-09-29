"""Local Santorini regression: BSP30 + supplied WAD, no bundled map/artwork.
Usage: test_santorini.py ORIGINAL.bsp ORIGINAL.wad CONVERTED.bsp
"""
import hashlib
import json
import struct
import sys
import unittest
from pathlib import Path
from bsp import BSP
from textures import Wads, records, texture

if len(sys.argv)<4:
    raise SystemExit(__doc__)
SOURCE,WAD,OUTPUT=[Path(sys.argv.pop(1)) for _ in range(3)]


def extension(raw, key):
    end=(max(sum(struct.unpack_from('<ii',raw,4+i*8)) for i in range(15))+3)&~3
    for i in range(struct.unpack_from('<I',raw,end+4)[0]):
        name,at,size=struct.unpack_from('<24sII',raw,end+8+i*32)
        if name.rstrip(b'\0').decode()==key:return raw[at:at+size]
    raise ValueError('Missing extension '+key)


class SantoriniTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        raw=SOURCE.read_bytes()
        if hashlib.sha256(raw).hexdigest()!='3a83d058b262019a35ad2418fce573deb107f154449ea69b04ff3c635fae1bc1':
            raise ValueError('Unexpected Santorini source revision')
        cls.source=BSP(raw);cls.output=OUTPUT.read_bytes();cls.target=BSP(cls.output,29)
        cls.report=json.loads(OUTPUT.with_suffix('.conversion.json').read_text())

    def test_geometry_and_baked_colour_preserved(self):
        self.assertEqual(len(self.source.faces),11890)
        for i in [1,3,4,5,6,9,10,11,12,13,14]:self.assertEqual(self.source.lumps[i],self.target.lumps[i])
        self.assertEqual(self.source.lumps[8],extension(self.output,'RGBLIGHTING'))
        # The final face triggered the float32-vs-double extent regression.
        self.assertEqual(self.target.faces[-1][-1],1457115//3)

    def test_original_wad_art_and_palette_preserved(self):
        wads=Wads([WAD]);palettes=extension(self.output,'FSL_PALETTES')
        lump=self.target.lumps[2]
        for i,row in enumerate(self.report['textures']):
            if row['source'].startswith('generated:'):continue
            name,w,h,mips,palette=texture(wads.entries[row['name']][0])
            self.assertEqual(palettes[8+i*768:8+(i+1)*768],palette)
            if 'resampled_from' in row:continue
            at=struct.unpack_from('<i',lump,4+i*4)[0]
            for mip,pixels in enumerate(mips):
                offset=struct.unpack_from('<I',lump,at+24+mip*4)[0]
                self.assertEqual(lump[at+offset:at+offset+len(pixels)],pixels)

    def test_replacements_and_resampling_are_limited(self):
        rows=self.report['textures']
        self.assertEqual(len(rows),79)
        self.assertEqual({r['name'] for r in rows if r['source'].startswith('generated:')},{'aaatrigger','clip','grid2','null'})
        self.assertEqual({r['name'] for r in rows if 'resampled_from' in r},{'black','sky'})

    def test_team_spawns_and_sites(self):
        layout=self.report['layout']
        self.assertEqual([len(v) for v in layout['starts']],[18,18])
        self.assertEqual([len(v) for v in layout['volumes']],[1,1])

    def test_actual_engine_import_and_all_navigation_routes(self):
        self.assertEqual(self.report['runtime_validation'],'passed')
        log=OUTPUT.with_suffix('.validation.log').read_text()
        self.assertIn('CS_MAP_VALIDATION_PASS',log);self.assertNotIn('ERROR:',log)
        self.assertEqual(sum('spawn can route to site' in line for line in log.splitlines()),72)


if __name__=='__main__':unittest.main()
