"""Regression checks for the user's local de_prodigy32.bsp; no map is bundled.

Run after convert.py --replace-missing --validate. Supply original and converted
BSP paths. This suite binds its expectations to the exact supplied source hash.
"""
import hashlib
import json
import struct
import sys
import unittest
from pathlib import Path
from bsp import BSP
from entities import site_groups
from textures import records

if len(sys.argv)<3:
    raise SystemExit('Usage: test_prodigy.py ORIGINAL.bsp CONVERTED.bsp')
SOURCE=Path(sys.argv.pop(1));OUTPUT=Path(sys.argv.pop(1))
SOURCE_SHA='84e955e900af19fa1e35d0a892ff0d93cdd763d486c5e7d71742314eae3e79b6'


class ProdigyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        raw=SOURCE.read_bytes()
        if hashlib.sha256(raw).hexdigest()!=SOURCE_SHA:
            raise ValueError('This regression expects the supplied de_prodigy32.bsp revision')
        cls.source=BSP(raw);cls.target=BSP(OUTPUT.read_bytes(),29)
        cls.report=json.loads(OUTPUT.with_suffix('.conversion.json').read_text())

    def test_original_geometry_and_uvs_unchanged(self):
        self.assertEqual(len(self.source.faces),7962)
        self.assertEqual(len(self.source.models),62)
        for i in [1,3,4,5,6,9,10,11,12,13,14]:
            self.assertEqual(self.target.lumps[i],self.source.lumps[i])

    def test_both_teams_and_individual_facing(self):
        self.assertEqual([len(v) for v in self.report['layout']['starts']],[16,16])
        self.assertEqual([len(v) for v in self.report['layout']['start_yaws']],[16,16])
        for classname in ['info_player_team1','info_player_team2']:
            self.assertEqual(sum(e['classname']==classname for e in self.target.entities),16)

    def test_four_brushes_form_two_irregular_sites(self):
        sites=[(i,e) for i,e in enumerate(self.source.entities) if e['classname']=='func_bomb_target']
        self.assertEqual(site_groups(self.source,sites),[[85,88,89],[86]])
        self.assertEqual([len(v) for v in self.report['layout']['volumes']],[3,1])

    def test_blocked_centre_relocated_within_site(self):
        for p in self.report['layout']['sites']:
            # Invert the engine transform and remove the .05 m floor allowance.
            point=[-p[2]*32,-p[0]*32,(p[1]-.05)*32]
            self.assertTrue(self.source.standing_clear(point))
        self.assertFalse(self.source.standing_clear([1968,-84,-416]))

    def test_all_missing_art_explicitly_replaced(self):
        source=records(self.source.lumps[2])
        self.assertEqual(len(source),214)
        self.assertTrue(all(row[3] is None for row in source))
        self.assertTrue(all(r['source'].startswith('generated:') for r in self.report['textures']))
        for row, target in zip(source,self.report['textures']):
            self.assertEqual(row[1:3],(target['width'],target['height']))
        self.assertTrue(any('approximations' in warning for warning in self.report['warnings']))

    def test_sliding_doors_and_documented_ladder_limit(self):
        doors=[e for e in self.target.entities if e['classname']=='func_door']
        self.assertEqual(len(doors),3)
        self.assertTrue(all(e['_de_reset']=='1' for e in doors))
        self.assertTrue(any('func_ladder' in w for w in self.report['warnings']))
        self.assertTrue(any('func_breakable' in w for w in self.report['warnings']))

    def test_hash_and_engine_validation(self):
        self.assertEqual(self.report['source_sha256'],SOURCE_SHA)
        self.assertEqual(self.report['sha256'],hashlib.sha256(OUTPUT.read_bytes()).hexdigest())
        self.assertEqual(self.report['runtime_validation'],'passed')
        log=OUTPUT.with_suffix('.validation.log').read_text()
        self.assertIn('CS_MAP_VALIDATION_PASS',log)
        self.assertNotIn('ERROR:',log)
        self.assertEqual(sum('spawn can route to site' in line for line in log.splitlines()),64)


if __name__=='__main__':unittest.main()
