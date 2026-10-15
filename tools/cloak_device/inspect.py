import bpy,json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(root/'tools/cloak_device/source/EnergyCell/EnergyCell.blend'),load_ui=False)
for o in bpy.data.objects:
 if o.type=='MESH':
  o.data.calc_loop_triangles();print('SOURCE',o.name,'triangles',len(o.data.loop_triangles),'bounds',list(o.dimensions),'materials',[m.name if m else '' for m in o.data.materials])
for m in bpy.data.materials:print('MAT',m.name,'color',list(m.diffuse_color),'nodes',[(n.type,n.name) for n in m.node_tree.nodes] if m.use_nodes else '')
