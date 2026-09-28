"""Execute through Blender MCP. Original CC0 geometry; CS workbench conventions reused.
Godot +Y up / -Z forward. Grip at origin; never replace other authoring scenes.
"""
import bpy,bmesh,math,json
from pathlib import Path
from mathutils import Vector,Quaternion
ROOT=Path('/home/blux/Documents/FPSloppa');OUT=ROOT/'tools/tribes/refined'
NAMES=['blaster','plasma','chaingun','disc','grenade_launcher','laser','elf','mortar','repair','grenade','mine','targeter','energy_pack','ammo_pack','repair_pack','shield_pack','jammer_pack']
scene=bpy.data.scenes.get('Tribes Arsenal') or bpy.data.scenes.new('Tribes Arsenal');bpy.context.window.scene=scene
for ob in list(scene.objects):bpy.data.objects.remove(ob,do_unlink=True)
image=bpy.data.images.load(str(OUT/'finish.png'),check_existing=True)
colors=['536461','273137','927d50','9fa9a6','161d22','37b9d3','dea844','ab4437'];mats=[]
for i,c in enumerate(colors):
 mat=bpy.data.materials.new('Tribes '+str(i));mat.diffuse_color=tuple(int(c[j:j+2],16)/255 for j in (0,2,4))+(1,);mat.use_nodes=True
 p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Metallic'].default_value=.6 if i<4 else .15;p.inputs['Roughness'].default_value=.55
 tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;mat.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
 if i in [5,6]:p.inputs['Emission Color'].default_value=mat.diffuse_color;p.inputs['Emission Strength'].default_value=.6
 mats.append(mat)
