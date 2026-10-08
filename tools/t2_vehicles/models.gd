extends SceneTree
## Independent low-poly T2 silhouettes, built from original geometry.
const OUT="res://deathmatch/vehicles/tribes/"
var batches: Dictionary={}
var materials: Dictionary={}
func _initialize():
 var atlas:=Image.new();assert(atlas.load_png_from_buffer(FileAccess.get_file_as_bytes(OUT+"hull-atlas.png"))==OK);atlas.generate_mipmaps()
 var texture:=ImageTexture.create_from_image(atlas)
 for pair in [["Hull","Bronze"],["Trim","Gunmetal"],["Dark","Recess"],["TeamPanel","TeamPanel"],["Glow","Engine"]]:
  var m:=StandardMaterial3D.new();m.resource_name="TribesOriginal_"+pair[1]
  m.roughness=.67;m.metallic=.25;m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
  m.albedo_color=Color("923a2f") if pair[0]=="TeamPanel" else Color.WHITE
  if pair[0]=="Glow":
   m.albedo_color=Color(.04,.42,.65);m.emission_enabled=true;m.emission=m.albedo_color;m.emission_energy_multiplier=1.3
  else:m.albedo_texture=texture
  materials[pair[0]]=m
 for kind in ["wildcat","shrike","havoc","beowulf","thundersword","jericho"]:build(kind)
 quit()
func triangle(a: Vector3,b: Vector3,c: Vector3,mat: String,uvs: Array):
 if not batches.has(mat):
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_material(materials[mat]);batches[mat]=st
 var n: Vector3=(b-a).cross(c-a).normalized();var points:=[a,b,c]
 for index in [0,2,1]:
  batches[mat].set_normal(n);batches[mat].set_uv(uvs[index]);batches[mat].add_vertex(points[index])
func convex(points: Array,faces: Array,mat: String):
 var center:=Vector3.ZERO
 for p in points:center+=p/points.size()
 var row: int={"Hull":0,"Trim":1,"Dark":2,"TeamPanel":3,"Glow":0}[mat]
 for face_index in faces.size():
  var face: Array=faces[face_index].duplicate();var a: Vector3=points[face[0]]
  var normal: Vector3=(points[face[1]]-a).cross(points[face[2]]-a)
  var middle:=Vector3.ZERO
  for index in face:middle+=points[index]/face.size()
  if normal.dot(middle-center)<0:face.reverse();normal=-normal
  var drop:=normal.abs().max_axis_index();var axes: Array=[]
  for axis in 3:
   if axis!=drop:axes.append(axis)
  var lo:=Vector2(INF,INF);var hi:=Vector2(-INF,-INF)
  for index in face:
   var value:=Vector2(points[index][axes[0]],points[index][axes[1]]);lo=lo.min(value);hi=hi.max(value)
  var span: Vector2=(hi-lo).max(Vector2(.001,.001));var aspect: float=maxf(span.x,span.y)/minf(span.x,span.y)
  # Match the existing ST atlas: plain narrow trim; seams, hatches and vents
  # on broad faces. Map each polygon once so triangles share continuous UVs.
  var tile:=0
  if span.x*span.y>.12 and aspect<7:
   tile=3 if mat=="Dark" else 2 if aspect<1.9 and face_index%3==0 else 1
  var uv: Dictionary={}
  for index in face:
   var value: Vector2=(Vector2(points[index][axes[0]],points[index][axes[1]])-lo)/span
   uv[index]=(Vector2(tile,row)+Vector2.ONE*.035+value*.93)/4.
  for i in range(1,face.size()-1):triangle(points[face[0]],points[face[i]],points[face[i+1]],mat,[uv[face[0]],uv[face[i]],uv[face[i+1]]])
func box(p: Vector3,size: Vector3,mat: String):
 var pts: Array=[]
 for y in [-1.,1.]:
  for xz in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:pts.append(p+Vector3(xz.x*size.x,y*size.y,xz.y*size.z)*.5)
 convex(pts,[[0,1,2,3],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]],mat)
func hull(rings: Array,mat: String):
 # Octagonal cross sections [z, half-width, bottom, top].
 var pts: Array=[]
 for ring in rings:
  var z: float=ring[0];var w: float=ring[1];var lo: float=ring[2];var hi: float=ring[3];var bevel: float=(hi-lo)*.25
  pts.append_array([Vector3(-w*.65,lo,z),Vector3(w*.65,lo,z),Vector3(w,lo+bevel,z),Vector3(w,hi-bevel,z),Vector3(w*.65,hi,z),Vector3(-w*.65,hi,z),Vector3(-w,hi-bevel,z),Vector3(-w,lo+bevel,z)])
 var faces: Array=[[0,1,2,3,4,5,6,7]];var end: Array=[]
 for i in 8:end.append((rings.size()-1)*8+i)
 faces.append(end)
 for r in rings.size()-1:
  for i in 8:faces.append([r*8+i,r*8+(i+1)%8,(r+1)*8+(i+1)%8,(r+1)*8+i])
 convex(pts,faces,mat)
