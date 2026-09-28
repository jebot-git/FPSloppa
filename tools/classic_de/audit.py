"""Read-only BSP29/30 cover/entity survey. Reference BSPs are never installed.

Usage: python3 tools/classic_de/audit.py --references /path/to/cs16/maps
The diagrams show upward-facing polygons below a height cutoff, with sky
omitted; they are geometry evidence, not textured gameplay screenshots. Each
panel keeps its own BSP coordinates and scale. Nuke has an extra lower slice.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import struct

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
NAMES = ['dust2', 'nuke', 'inferno', 'aztec', 'train']


class BSP:
    def __init__(self, path):
        self.path = Path(path)
        raw = self.raw = self.path.read_bytes()
        assert 124 <= len(raw) <= 25_000_000
        self.version = struct.unpack_from('<i', raw)[0]
        assert self.version in (29, 30)
        self.lumps = [struct.unpack_from('<ii', raw, 4 + i * 8) for i in range(15)]
        assert all(0 <= o <= len(raw) and 0 <= n <= len(raw) - o for o, n in self.lumps)
        self.entities = [dict(re.findall(r'"([^"\n]*)"\s*"([^"\n]*)"', row))
                         for row in self.lump(0).decode('latin1').split('}') if 'classname' in row]
        self.vertices = np.array(self.records(3, '<3f'))
        self.planes = self.records(1, '<4fi')
        self.edges = self.records(12, '<2H')
        self.surfedges = [row[0] for row in self.records(13, '<i')]
        self.texinfo = self.records(6, '<8f2i')
        self.faces = self.records(7, '<HhiHH4Bi')
        self.models = self.records(14, '<9f7i')
        texture_data = self.lump(2)
        count = struct.unpack_from('<i', texture_data)[0]
        assert 0 <= count <= 10000
        self.textures = []
        for i in range(count):
            offset = struct.unpack_from('<i', texture_data, 4 + i * 4)[0]
            self.textures.append(texture_data[offset:offset+16].split(b'\0')[0].decode('latin1') if offset >= 0 else '<missing>')
        self.owners = {0: self.entities[0]}
        for e in self.entities:
            if e.get('model', '').startswith('*'):
                self.owners[int(e['model'][1:])] = e

    def lump(self, index):
        o, n = self.lumps[index]
        return self.raw[o:o+n]

    def records(self, index, fmt):
        return list(struct.iter_unpack(fmt, self.lump(index)))

    def polygon(self, index):
        plane, side, start, count, tex, *_ = self.faces[index]
        indices = [self.edges[abs(edge)][0 if edge >= 0 else 1]
                   for edge in self.surfedges[start:start+count]]
        normal = np.array(self.planes[plane][:3]) * (-1 if side else 1)
        return self.vertices[indices], normal, self.textures[self.texinfo[tex][8]]

    def brush_record(self, entity):
        index = int(entity['model'][1:])
        model = self.models[index]
        offset = np.fromstring(entity.get('origin', '0 0 0'), sep=' ')
        low, high = np.array(model[:3]) + offset, np.array(model[3:6]) + offset
        return dict(entity, bounds=[low.tolist(), high.tolist()],
                    textures=sorted({self.polygon(i)[2] for i in range(model[-2], model[-2]+model[-1])}))

    def summary(self):
        kinds = Counter(e['classname'] for e in self.entities)
        relevant = [self.brush_record(e) for e in self.entities if e.get('classname') in
                    ['func_door', 'func_door_rotating', 'func_breakable', 'func_bomb_target']]
        shootable = [e for e in relevant if e['classname'] == 'func_breakable'
                     and not int(e.get('spawnflags', 0)) & 1 and int(e.get('material', 0)) != 7]
        return {'file': str(self.path), 'sha256': hashlib.sha256(self.raw).hexdigest(),
                'version': self.version, 'faces': len(self.faces), 'brush_models': len(self.models),
                'texture_names': self.textures, 'entity_counts': dict(kinds),
                'doors': [e for e in relevant if 'door' in e['classname']],
                'breakables': [e for e in relevant if e['classname'] == 'func_breakable'],
                'shoot_damage_enabled_breakables': len(shootable),
                'sites': [e for e in relevant if e['classname'] == 'func_bomb_target']}

    def plan(self, ax, title, cut=None):
        rows = []
        for index, model in enumerate(self.models):
            entity = self.owners.get(index, {})
            kind = entity.get('classname', '')
            if kind.startswith('trigger_') or kind in ['func_bomb_target', 'func_buyzone', 'func_ladder']:
                continue
            offset = np.fromstring(entity.get('origin', '0 0 0'), sep=' ')
            for face in range(model[-2], model[-2]+model[-1]):
                points, normal, texture = self.polygon(face)
                points = points + offset
                if normal[2] < .05 or texture.lower().startswith(('sky', 'clip', 'origin')):
                    continue
                if cut is not None and points[:, 2].mean() > cut:
                    continue
                category = 'cover' if any(s in texture.lower() for s in ['crate', 'box', 'sandcrt', 'mltrycrte', 'ind_wd01', 'cont1', 'train', 'wagon', 'casetop', 'caseside']) else 'floor'
                if 'door' in kind: category = 'door'
                elif kind == 'func_breakable' and not int(entity.get('spawnflags', 0)) & 1:category = 'breakable'
                rows.append((float(points[:, 2].mean()), points[:, :2], category))
        rows.sort(key=lambda row: row[0])
        heights = np.array([row[0] for row in rows])
        low, high = np.percentile(heights, [2, 98])
        polygons, colors = [], []
        for z, polygon, kind in rows:
            colors.append({'cover':'#d8a451', 'door':'#eb5e55', 'breakable':'#bd7cf3'}.get(kind,
                          plt.get_cmap('Blues')(.25+.5*np.clip((z-low)/max(high-low,1),0,1))))
            polygons.append(polygon)
        ax.add_collection(PolyCollection(polygons, facecolors=colors, edgecolors='#182a3e', linewidths=.08))
        ax.autoscale();ax.set_aspect('equal');ax.set_title(title, fontsize=12)
        ax.set_facecolor('#edf1f4');ax.tick_params(labelsize=7)
        ax.set_xlabel('BSP X / map units', fontsize=8);ax.set_ylabel('BSP Y / map units', fontsize=8)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--references', type=Path, required=True)
    parser.add_argument('--out', type=Path, default=ROOT/'test-results/de-fidelity')
    args=parser.parse_args();args.out.mkdir(parents=True, exist_ok=True)
    rows=[]
    for name in NAMES:
        original=BSP(args.references/f'de_{name}.bsp')
        rebuilt=BSP(ROOT/f'maps/de_{name}_rebuilt.bsp')
        fig, axes=plt.subplots(1, 2, figsize=(14, 7), layout='constrained')
        cuts={'dust2':(320,400),'nuke':(-224,192),'inferno':(320,176),'aztec':(-64,176),'train':(0,176)}
        original_cut,rebuilt_cut=cuts[name]
        original.plan(axes[0],f'{name.upper()} · reference BSP30 · Z ≤ {original_cut}',original_cut)
        rebuilt.plan(axes[1],f'{name.upper()} · FPSloppa BSP29 · Z ≤ {rebuilt_cut}',rebuilt_cut)
        fig.suptitle('Geometry survey · separate coordinate systems / scales\nGold: named cover textures   Red: moving doors   Purple: damageable brushes', fontsize=13)
        fig.savefig(args.out/f'{name}-plan.png',dpi=150);plt.close(fig)
        if name=='nuke':
            fig, axes=plt.subplots(1,2,figsize=(14,7),layout='constrained')
            original.plan(axes[0],'NUKE · reference lower slice (Z ≤ −500)',-500)
            rebuilt.plan(axes[1],'NUKE · rebuilt lower slice (Z ≤ −100)',-100)
            fig.savefig(args.out/'nuke-lower-plan.png',dpi=150);plt.close(fig)
        record={'map':name,'reference':original.summary(),'rebuilt':rebuilt.summary()}
        rows.append(record)
        print(name, json.dumps({key: {'faces':record[key]['faces'],'doors':len(record[key]['doors']),
                'damageable_brushes':record[key]['shoot_damage_enabled_breakables']} for key in ['reference','rebuilt']}))
    (args.out/'bsp-survey.json').write_text(json.dumps({'maps':rows,'limits':[
        'Reference files are pinned community-hosted CS 1.6 BSPs, not authenticated Steam depot extracts.',
        'Entity, face and texture counts are structural observations, not fidelity scores.',
        'Cover highlighting uses texture-name heuristics and does not count individual cover objects.',
        'Plan panels are not geometrically registered; exact positional deviation is not measured.',
        'Height cutoffs omit higher geometry; overlapping floors require separate slices. These are not complete object inventories.',
        'Trigger-only breakable brushes are not counted as shoot-damage-enabled surfaces.',
        'No reference geometry or textures are installed into the game.']},indent=2)+'\n')


if __name__=='__main__':main()
