"""Firearm-specific grip contours and photographic material finish.
Sights, controls, magazine wells and action pivots remain in their original poses.
"""
import bpy,bmesh,math
from workshop import ROOT

def refine(meshes,key):
 slot=int(key.split('_')[1]);image=bpy.data.images.load(str(ROOT/('furniture-surfaces.png' if slot in [1,2,10,11] else 'realistic-surfaces.png')),check_existing=True)
 for ob in meshes:
  for mat in ob.data.materials:
   if not mat or not mat.use_nodes:continue
   p=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
   if not p:continue
   for n in mat.node_tree.nodes:
    if n.type=='TEX_IMAGE' and n.image:n.image=image
   name=mat.name.lower()
   p.inputs['Metallic'].default_value=.85 if any(n in name for n in ['steel','brass']) else 0
   p.inputs['Roughness'].default_value=.32 if 'machined' in name else .38 if 'brass' in name else .52 if 'parkerized' in name else .43 if 'walnut' in name else .72
  if ob.name!='Body' or slot in [0,1,2,9,10,11]:continue
  bm=bmesh.new();bm.from_mesh(ob.data);remaining=set(bm.verts)
  while remaining:
   seed=remaining.pop();component={seed};todo=[seed]
   while todo:
    v=todo.pop()
    for e in v.link_edges:
     other=e.other_vert(v)
     if other in remaining:remaining.remove(other);component.add(other);todo.append(other)
   lo=[min(v.co[i] for v in component) for i in range(3)];hi=[max(v.co[i] for v in component) for i in range(3)]
   # Only disconnected grip furniture and its seated side inserts qualify.
   # The receiver, guard, barrel, magazine and manipulation controls do not.
   if lo[1]<-.145 or hi[1]>.035 or hi[2]>.078 or lo[2]>-.025:continue
   for v in component:
    z=v.co.z
    # Narrow the palm swell with a rounded cross-section; retain the neck.
    envelope=max(0,min(1,(.045-z)/.07))
    v.co.x*=1-.20*envelope
    # Long-gun furniture: correct the excessive rear rake around the fixed palm.
    # Pistol well geometry is left aligned to its magazine and reload controls.
    if slot not in [1,2,10]:v.co.y-=(z+.057)*.15*envelope
  bm.to_mesh(ob.data);bm.free();ob.data.update()