func wing(side: float,front: float,back: float,width: float,y: float):
 convex([Vector3(side*.75,y,front),Vector3(side*width,y,back-.4),Vector3(side*width,y+.15,back+.55),Vector3(side*.75,y+.2,back+.3),Vector3(side*.75,y-.16,front),Vector3(side*width,y-.12,back-.4),Vector3(side*width,y-.02,back+.55),Vector3(side*.75,y-.1,back+.3)],[[0,1,2,3],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]],"Hull")
func cockpit(z: float,y: float):
 box(Vector3(0,y-.05,z+.12),Vector3(.68,.12,.85),"Dark")
 box(Vector3(0,y+.35,z+.52),Vector3(.72,.75,.15),"Dark")
 box(Vector3(0,y+.42,z-.75),Vector3(.70,.12,.38),"Trim")
 box(Vector3(0,y+.50,z-.76),Vector3(.38,.025,.18),"Glow")
 for side in [-1.,1.]:box(Vector3(side*.30,y+.30,z-.45),Vector3(.055,.36,.055),"Dark")
func pod(p: Vector3,size: Vector3):
 box(p,size,"Hull");box(p+Vector3(0,0,size.z*.51),Vector3(size.x*.7,size.y*.65,.10),"Dark")
 box(p+Vector3(0,0,size.z*.54),Vector3(size.x*.5,size.y*.45,.06),"Glow")
 for i in 4:box(p+Vector3(0,size.y*.51,-size.z*.3+i*size.z*.19),Vector3(size.x*.72,.045,.07),"Dark")