parts=[]
def xyz(v):return (v[0],-v[2],v[1])
def mesh(name,verts,faces,mat=0,bevel=.005):
 data=bpy.data.meshes.new(name);data.from_pydata([xyz(v) for v in verts],[],faces);data.update()
 bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 if bevel:bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=2)
 bm.to_mesh(data);bm.free();ob=bpy.data.objects.new(name,data);scene.collection.objects.link(ob);data.materials.append(mats[mat])
 uv=data.uv_layers.new(name='Finish')
 for poly in data.polygons:
  norm=poly.normal;axis=max(range(3),key=lambda k:abs(norm[k]));axes=[k for k in range(3) if k!=axis]
  for li in poly.loop_indices:
   v=data.vertices[data.loops[li].vertex_index].co;u=(float(v[axes[0]])*1.3+.5)%1;w=(float(v[axes[1]])*1.3+.5)%1
   uv.data[li].uv=((mat%4+(16+224*u)/256)/4,(1-mat//4+(16+224*w)/256)/2)
 parts.append(ob);return ob
def box(name,pos,size,mat=0):
 x,y,z=pos;a,b,c=[s/2 for s in size]
 return mesh(name,[(x+dx*a,y+dy*b,z+dz*c) for dx,dy,dz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat)
def profile(name,outline,width,mat=0):
 n=len(outline);return mesh(name,[(s*width/2,y,z) for s in [-1,1] for z,y in outline],[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],mat)
def tube(name,pos,radius,length,mat=1,axis='z',bore=.0):
 n=16;vs=[];fs=[];x,y,z=pos
 for along,r in [(-length/2,radius),(length/2,radius),(-length/2,bore),(length/2,bore)]:
  for i in range(n):
   a=2*math.pi*i/n;u=math.cos(a)*r;v=math.sin(a)*r;vs.append((x+u,y+v,z+along) if axis=='z' else (x+u,y+along,z+v) if axis=='y' else (x+along,y+u,z+v))
 for i in range(n):
  j=(i+1)%n
  fs.extend([(i,j,n+j,n+i),(2*n+j,2*n+i,3*n+i,3*n+j),(i,2*n+i,2*n+j,j),(n+j,3*n+j,3*n+i,n+i)])
 return mesh(name,vs,fs,mat,.001)
def common(length,width=.19):
 profile('Angled grip',[(.07,.08),(-.035,.08),(-.005,-.15),(.075,-.15),(.12,-.07)],.09,4)
 box('Palm saddle',(0,.05,.01),(.12,.06,.14),1)
 # Connected closed guard, with finger clearance under the forward receiver.
 for pos,size in [((0,-.08,-.075),(.042,.025,.16)),((0,-.03,-.15),(.042,.125,.025))]:box('Trigger guard',pos,size,1)
 box('Trigger',(0,-.035,-.045),(.014,.055,.015),3)
 profile('Receiver',[(.15,.05),(-length*.65,.05),(-length*.75,.14),(-length*.65,.24),(.10,.24),(.19,.16)],width)
 box('Forehand pad',(0,.035,-.25),(.12,.055,.19),4)
 for side in [-1,1]:
  box('Service plate',(side*(width/2+.003),.145,-.14),(.016,.1,.25),2)
  for z in [-.23,-.06]:tube('Recessed fastener',(side*(width/2+.013),.145,z),.010,.006,3,'x')
 box('Rear sight',(0,.27,.055),(.07,.03,.035),1);box('Front sight',(0,.27,-length*.65),(.023,.03,.035),3)
def weapon(i):
 length=[.48,.68,.78,.64,.72,1.12,.69,1.02,.6][i];common(length,.24 if i in [1,3,7] else .19)
 if i==0:
  for x in [-.053,.053]:tube('Blaster emitter',(x,.15,-.37),.047,.22,1,bore=.024);tube('Energy ring',(x,.15,-.405),.05,.025,5)
 elif i==1:
  tube('Plasma chamber',(0,.16,-.42),.13,.37,2,bore=.073)
  for x in [-.15,.15]:
   tube('Plasma reservoir',(x,.17,-.25),.043,.35,1);tube('Reservoir glow',(x,.17,-.36),.045,.04,6)
  for z in [-.4,-.48,-.56]:tube('Cooling collar',(0,.16,z),.145,.025,1,bore=.125)
 elif i==2:
  tube('Barrel motor',(0,.16,-.34),.145,.15,1)
  for n in range(6):
   a=n*math.pi/3;tube('Rotary barrel',(math.cos(a)*.078,.16+math.sin(a)*.078,-.57),.03,.44,3,bore=.017)
  for z in [-.39,-.68]:tube('Barrel cage',(0,.16,z),.127,.04,1,bore=.103)
  tube('Ammo drum',(0,.12,.1),.17,.22,2,'x');box('Feed bridge',(0,.13,-.035),(.2,.12,.17),1)
 elif i==3:
  tube('Disc housing',(0,.18,-.36),.27,.13,1,'y',.04);tube('Disc top armour',(0,.254,-.36),.245,.024,0,'y',.065)
  tube('Magnetic rim',(0,.178,-.36),.275,.024,5,'y',.25)
  box('Disc exit',(0,.158,-.555),(.33,.067,.20),1);box('Exit slit',(0,.16,-.66),(.285,.018,.015),5)
 elif i==4:
  tube('Launcher barrel',(0,.17,-.48),.105,.43,0,bore=.077);tube('Muzzle shroud',(0,.17,-.67),.115,.065,2,bore=.078)
  tube('Rotary breech',(0,.13,-.22),.155,.19,1,'x')
  for z in [-.41,-.49,-.57]:box('Barrel vent',(0,.281,z),(.09,.012,.04),4)
 elif i==5:
  tube('Laser barrel',(0,.17,-.69),.045,.75,3,bore=.018)
  for z in [-.41,-.5,-.59]:tube('Focusing ring',(0,.17,z),.072,.035,1,bore=.039)
  box('Optic mounts',(0,.26,-.14),(.075,.11,.3),1);tube('Scope',(0,.33,-.15),.052,.36,1,bore=.035)
  tube('Objective',(0,.33,-.338),.04,.012,5);profile('Stock',[(.14,.2),(.39,.18),(.40,-.09),(.29,-.09),(.17,.07)],.095,4)
 elif i==6:
  for x in [-.1,.1]:
   box('ELF rail',(x,.16,-.43),(.075,.1,.42),1);tube('Field coil',(x,.16,-.47),.061,.14,5);box('Emitter tip',(x,.16,-.655),(.055,.075,.05),3)
  box('Capacitor',(0,.18,-.25),(.12,.18,.25),2)
 elif i==7:
  tube('Mortar barrel',(0,.24,-.48),.19,.93,0,bore=.143)
  for z in [-.14,-.48,-.87]:tube('Mortar reinforcement',(0,.24,z),.21,.055,2,bore=.18)
  tube('Muzzle interior',(0,.24,-.935),.16,.02,4,bore=.142)
  for x in [-.235,.235]:box('Lifting rail',(x,.21,-.4),(.055,.055,.55),1)
 elif i==8:
  for x in [-.08,.08]:box('Repair probe',(x,.16,-.39),(.055,.075,.33),3);tube('Probe energy',(x,.16,-.53),.036,.03,5)
  tube('Repair canister',(0,.18,-.2),.115,.19,7,'x')
 return (0,.17 if i!=7 else .24,-length)
report={};anchors={}
for i,name in enumerate(NAMES):
 parts=[]
 if i<9:anchor=weapon(i)
 elif i in [9,10]:
  tube('Throwable body',(0,0,0),.072 if i==9 else .14,.15 if i==9 else .048,0,'y');tube('Activation cap',(0,.09 if i==9 else .032,0),.036,.025,7,'y');anchor=(0,0,-.1)
 elif i==11:common(.42);tube('Designator lens',(0,.17,-.35),.055,.20,1,bore=.025);anchor=(0,.17,-.46)
 else:
  box('Backpack chassis',(0,0,0),(.42,.50,.16),1);box('Backpack face',(0,0,.09),(.36,.42,.07),[0,2,7,3,0][i-12])
  for x in [-.20,.20]:tube('Pack side unit',(x,0,.07),.078,.40,1,'y');box('Pack strap',(x*.65,0,-.10),(.04,.52,.035),4)
  if i==12:
   for x in [-.1,.1]:tube('Energy cell',(x,0,.14),.059,.33,5,'y')
  if i==13:
   for y in [-.14,0,.14]:box('Ammo box',(0,y,.16),(.30,.11,.12),2)
  if i==14:box('Repair cross',(0,0,.14),(.20,.06,.012),3);box('Repair cross',(0,0,.14),(.06,.20,.012),3)
  if i==15:tube('Shield coil',(0,0,.155),.16,.02,5,bore=.13)
  if i==16:
   for x in [-.12,.12]:tube('Jammer antenna',(x,.36,0),.012,.4,3,'y')
  anchor=(0,0,0)
 for ob in scene.objects:ob.select_set(False)
 for ob in parts:ob.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();ob=parts[0];ob.name=name
 # Meshes are authored in model coordinates, keeping the handle anchor exact.
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),use_selection=True,use_active_scene=True,export_yup=True)
 report[name]={'vertices':len(ob.data.vertices),'triangles':sum(len(p.vertices)-2 for p in ob.data.polygons)};anchors[name]=anchor
 ob.location=(i%5*1.5,i//5*1.8,0)
(OUT/'mesh-report.json').write_text(json.dumps(report,indent=2));(OUT/'anchors.json').write_text(json.dumps(anchors,indent=2))
for a in bpy.context.screen.areas:
 if a.type=='VIEW_3D':
  a.spaces.active.region_3d.view_distance=10;a.spaces.active.region_3d.view_location=Vector((3,2.5,0));a.spaces.active.region_3d.view_rotation=Quaternion((.87,.35,.15,.25));a.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'tribes-arsenal.blend'),copy=True)
print(json.dumps(report))
