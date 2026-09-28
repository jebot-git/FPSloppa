"""Original CS-inspired meshes. Execute in Blender; only replaces CS16_Workbench.
Godot coordinates are in Art units, with explicit palm anchors and bore facing -Z.
No retail Counter-Strike assets. Shared finish is original procedural game art.
"""
import bpy, bmesh, math, json, struct
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tools/cs16/refined'; OUT.mkdir(parents=True,exist_ok=True)
NAMES=['knife','glock','usp','m3','xm1014','mp5','ak47','m4a1','m249','awp','deagle','p90']
LENGTHS=[.40,.32,.36,.95,.90,.63,.92,.86,1.02,1.12,.40,.58]
COL='CS16_Workbench'
if COL in bpy.data.collections:
 for ob in list(bpy.data.collections[COL].objects):bpy.data.objects.remove(ob,do_unlink=True)
 bpy.data.collections.remove(bpy.data.collections[COL])
collection=bpy.data.collections.new(COL);bpy.context.scene.collection.children.link(collection)
exec(compile((ROOT/'tools/cs16/surface_finish.py').read_text(),str(ROOT/'tools/cs16/surface_finish.py'),'exec'),globals())
exec(compile((ROOT/'tools/cs16/refine_profiles.py').read_text(),str(ROOT/'tools/cs16/refine_profiles.py'),'exec'),globals())
image=make_finish(bpy,OUT/'cs16-finish.png')
MATS=[]
for i,(name,color) in enumerate(zip(FINISH_NAMES,FINISH_COLORS)):
 mat=bpy.data.materials.new('CS16 '+name);mat.diffuse_color=tuple(c/255 for c in color)+(1,);mat.use_nodes=True
 nodes=mat.node_tree.nodes;p=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
 p.inputs['Metallic'].default_value=.30 if i in [0,4,5] else .0
 p.inputs['Roughness'].default_value=.72 if i in [0,1,2,3,6,7] else .48
 tex=nodes.new('ShaderNodeTexImage');tex.image=image
 mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color']);p.inputs['Base Color'].default_value=(1,1,1,1)
 MATS.append(mat)
PARTS=[]
def deselect_all():
 # The UI operator skips hidden review objects, but glTF's selected-object
 # export still includes them. Clear selection on the entire view layer.
 bpy.context.view_layer.update()
 for ob in bpy.context.view_layer.objects:
  if ob is not None:ob.select_set(False)
