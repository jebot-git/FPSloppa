"""Weapon-specific edits of the additional user-selected CC0 donors."""
import bpy,bmesh,math
from mathutils import Vector,Matrix
from workshop import ROOT,load_gltf,transform_meshes
from designs import lathe,side_profile

SOURCES={
 'doom_1':'3rd-person-blender-sci-fi-pack','doom_2':'retro-style-pistol-lowpoly',
 'doom_7':'sci-fi-rifle','doom_8':'sci-fi-rifle','ut99_2':'fallout-shelter-laser-pistol',
 'ut99_3':'energy-rifle','ut99_8':'akira-laser-rifle-st-001'}

def build(key,anchors,mat):
 objects=load_gltf(ROOT/'catalog'/('new_'+SOURCES[key]+'.glb'));parts=[o for o in objects if o.type=='MESH'];transform_meshes(parts,Matrix.Identity(4))
 for ob in objects:
  if ob.type!='MESH':bpy.data.objects.remove(ob,do_unlink=True)
 def xyz(v):return Vector((v[0],-v[2],v[1]))
 grip=xyz(anchors[key]['grip']);muzzle=xyz(anchors[key]['muzzle']);muzzle.y-=.015
 specs={'doom_1':((0,.08,-.035),(0,1,-.064)), 'doom_2':((0,.15,-.14),(0,1,.215)),
 'doom_7':((0,.14,-.12),(0,1,.087)), 'doom_8':((0,.14,-.12),(0,1,.087)),
 'ut99_2':((.025,.15,-.18),(0,1,.19)), 'ut99_3':((-.079,.32,-.105),(-.079,1,-.025)),
 'ut99_8':((0,.39,-.06),(0,1,.014))}
 palm,tip=[Vector(v) for v in specs[key]]
 sy=(muzzle.y-grip.y)/(tip.y-palm.y);sz=(muzzle.z-grip.z)/(tip.z-palm.z) if key!='doom_1' else sy
 sx=min(sy,sz) if key in ['doom_2','ut99_2'] else sy
 if key=='doom_8':sx*=1.65
 if key=='ut99_8':sx*=1.6;sz=min(sz,sy*1.8)
 if key=='ut99_3':sz=min(sz,sy*1.2)
 steel=mat('Blued steel',(.042,.054,.065),.6);alloy=mat('Machined alloy',(.24,.27,.30),.6);rubber=mat('Stippled rubber',(.026,.029,.032),.02)
 copper=mat('Breech bronze',(.29,.12,.035),.5);blue=mat('Blue enamel shell',(.055,.075,.11),.3)
 # Remove the laser donor's full-length lower frame: the Enforcer gets a
 # compact trigger guard and a bored ballistic muzzle in its place.
 if key=='ut99_2':
  ob=parts[0];bm=bmesh.new();bm.from_mesh(ob.data)
  bmesh.ops.delete(bm,geom=[f for f in bm.faces if all(v.co.y>.34 and v.co.z<-.015 for v in f.verts)],context='FACES');bm.to_mesh(ob.data);bm.free()
  for slot in ob.material_slots:
   n=slot.material.name.lower();slot.material=rubber if 'rubber' in n else steel if any(s in n for s in ['brown','wire','glass']) else alloy
 if key=='ut99_3':
  ob=parts[0];bm=bmesh.new();bm.from_mesh(ob.data)
  # The oversized optic and side-mounted loose battery are unnecessary on a
  # shock rifle. Keep the vented receiver, handle and linear accelerator.
  bmesh.ops.delete(bm,geom=[f for f in bm.faces if all(v.co.z>.086 for v in f.verts) or all(v.co.x>-.012 for v in f.verts)],context='FACES');bm.to_mesh(ob.data);bm.free()
  # Shorten the rear counterweight while leaving the original grip/fore-end.
  for v in ob.data.vertices:
   if v.co.y<.25:v.co.y=.25+(.25-v.co.y)*-.50
  for slot in ob.material_slots:
   n=slot.material.name.lower();slot.material=blue if 'yellow' in n else rubber if 'bandage' in n else steel if 'grey' in n else alloy
 if key in ['doom_7','doom_8']:
  for ob in parts:
   ob.data.materials.clear()
   for m in [alloy if key=='doom_8' else copper,steel,rubber]:ob.data.materials.append(m)
   for p in ob.data.polygons:p.material_index=2 if p.center.z<-.025 else 1 if key!='doom_8' and p.center.y<.49 else 0
   ob.name='CapacitorMagazine' if 'Clip' in ob.name else 'EnergyReceiver'
   if ob.name=='CapacitorMagazine':ob['motion']='slide';ob['amount']=[0,-.022,0]
 for ob in parts:
  for v in ob.data.vertices:
   q=v.co-palm
   v.co=Vector((q.x*sx,q.y*sy,q.z*sz))+grip
   # A small longitudinal correction fits both landmarks without relocating
   # the palm. The saw blade remains on the existing melee sweep plane.
   predicted=grip.z+(tip.z-palm.z)*sz
   v.co.z+=(muzzle.z-predicted)*q.y/(tip.y-palm.y)
  if key=='doom_2' and ob.name=='Pistol_toppart':ob.name='Slide';ob['motion']='slide';ob['amount']=[0,0,.035]
  if key=='doom_2' and ob.name=='pistol_idkthenameofthispart':ob.name='Hammer';ob['motion']='hinge';ob['amount']=[.10,0,0]
  if key=='doom_8' and ob.name=='EnergyReceiver':
   for v in ob.data.vertices:
    if v.co.z>grip.z+.105:
     v.co.z=muzzle.z+(v.co.z-muzzle.z)*1.8
 z=muzzle.z;end=muzzle.y
 def profile(name,outline,width,material):
  ob=side_profile(name,outline,width,material);parts.append(ob);return ob
 if key=='ut99_2':
  parts[0].name='EnforcerReceiver'
  profile('CompactTriggerGuard',[(grip.y+.045,grip.z+.09),(grip.y+.17,grip.z+.09),(grip.y+.18,grip.z-.008),(grip.y+.035,grip.z-.017),(grip.y+.035,grip.z),(grip.y+.16,grip.z+.009),(grip.y+.153,grip.z+.073),(grip.y+.045,grip.z+.073)],.019,steel)
  parts.append(lathe('EnforcerBore',[(end-.025,.036),(end+.004,.036),(end+.004,.023),(end-.025,.023)],(0,z),steel,24))
 if key in ['doom_7','doom_8']:
  # Related receiver language, distinct plasma heat sink / BFG emitter.
  r=.067 if key=='doom_7' else .13
  parts.append(lathe('EmitterCollar',[(end-.075,r),(end-.015,r),(end,r*.9),(end,r*.62),(end-.075,r*.62)],(0,z),steel,32))
  lens=lathe('EnergyLens',[(end-.019,r*.59),(end-.014,r*.59),(end-.014,.001),(end-.019,.001)],(0,z),alloy,24);lens['lamp']=[.13,.58,1] if key=='doom_7' else [.2,.85,.12];parts.append(lens)
  for i in range(6):
   y=end-.13-i*.029
   parts.append(lathe('CoolingRib',[(y,r*.99),(y+.01,r*1.07),(y+.016,r*.99),(y+.016,r*.89),(y,r*.89)],(0,z),copper if key=='doom_7' else steel,24))
  if key=='doom_8':
   profile('BFGCarryHandle',[(grip.y-.07,z+.085),(grip.y-.055,z+.26),(grip.y+.32,z+.26),(grip.y+.36,z+.08),(grip.y+.328,z+.075),(grip.y+.29,z+.221),(grip.y-.021,z+.221),(grip.y-.033,z+.08)],.055,steel)
 return parts
