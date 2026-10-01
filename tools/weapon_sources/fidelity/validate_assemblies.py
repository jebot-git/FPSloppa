"""Check actual surface intersections at the reported floating ST attachments."""
import bpy,bmesh,json,sys,os
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parent;sys.path.insert(0,str(ROOT))
from workshop import clear,load_gltf
rows=[]
def tree(ob,shift=Vector()):
 return BVHTree.FromPolygons([ob.matrix_world@v.co+shift for v in ob.data.vertices],[list(p.vertices) for p in ob.data.polygons])
for key in ['tribes_1','tribes_4','tribes_5','tribes_7']:
 clear();obs=load_gltf(ROOT/'refined'/(key+'.glb'));bpy.context.view_layer.update();parts={o.name:o for o in obs if o.type=='MESH'}
 links={'tribes_1':[('PowerCellSaddle','RearPowerCell'),('PowerCellSaddle','PlasmaReceiverShell'),('PlasmaHoodShoulder','PlasmaHoodSeat'),('PlasmaHoodSeat','PlasmaReceiverShell'),('PlasmaHoodShoulder','PlasmaHoodRetainer')], 'tribes_4':[('RedRangeSight','RangeSightDovetail'),('RangeSightDovetail','GrenadeReceiverShell')], 'tribes_5':[('PairedLaserBreech','LaserReceiverShell')], 'tribes_7':[('ClosedMortarBreech','HeavyMortarTube'),('MortarBreechSaddle','ClosedMortarBreech'),('MortarBreechSaddle','MortarBreechShell')]}[key]
 for a,b in links:
  pairs=tree(parts[a]).overlap(tree(parts[b]));rows.append({'key':key,'a':a,'b':b,'intersections':len(pairs)})
 if key=='tribes_1':
  retainers=[o for n,o in parts.items() if n.startswith('PlasmaHoodRetainer')]
  for name,ob in parts.items():
   if not name.startswith('VentedPlasmaHood'):continue
   for lift in [0,.013]:
    pairs=sum(len(tree(ob,Vector((0,0,lift))).overlap(tree(r))) for r in retainers)
    rows.append({'key':key,'a':name,'b':'retainers','vent_lift_m':lift,'intersections':pairs})
 if key=='tribes_5':
  for n,ob in parts.items():
   if n.startswith('LaserFocusingBarrel'):
    rows.append({'key':key,'a':'CarvedWalnutForeStock','b':n,'unwanted_intersections':len(tree(parts['CarvedWalnutForeStock']).overlap(tree(ob)))})
 if key=='tribes_7':
  ob=parts['ClosedMortarBreech'];bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
  rows.append({'key':key,'part':ob.name,'boundary_edges':sum(e.is_boundary for e in bm.edges)});bm.free()
path=ROOT.parents[2]/'test-results/weapon-fidelity/assembly-contacts.json';path.write_text(json.dumps(rows,indent=2))
failures=[r for r in rows if r.get('intersections',1)==0 or r.get('boundary_edges',0)!=0 or r.get('unwanted_intersections',0)!=0]
print('ASSEMBLY_CONTACTS',len(rows),'FAILURES',json.dumps(failures),flush=True)
os._exit(1 if failures else 0)