def xyz(v):return (v[0],-v[2],v[1])
def obj(name,vertices,faces,mat=0,bevel=.003):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([xyz(v) for v in vertices],[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 ob=bpy.data.objects.new(name,mesh);collection.objects.link(ob);mesh.materials.append(MATS[mat])
 deselect_all();ob.select_set(True);bpy.context.view_layer.objects.active=ob
 if bevel:
  mod=ob.modifiers.new('Forged edge bevel','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 for face in mesh.polygons:face.use_smooth=False
 normal=ob.modifiers.new('Face-weighted normals','WEIGHTED_NORMAL');normal.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=normal.name)
 apply_finish(ob)
 ob.select_set(False);PARTS.append(ob);return ob

def profile(name,outline,width,mat=0,x=0,bevel=.003):
 # outline coordinates (forward Z, height Y).
 n=len(outline);v=[(x+side*width/2,y,z) for side in [-1,1] for z,y in outline]
 f=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return obj(name,v,f,mat,bevel)
def block(name,p,s,mat=0,bevel=.003):
 x,y,z=p;w,h,l=s
 return profile(name,[(z-l/2,y-h/2),(z+l/2,y-h/2),(z+l/2,y+h/2),(z-l/2,y+h/2)],w,mat,x,bevel)
def tube(name,p,r,length,mat=0,inner=0,segments=12,axis='z'):
 x,y,z=p;v=[];rings=[(r,-length/2),(r,length/2),(inner,length/2),(inner,-length/2)]
 for rad,t in rings:
  for i in range(segments):
   a=i*math.tau/segments;u=rad*math.cos(a);w=rad*math.sin(a)
   v.append((x+u,y+w,z+t) if axis=='z' else (x+t,y+u,z+w) if axis=='x' else (x+u,y+t,z+w))
 faces=[]
 for k in range(4):
  for i in range(segments):faces.append((k*segments+i,k*segments+(i+1)%segments,((k+1)%4)*segments+(i+1)%segments,((k+1)%4)*segments+i))
 return obj(name,v,faces,mat,0)
def pin(z,y,width=.116):
 tube('Recessed receiver pin',(0,y,z),.009,width,4,0,10,'x')
def ring_profile(name,outer,inner,width,mat=0):
 # A true closed annulus, including the upper bridge; no C-shaped strips.
 n=len(outer);verts=[]
 for x in [-width/2,width/2]:
  for outline in [outer,inner]:verts.extend((x,y,z) for z,y in outline)
 faces=[]
 for i in range(n):
  j=(i+1)%n
  faces.extend([(i,j,2*n+j,2*n+i),(n+j,n+i,3*n+i,3*n+j),(i,n+i,n+j,j),(2*n+j,3*n+j,3*n+i,2*n+i)])
 return obj(name,verts,faces,mat,.001)
def guard(z=-.095):
 ring_profile('Closed trigger guard',[(-.036,.043),(-.145,.043),(-.169,.018),(-.169,-.036),(-.145,-.060),(-.052,-.060),(-.030,-.037),(-.030,.019)],[(-.052,.024),(-.137,.024),(-.153,.009),(-.153,-.030),(-.137,-.044),(-.060,-.044),(-.046,-.029),(-.046,.009)],.057)
 # The finger pad is concave toward the muzzle (-Z). The old bow opened
 # toward the grip; keep the upper attachment while reversing that curve.
 profile('Curved trigger',[(-.10,.032),(-.091,-.005),(-.101,-.032),(-.089,-.027),(-.080,-.001),(-.09,.032)],.012,4,bevel=.001)
def magazine(curved=False,small=False):
 if curved:
  outline=[(-.235,.035),(-.122,.03),(-.133,-.105),(-.176,-.241),(-.264,-.33),(-.35,-.283),(-.279,-.188),(-.247,-.091)]
 else:outline=[(-.251,.03),(-.141,.03),(-.117,-.20),(-.136,-.235),(-.224,-.235),(-.251,-.15)]
 if curved and not small:outline=[(z-.075,y) for z,y in outline]
 if small:outline=[(z*.72-.03,y*.87) for z,y in outline]
 profile('Curved box magazine' if curved else 'Box magazine',outline,.065 if not small else .052,0,bevel=.003)
 for side in [-1,1]:
  for offset in [0,.03,.06]:
   if curved:line=[(-.158-offset,-.04),(-.168-offset,-.112),(-.205-offset,-.219),(-.263-offset,-.276),(-.269-offset,-.269),(-.212-offset,-.212),(-.176-offset,-.108),(-.166-offset,-.04)]
   else:line=[(-.151-offset,-.05),(-.135-offset,-.201),(-.143-offset,-.201),(-.159-offset,-.05)]
   if curved and not small:line=[(z-.075,y) for z,y in line]
   if small:line=[(z*.72-.03,y*.87) for z,y in line]
   profile('Pressed magazine rib',line,.003,1,x=side*(.034 if not small else .028),bevel=0)
def mp5_magazine():
 start=len(PARTS)
 # Narrow 9 mm double-stack magazine: straight upper section, gentle lower arc.
 outline=[(-.224,.035),(-.157,.035),(-.160,-.105),(-.179,-.230),(-.209,-.270),(-.266,-.242),(-.240,-.209),(-.226,-.103)]
 profile('MP5 curved 9mm magazine',outline,.047,0,bevel=.002)
 for side in [-1,1]:
  profile('MP5 magazine pressed groove',[(-.182,-.045),(-.186,-.104),(-.206,-.217),(-.223,-.238),(-.230,-.234),(-.214,-.212),(-.194,-.103),(-.190,-.045)],.002,1,x=side*.024,bevel=0)
 profile('MP5 magazine floorplate',[(-.209,-.270),(-.266,-.242),(-.271,-.251),(-.212,-.280)],.052,1,bevel=.001)

 for ob in PARTS[start:]:
  for v in ob.data.vertices:v.co.y+=.038

def stanag_magazine():
 # 30-round STANAG: straight feed section seated inside an angled magwell,
 # with the lower body bending forward (towards -Z), never an AK-style arc.
 profile('M4 flared magazine well',[(-.314,.065),(-.170,.065),(-.167,-.039),(-.311,-.045)],.099,0,bevel=.003)
 outline=[(-.298,.016),(-.186,.016),(-.188,-.102),(-.217,-.247),(-.330,-.225),(-.302,-.099)]
 profile('STANAG 30-round magazine',outline,.061,4,bevel=.002)
 for side in [-1,1]:
  for offset in [0,.030,.060]:
   profile('STANAG pressed rib',[(-.205-offset,-.061),(-.207-offset,-.105),(-.232-offset,-.222),(-.240-offset,-.220),(-.215-offset,-.104),(-.213-offset,-.061)],.002,0,x=side*.032,bevel=0)
 profile('STANAG floorplate',[(-.217,-.247),(-.330,-.225),(-.333,-.238),(-.219,-.260)],.069,0,bevel=.001)

exec(compile((ROOT/'tools/cs16/weapon_shapes.py').read_text(),str(ROOT/'tools/cs16/weapon_shapes.py'),'exec'),globals())

def build(slot):
 global PARTS
 PARTS=[]
 if slot!=11:
  rebuild(slot);return PARTS
 # Integrated rounded chassis, two real through-holes, and a short muzzle.
 # Proportions checked against FN's standard P90 side photograph, 2026-09-26.
 outline=[(.22,.171),(-.024,.171),(-.034,.132),(-.50,.132),(-.505,.021),(-.487,.021),(-.48,.053),(-.460,.059),(-.442,.045),(-.427,.001),(-.402,-.030),(-.367,-.045),(-.302,-.045),(-.295,-.010),(-.283,.008),(-.262,.008),(-.237,-.013),(-.208,-.031),(-.148,-.047),(-.071,-.047),(.015,-.015),(.22,-.015)]
 chassis=profile('P90 closed trigger guard and thumbhole chassis',outline,.141,1,bevel=.007)
 openings=[[( -.15+.055*math.cos(i*math.tau/16),.050+.037*math.sin(i*math.tau/16)) for i in range(16)],[( -.353+.036*math.cos(i*math.tau/16),.054+.036*math.sin(i*math.tau/16)) for i in range(16)]]
 for k,opening in enumerate(openings):
  cutter=profile('Temporary opening cutter',opening,.25,1,bevel=0)
  bpy.context.view_layer.objects.active=chassis;chassis.select_set(True)
  cut=chassis.modifiers.new('Thumbhole' if k==0 else 'Trigger aperture','BOOLEAN');cut.operation='DIFFERENCE';cut.solver='EXACT';cut.object=cutter
  bpy.ops.object.modifier_apply(modifier=cut.name);PARTS.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
 edge=chassis.modifiers.new('Rounded aperture rims','BEVEL');edge.width=.003;edge.segments=2;bpy.ops.object.modifier_apply(modifier=edge.name)
 for face in chassis.data.polygons:face.use_smooth=abs(face.normal.x)<.99
 block('P90 recoil pad',(0,.078,.222),(.147,.192,.014),0,.005)
 profile('P90 stock inset',[(.208,.061),(.018,.061),(.010,-.006),(.208,-.006)],.145,1,bevel=.002)
 block('P90 horizontal magazine',(0,.153,-.224),(.113,.037,.402),7,.006)
 for j in range(18):
  # Cartridge rim details under an amber body, kept opaque for VR overdraw.
  tube('Magazine cartridge rims',(0,.154,-.037-j*.021),.006,.115,5,0,8,'x')
 block('P90 rear magazine latch',(0,.153,-.021),(.13,.042,.025),0,.003)
 profile('P90 rear optic pillar',[(-.233,.119),(-.277,.119),(-.302,.224),(-.270,.224)],.123,0,bevel=.003)
 profile('P90 front optic pillar',[(-.459,.124),(-.503,.124),(-.501,.229),(-.480,.239),(-.459,.218)],.128,0,bevel=.004)
 profile('P90 optic bridge',[(-.274,.205),(-.482,.205),(-.480,.241),(-.282,.241)],.123,0,bevel=.003)
 optic=block('P90 integrated sight housing',(0,.262,-.383),(.077,.065,.130),0,.004)
 cutter=block('Temporary optic channel',(0,.266,-.383),(.049,.034,.16),1,0)
 bpy.context.view_layer.objects.active=optic;optic.select_set(True)
 cut=optic.modifiers.new('See-through optic','BOOLEAN');cut.operation='DIFFERENCE';cut.solver='EXACT';cut.object=cutter
 bpy.ops.object.modifier_apply(modifier=cut.name);PARTS.remove(cutter);bpy.data.objects.remove(cutter,do_unlink=True)
 block('P90 aiming post',(0,.257,-.441),(.005,.018,.005),0,.0005)
 SIGHT_POINTS[11]=[(0,.266,-.318),(0,.266,-.441)]
 profile('P90 trigger',[(-.347,.098),(-.339,.051),(-.349,.033),(-.337,.027),(-.326,.049),(-.334,.098)],.029,0,bevel=.003)
 tube('P90 selector',(0,.014,-.33),.013,.069,0,0,12,'x')
 tube('P90 barrel',(0,.115,-.532),.021,.065,0,.013,16)
 tube('P90 muzzle',(0,.115,-.58),.027,.039,0,.013,16)
 for z,y in [(.185,.126),(.09,.130),(-.06,-.019),(-.244,.06),(-.38,-.011),(-.48,.072)]:tube('Chassis fastener',(0,y,z),.006,.143,4,0,8,'x')
 return PARTS

def mechanism_parts(slot):
 if slot in [7,8]:
  if slot==7:
   block('Charging handle shaft',(0,.142,.017),(.026,.016,.09),0,.001)
   block('Charging handle latch',(0,.142,.055),(.086,.019,.021),0,.002)
  else:
   block('Charging handle shaft',(.077,.078,-.29),(.08,.018,.025),0,.002)
   tube('Charging handle knob',(.114,.078,-.29),.013,.035,1,0,10)
 if slot==6:
  block('Reciprocating bolt handle',(.084,.106,-.19),(.063,.020,.028),0,.002)
 if slot==11:
  for side in [-1,1]:block('Charging handle P90',(side*.077,.106,-.438),(.035,.025,.067),0,.002)
  block('Bottom ejection bolt',(0,.015,.06),(.055,.014,.058),4,.001)

def role(ob,slot):
 name=ob.name.split('.')[0]
 if slot==8 and name in ['Feed belt links','Linked cartridges']:return 'FeedBelt'
 mags={1:['Pistol magazine','Magazine floorplate'],2:['Pistol magazine','Magazine floorplate'],10:['Pistol magazine','Magazine floorplate'],5:['MP5 curved 9mm magazine','MP5 magazine pressed groove','MP5 magazine floorplate'],6:['Curved box magazine','Pressed magazine rib'],7:['STANAG 30-round magazine','STANAG pressed rib','STANAG floorplate'],8:['Ammunition box','Ammunition box lid','Ammo box strengthening rib','Linked cartridges'],9:['AWP magazine','AW magazine rib'],11:['P90 horizontal magazine','Magazine cartridge rims']}
 if name in mags.get(slot,[]):return 'Magazine'
 if slot==8 and name in ['M249 feed cover','Rear sight pedestal','Rear sight aperture','Rear sight protector']:return 'FeedCover'
 if slot in [1,2,10] and name in ['Faceted slide','Slide serrations','Ejection cutout','Rear sight','Rear sight base']:return 'Slide'
 if slot in [1,2] and name in ['Front sight post','Front sight pedestal']:return 'Slide'
 if slot==3 and name in ['Contoured fore-end','Fore-end cooling slots','Pump ribs']:return 'Pump'
 if slot in [3,4,9] and name in ['Bolt','Bolt handle','Bolt knob']:return 'Bolt'
 if name in ['Bolt face','Reciprocating bolt handle','Bottom ejection bolt']:return 'Bolt'
 if 'Charging handle' in name or slot==5 and name=='Cocking handle':return 'ChargingHandle'
 return 'Body'

def bounds(ob):
 points=[ob.matrix_world@Vector(p) for p in ob.bound_box]
 return ([min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)])
def connected_report(objects):
 bpy.context.view_layer.update();boxes=[bounds(ob) for ob in objects];linked={0};eps=.003
 def overlaps(a,b):return all(a[0][i]<=b[1][i]+eps and b[0][i]<=a[1][i]+eps for i in range(3))
 while True:
  added={j for j,b in enumerate(boxes) if j not in linked and any(overlaps(boxes[i],b) for i in linked)}
  if not added:break
  linked.update(added)
 return [objects[i].name for i in range(len(objects)) if i not in linked]

def join_named(objects,name,pivot=(0,0,0)):
 deselect_all()
 for ob in objects:ob.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 if len(objects)>1:bpy.ops.object.join()
 result=bpy.context.object;result.name=name
 bpy.context.scene.cursor.location=xyz(pivot);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');return result

def export(slot):
 build(slot);mechanism_parts(slot);objects=PARTS.copy();profile_changes=refine_profiles(objects,slot)
 for ob in objects:apply_finish(ob)
 disconnected=connected_report(objects)
 guard=next((o for o in objects if 'closed trigger guard' in o.name.lower()),None)
 guard_closed=True
 if guard:
  bm=bmesh.new();bm.from_mesh(guard.data);guard_closed=all(e.is_manifold for e in bm.edges);bm.free()
 magazine_names={5:'MP5 curved 9mm magazine',6:'Curved box magazine',7:'STANAG 30-round magazine',8:'Ammunition box',9:'AWP magazine'}
 mag=next((o for o in objects if o.name.split('.')[0]==magazine_names.get(slot,'')),None)
 clearance=min(-v.co.y for v in guard.data.vertices)-max(-v.co.y for v in mag.data.vertices) if mag and guard else None
 assert not disconnected,(NAMES[slot],disconnected)
 assert guard_closed,NAMES[slot]+' has an open guard mesh'
 assert clearance is None or clearance>.010,(NAMES[slot],clearance)
 groups={}
 for ob in objects:groups.setdefault(role(ob,slot),[]).append(ob)
 objects=[join_named(obs,NAMES[slot]+'_'+key,(0,.085,-.14) if slot==9 and key=='Bolt' else (0,.145,-.424) if key=='FeedCover' else (0,0,0)) for key,obs in groups.items()]
 if slot in [2,7]:
  PARTS.clear();tube('Suppressor shell',(0,.113 if slot==2 else .085,-LENGTHS[slot]-.101),.032,.20,1,.014,16)
  for z in [-LENGTHS[slot]-.014,-LENGTHS[slot]-.18]:tube('Suppressor collar',(0,.113 if slot==2 else .085,z),.034,.012,0,.014,16)
  objects.append(join_named(PARTS,NAMES[slot]+'_Suppressor'))
 for key,position in zip(['SightRear','SightFront'],SIGHT_POINTS.get(slot,[])):
  marker=bpy.data.objects.new(NAMES[slot]+'_'+key,None);collection.objects.link(marker);marker.location=xyz(position);objects.append(marker)
 deselect_all()
 for ob in objects:ob.select_set(True);ob['weapon']=NAMES[slot];ob['component']=ob.name.split('.')[0]
 bpy.ops.export_scene.gltf(filepath=str(OUT/(NAMES[slot]+'.glb')),use_selection=True,use_active_scene=True,export_yup=True)
 for ob in objects:ob.hide_set(True)
 return {'slot':slot,'name':NAMES[slot],'triangles':sum(len(o.data.loop_triangles) for o in objects if o.type=='MESH'),'parts':len(groups),'profile_changes':profile_changes,'sights':SIGHT_POINTS.get(slot,[]),'disconnected_bounds':disconnected,'closed_guard_manifold':guard_closed,'magazine_guard_clearance':clearance,'grip_style':'integrated thumbhole' if slot in [9,11] else 'contoured pistol' if slot else 'straight knife'}

def main():
 report=[export(i) for i in range(12)]
 (OUT/'mesh-report.json').write_text(json.dumps(report,indent=2))
 # Transform each complete weapon around a common origin. In particular, the
 # AWP bolt has its own animation pivot and must not be rotated in isolation.
 for slot,name in enumerate(NAMES):
  assembly=bpy.data.objects.new(name+'_Assembly',None);collection.objects.link(assembly)
  for ob in list(collection.objects):
   if ob.get('weapon')==name:ob.hide_set(False);ob.parent=assembly
  assembly.rotation_euler.z=-math.pi/2;assembly.location=((slot%4)*1.8,0,(2-slot//4)*.75)
 for ob in bpy.context.scene.objects:
  if ob not in list(collection.objects):ob.hide_set(True)
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cs16_arsenal.blend'))
 print('CS16_BUILD_OK',json.dumps(report))
if __name__=='__main__':main()