func build(kind: String):
 batches.clear()
 if kind=="wildcat":
  hull([[-1.8,.35,-.4,.05],[-1.2,.72,-.45,.45],[-.2,.65,-.40,.4],[.9,.45,-.30,.5],[1.65,.5,-.2,1.25]],"Hull")
  hull([[-1.6,.16,.05,.28],[-.9,.32,.25,.62],[-.35,.3,.4,.75]],"Trim")
  cockpit(.20,.62)
  for side in [-1.,1.]:
   pod(Vector3(side*.67,-.15,1.1),Vector3(.48,.46,1.0))
   box(Vector3(side*.69,.05,-.8),Vector3(.05,.22,.52),"TeamPanel")
   box(Vector3(side*.38,-.2,-1.48),Vector3(.24,.16,.08),"Glow")
  box(Vector3(0,1.2,1.55),Vector3(.58,.22,.25),"Trim")
 elif kind=="shrike":
  hull([[-3.3,.26,-.3,.12],[-2.6,.72,-.5,.48],[-1.,.87,-.4,.62],[1.2,.8,-.25,.6],[2.9,.48,-.15,1.05],[3.2,.22,.1,.9]],"Hull")
  hull([[-2.9,.21,.18,.34],[-1.4,.54,.4,.82],[-.7,.58,.45,.9]],"Trim")
  cockpit(.5,.48)
  for side in [-1.,1.]:
   wing(side,-1.6,1.7,2.,-.15)
   pod(Vector3(side*1.55,-.20,1.9),Vector3(.62,.7,1.7))
   box(Vector3(side*1.25,-.08,-2.65),Vector3(.20,.20,1.5),"Dark")
   box(Vector3(side*1.25,-.08,-3.42),Vector3(.13,.13,.06),"Glow")
   box(Vector3(side*.83,.12,-.35),Vector3(.055,.25,1.1),"TeamPanel")
   box(Vector3(side*1.58,-.50,2.50),Vector3(.60,.10,.8),"Trim")
 elif kind=="havoc":
  hull([[-4.35,.8,-.45,.55],[-3.4,1.6,-.5,.9],[-2.,2.1,-.5,.65],[2.6,2.15,-.55,.70],[4.1,1.55,-.35,1.35]],"Hull")
  # Open side bays leave every passenger's weapon and exit route clear.
  box(Vector3(0,.87,1.0),Vector3(4.25,.22,4.7),"Dark")
  cockpit(-2.65,1.03)
  for side in [-1.,1.]:
   for z in [-1.7,2.9]:
    pod(Vector3(side*2.48,.12,z),Vector3(1.0,1.25,1.8))
    box(Vector3(side*2.48,-.60,z+.35),Vector3(1.05,.16,1.4),"Trim")
   for z in [-.4,1.6]:
    box(Vector3(side*1.6,.98,z),Vector3(.8,.06,.85),"Trim")
    box(Vector3(side*2.05,1.30,z),Vector3(.10,.55,.5),"TeamPanel")
   box(Vector3(side*1.6,.60,-3.05),Vector3(.12,.48,1.2),"TeamPanel")
  box(Vector3(0,1.,2.9),Vector3(.8,.08,.8),"Trim")
  box(Vector3(0,1.75,3.8),Vector3(.9,1.,.7),"Hull")
 elif kind=="beowulf":
  hull([[-3.5,.7,-.6,.1],[-2.5,1.8,-.85,.65],[2.8,1.8,-.85,.55],[3.5,1.1,-.45,.65]],"Hull")
  cockpit(-1.6,1.0)
  hull([[-.7,.75,.6,1.7],[1.1,1.15,.6,1.9],[2.0,.65,.65,1.4]],"Trim")
  box(Vector3(0,2.05,-1.6),Vector3(.38,.36,4.8),"Dark")
  box(Vector3(0,2.05,-4.03),Vector3(.52,.5,.25),"Trim")
  box(Vector3(0,2.05,-4.17),Vector3(.27,.27,.04),"Glow")
  box(Vector3(0,1.47,.9),Vector3(.7,.08,.7),"Dark")
  for side in [-1.,1.]:
   pod(Vector3(side*2.0,-.25,.2),Vector3(1.0,1.1,5.6))
   box(Vector3(side*2.51,-.25,.2),Vector3(.09,.55,4.2),"Trim")
   box(Vector3(side*1.81,.48,-1.1),Vector3(.06,.4,1.2),"TeamPanel")
 elif kind=="thundersword":
  hull([[-4.3,.65,-.55,.35],[-3.1,1.5,-.65,1.0],[-1.2,1.7,-.9,.8],[2.6,1.65,-.7,.8],[4.3,.8,-.3,1.15]],"Hull")
  cockpit(-2.7,1.0);cockpit(-.4,.6)
  box(Vector3(0,-.97,.3),Vector3(2.0,.22,3.4),"Dark")
  for side in [-1.,1.]:
   wing(side,-2.5,1.8,3.0,-.1)
   pod(Vector3(side*2.45,.05,1.5),Vector3(1.05,1.35,3.6))
   box(Vector3(side*1.1,-1.15,.5),Vector3(.15,.15,3.4),"Trim")
   box(Vector3(side*1.52,.6,-2.4),Vector3(.09,.48,1.15),"TeamPanel")
   box(Vector3(side*.46,1.55,3.3),Vector3(.16,.16,1.7),"Dark")
   box(Vector3(side*.46,1.55,4.2),Vector3(.13,.13,.06),"Glow")
  box(Vector3(0,1.12,2.7),Vector3(.8,.12,.8),"Trim")
  box(Vector3(0,1.5,2.0),Vector3(.7,.7,.13),"Dark")
 elif kind=="jericho":
  hull([[-4.2,1.25,-.8,.8],[-3.0,2.0,-.9,1.25],[3.4,2.0,-.9,1.25],[4.2,1.4,-.6,.8]],"Hull")
  cockpit(-2.7,1.2)
  box(Vector3(0,.85,.7),Vector3(3.5,1.6,3.3),"Hull")
  box(Vector3(0,1.72,.6),Vector3(1.5,.25,1.8),"Trim")
  box(Vector3(0,2.08,.6),Vector3(.9,.5,.9),"Dark")
  box(Vector3(0,2.5,-.5),Vector3(.22,.22,2.8),"Trim")
  box(Vector3(0,2.5,-1.94),Vector3(.16,.16,.07),"Glow")
  # Six faceted wheels distinguish the wheeled mobile base from grav craft.
  for side in [-1.,1.]:
   for z in [-2.6,0,2.6]:
    var pts: Array=[]
    for x in [side*1.9,side*2.48]:
     for i in 12:
      var angle:=TAU*i/12.;pts.append(Vector3(x,-.48+sin(angle)*.73,z+cos(angle)*.73))
    var faces: Array=[range(12),range(12,24)]
    for i in 12:faces.append([i,(i+1)%12,(i+1)%12+12,i+12])
    convex(pts,faces,"Dark")
    box(Vector3(side*2.49,-.48,z),Vector3(.045,.5,.5),"Trim")
   box(Vector3(side*2.02,.76,.8),Vector3(.07,.65,2.0),"TeamPanel")
   box(Vector3(side*1.6,-.48,3.7),Vector3(.55,.8,.55),"Trim")
  box(Vector3(0,.9,3.5),Vector3(1.15,1.1,.18),"Dark")
  box(Vector3(0,1.0,3.61),Vector3(.85,.55,.05),"Glow")
  box(Vector3(0,.15,4.05),Vector3(1.9,.18,.75),"Trim")

 var root:=Node3D.new();root.name=kind.capitalize();var mesh:=ArrayMesh.new()
 for st in batches.values():st.index();st.commit(mesh)
 var visual:=MeshInstance3D.new();visual.mesh=mesh;root.add_child(visual);visual.owner=root
 var packed:=PackedScene.new();assert(packed.pack(root)==OK)
 assert(ResourceSaver.save(packed,OUT+kind+".scn",ResourceSaver.FLAG_COMPRESS)==OK)
 root.free()
 var icon:=Image.new();assert(icon.load_svg_from_string(FileAccess.get_file_as_string("res://deathmatch/ui/weapon_icons/st_"+kind+".svg"))==OK);icon.generate_mipmaps()
 assert(ResourceSaver.save(ImageTexture.create_from_image(icon),OUT+kind+"-icon.res",ResourceSaver.FLAG_COMPRESS)==OK)
 print("T2_MODEL ",kind," surfaces=",mesh.get_surface_count())
