extends RefCounted
## Blender-authored, shared with the generated native transport geometry.
const EYE_HEIGHT:=1.48
static var manifest:Dictionary={}
static func data()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/models/ground_transport/manifest.json"))
 return manifest
static func point(index:int,kind:String)->Vector3:
 var v:Array=data().seats[index][kind];return Vector3(v[0],v[1],v[2])
static func size()->Vector3:
 var v:Array=data().size;return Vector3(v[0],v[1],v[2])
static func prepare_windows(node:Node)->void:
 # Keep transparent glass out of the opaque baked-light material conversion.
 var glass:=StandardMaterial3D.new();glass.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.cull_mode=BaseMaterial3D.CULL_DISABLED;glass.albedo_color=Color(.18,.32,.34,.10);glass.no_depth_test=false
 for mesh in node.find_children("*PodWindows*","MeshInstance3D",true,false):mesh.material_override=glass
 var hull:MeshInstance3D=node.find_child("Hull",true,false)
 if hull:
  var original:=hull.get_active_material(0)
  var finish:=ShaderMaterial.new();finish.shader=preload("res://deathmatch/conquest/classes/transport_hull.gdshader")
  if original is StandardMaterial3D:finish.set_shader_parameter("albedo",original.albedo_texture)
  elif original is ShaderMaterial:finish.set_shader_parameter("albedo",original.get_shader_parameter("albedo"))
  hull.material_override=finish


static func prepare_seats(node:Node3D)->void:
 if node.has_node("OccupantSeats"):return
 var seats:=Node3D.new();seats.name="OccupantSeats";node.add_child(seats)
 var art=preload("res://deathmatch/art.gd")
 var finish:=art.material(Color("26362f"),.15)
 for i in 8:
  var seat:=Node3D.new();seats.add_child(seat);seat.position=point(i,"seat")
  if i<6:seat.rotation.y=PI/2 if i<3 else -PI/2
  art.box(seat,Vector3(0,.35,0),Vector3(.5,.12,.5),finish)
  art.box(seat,Vector3(0,.7,.22),Vector3(.5,.65,.1),finish)
