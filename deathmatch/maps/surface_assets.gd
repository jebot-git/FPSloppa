extends RefCounted
## Import-time data only. No new textures for wear; no extra material surfaces.
const VERSION=2
const Mips=preload("res://deathmatch/maps/colour_mips.gd")
const FRAME_TAG="map_texture_frames"
const VARY_TAG="map_surface_variation"
const STONE={
 "tf_pressureworks":["med_cobstn1_2","med_cobstn1_2a","med_rock5","med_rock5_g1","ind_brk01_brwn","ind_brk02_gry1","ind_brk01_gry1"],
 "tf_vesper":["med_dbrick6","grk_ebrick23","stn_gr02_gry1","stn_gw02_gry1","med_cobstn1_2a","stn_gc01_gry1","stn_gs01_gry1","stn_gt01_gry1","stn_gc02_gry1"]
}
static func sequence(name: String) -> String:
 if name.length()<3 or name[0]!="+":return ""
 if name[1] in "0123456789":return "0"+name.substr(2)
 if name[1] in "abcdefghij":return "a"+name.substr(2)
 return ""
static func capture(root: Node,textures: Array) -> void:
 var groups: Dictionary={}
 for item in textures:
  if not item or not item.material is BaseMaterial3D:continue
  var name: String=item.source_name
  var key:=sequence(name)
  if key.is_empty():continue
  if not groups.has(key):groups[key]={}
  groups[key][name[1]]=item.material
 var bank: Dictionary={}
 for key in groups:
  var letters: String="0123456789" if key[0]=="0" else "abcdefghij"
  var source: Dictionary=groups[key]
  var frames: Array=[];var valid:=true;var size:=Vector2.ZERO
  # Missing frames invalidate the whole sequence; alternate states stay separate.
  for i in source.size():
   if i>=10 or not source.has(letters[i]):valid=false;break
   var mat: BaseMaterial3D=source[letters[i]]
   if not mat.albedo_texture:valid=false;break
   if i==0:size=mat.albedo_texture.get_size()
   if mat.albedo_texture.get_size()!=size:valid=false;break
   frames.append({"base":Mips.prepare(mat.albedo_texture,mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR),"glow":Mips.prepare(mat.emission_texture) if mat.emission_texture else null})
  if valid and frames.size()>1:bank[key]=frames
 root.set_meta(FRAME_TAG,bank)
static func tint(map: String,p: Vector3) -> Color:
 # Authored damp lower courses and broad runoff bands. Reflect coordinates so
 # opposing bases receive identical treatment. Never touch team-colour trims.
 var x:=absf(p.x);var z:=absf(p.z)
 var foot:=1.0-smoothstep(0.0,5.0 if map=="tf_vesper" else 3.2,p.y)
 var band:=1.0-smoothstep(1.2,4.8,absf(x-12.0))
 var court:=1.0-smoothstep(18.0,34.0,z)
 var strength:=clampf(foot*(.07+.07*band)+.035*court,0,.17)
 var damp:=Color(.77,.84,.78) if map=="tf_vesper" else Color(.80,.82,.74)
 return Color.WHITE.lerp(damp,strength*3.2)
static func vary(root: Node,map: String) -> void:
 if not STONE.has(map) or root.get_meta(VARY_TAG,0)==VERSION:return
 var count:=0
 for node in root.find_children("*","MeshInstance3D",true,false):
  if not node.mesh is ArrayMesh or node.mesh.get_blend_shape_count()>0:continue
  # Moving brush entities must not inherit world-position stains.
  var parent: Node=node.get_parent();var moving:=false
  while parent and parent!=root:
   if "attributes" in parent and str(parent.attributes.get("classname","")).begins_with("func_"):moving=true;break
   parent=parent.get_parent()
  if moving:continue
  var mesh: ArrayMesh=node.mesh;var eligible: Array=[]
  for i in mesh.get_surface_count():
   var mat: Material=node.get_active_material(i)
   eligible.append(mat is ShaderMaterial and str(mat.get_meta("bsp_texture_name","")) in STONE[map])
  if not true in eligible:continue
  var result:=ArrayMesh.new()
  var transform:=Transform3D.IDENTITY;var cursor: Node=node
  while cursor!=root:
   if cursor is Node3D:transform=cursor.transform*transform
   cursor=cursor.get_parent()
  for i in mesh.get_surface_count():
   var arrays:=mesh.surface_get_arrays(i)
   if eligible[i]:
    var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var colours:=PackedColorArray()
    for point in points:colours.append(tint(map,transform*point))
    arrays[Mesh.ARRAY_COLOR]=colours;count+=points.size()
   result.add_surface_from_arrays(mesh.surface_get_primitive_type(i),arrays)
   result.surface_set_material(i,mesh.surface_get_material(i))
   result.surface_set_name(i,mesh.surface_get_name(i))
  node.mesh=result
 root.set_meta(VARY_TAG,VERSION);root.set_meta("map_tinted_vertices",count)
