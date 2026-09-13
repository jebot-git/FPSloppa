"""Read the original BA-2 with auto-execution disabled; report its actual rig."""
import bpy, json
from pathlib import Path
from collections import Counter
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/ba2'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'tools/ba2/source/extracted/Quandtum_BA-2_v1_1.blend'), load_ui=False, use_scripts=False)
report = {'blender': bpy.app.version_string, 'objects': [], 'actions': [], 'images': []}
for o in bpy.data.objects:
    r = {'name': o.name, 'type': o.type, 'parent': o.parent.name if o.parent else None,
         'dimensions': list(o.dimensions), 'scale': list(o.scale), 'location': list(o.location)}
    if o.type == 'MESH':
        o.data.calc_loop_triangles()
        r.update(vertices=len(o.data.vertices), triangles=len(o.data.loop_triangles),
                 materials=[m.name if m else None for m in o.data.materials],
                 modifiers=[{'type': m.type, 'name': m.name} for m in o.modifiers],
                 groups={g.name: sum(1 for v in o.data.vertices if any(w.group == g.index and w.weight > 0 for w in v.groups)) for g in o.vertex_groups},
                 unweighted=sum(not any(w.weight > 0 for w in v.groups) for v in o.data.vertices),
                 influences=dict(Counter(sum(w.weight > 0 for w in v.groups) for v in o.data.vertices)))
        adj=[[] for _ in o.data.vertices]
        for e in o.data.edges:
            a,b=e.vertices; adj[a].append(b); adj[b].append(a)
        seen=set(); components=[]
        for start in range(len(adj)):
            if start in seen: continue
            stack=[start]; seen.add(start); ids=[]
            while stack:
                v=stack.pop(); ids.append(v)
                for n in adj[v]:
                    if n not in seen: seen.add(n); stack.append(n)
            components.append(len(ids))
        r['connected_components'] = sorted(components, reverse=True)
    if o.type == 'ARMATURE':
        r['bones']=[{'name': b.name, 'parent': b.parent.name if b.parent else None,
                     'head': list(b.head_local), 'tail': list(b.tail_local), 'deform': b.use_deform,
                     'constraints': [{'type': c.type, 'name': c.name, 'target': getattr(getattr(c,'target',None),'name',None), 'subtarget': getattr(c,'subtarget',None)} for c in o.pose.bones[b.name].constraints]} for b in o.data.bones]
    report['objects'].append(r)
for a in bpy.data.actions:
    report['actions'].append({'name': a.name, 'frame_range': list(a.frame_range)})
for i in bpy.data.images:
    report['images'].append({'name': i.name, 'size': list(i.size), 'packed': bool(i.packed_file), 'path': i.filepath})
report['texts'] = [t.name for t in bpy.data.texts]
(OUT/'inspection.json').write_text(json.dumps(report, indent=2)+'\n')
print('BA2_INSPECTION_COMPLETE', flush=True)
