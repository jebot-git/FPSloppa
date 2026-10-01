"""Project Krita layered surface artwork onto authored material regions before UV baking."""
import bpy,math
from mathutils import Vector
from workshop import ROOT

def finish(meshes,key):
 base_path=ROOT/'material-swatches.png';panel_path=ROOT/'weapon-panels.png'
 if not base_path.exists():return
 realistic=key.startswith(('tribes','cs16'))
 if realistic:base_path=ROOT/('furniture-surfaces.png' if key.startswith('cs16') or key in ['tribes_1','tribes_2','tribes_3','tribes_4','tribes_5','tribes_7'] else 'realistic-surfaces.png')
 image=bpy.data.images.load(str(base_path),check_existing=True)
 panels=bpy.data.images.load(str(panel_path),check_existing=True) if panel_path.exists() else image
 mats={}
 def get(tile,panel=False):
  k=(tile,panel)
  if k in mats:return mats[k]
  mat=bpy.data.materials.new('Painted finish '+str(k));mat.use_nodes=True
  p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Roughness'].default_value=[.48,.35,.64,.43,.4,.58,.61,.76][tile];p.inputs['Metallic'].default_value=.8 if tile in [0,1,4] else .05
  if realistic and tile==1:p.inputs['Roughness'].default_value=.55;p.inputs['Metallic'].default_value=.55
  if realistic and tile==4:p.inputs['Roughness'].default_value=.58;p.inputs['Metallic'].default_value=.55
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=panels if panel else image;mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
  mats[k]=mat;return mat
 for ob in meshes:
  if ob.get('lamp') or 'EnergyIndicator' in ob.name or any(n in ob.name for n in ['RedRangeSight','OrangeCellBand']):continue
  mesh=ob.data;old=list(mesh.materials);indices=[p.material_index for p in mesh.polygons]
  uv=mesh.uv_layers.active or mesh.uv_layers.new(name='SourceUV');mesh.materials.clear();mapping={}
  for p,index in zip(mesh.polygons,indices):
   name=old[index].name.lower() if index<len(old) and old[index] else ''
   tile=7 if any(s in name for s in ['rubber','stipple','grip inset','black']) else 3 if any(s in name for s in ['walnut','wood']) else 4 if any(s in name for s in ['bronze','brass']) else 0 if any(s in name for s in ['blued','dark','steel']) else 1
   if any(s in name for s in ['shell','enamel']):tile=2 if key.startswith('doom') else 4 if key.startswith('quake') else 2
   if 'blue enamel' in name:tile=5
   if key.startswith('tribes') and ob.name in ['InstrumentReceiver','PlasmaReceiver','GrenadeReceiver','MortarBreech','RearElectronics']:tile=0
   if name.startswith('authored'):
    index=int(name.split(' ')[2].split('.')[0]);tile=[2 if key.startswith('doom') else 4 if key.startswith('quake') else 5,1,7,4][index]
    if key in ['doom_3','doom_4','quake_2','quake_3']:tile=[0,1,7,3][index]
    if key=='ut99_4':tile=[6,0,7,4][index]
   panel=not realistic and len(p.vertices)>=4 and abs(p.normal.x)>.92 and p.area>.012 and any(n in ob.name.lower() for n in ['receiver','cheek','electronics','collar','stock'])
   k=(tile,panel)
   if k not in mapping:mapping[k]=len(mesh.materials);mesh.materials.append(get(*k))
   p.material_index=mapping[k]
   axis=max(range(3),key=lambda i:abs(p.normal[i]));axes=[i for i in range(3) if i!=axis]
   coords=[ob.matrix_world@mesh.vertices[mesh.loops[li].vertex_index].co for li in p.loop_indices]
   lows=[min(v[a] for v in coords) for a in axes];highs=[max(v[a] for v in coords) for a in axes]
   # Planar panels use the whole painted tile. Curved and small pieces get only
   # the uninterrupted material swatch, at one consistent texel scale.
   for li,v in zip(p.loop_indices,coords):
    if panel:values=[(v[a]-lows[j])/max(.001,highs[j]-lows[j]) for j,a in enumerate(axes)]
    else:values=[(v[a]*1.4+.5)%1 for a in axes]
    mapped=[0,4,3,2,5,0,5,1][tile] if realistic else tile
    uv.data[li].uv=((mapped%4+.035+.93*values[0])/4,((mapped//4 if realistic else 1-mapped//4)+.035+.93*values[1])/2)
