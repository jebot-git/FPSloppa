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
 prepare_wheel(node)
 if node.has_node("OccupantSeats"):return
 var seats:=Node3D.new();seats.name="OccupantSeats";node.add_child(seats)
 var art=preload("res://deathmatch/art.gd")
 var finish:=art.material(Color("26362f"),.15)
 for i in 8:
  var seat:=Node3D.new();seats.add_child(seat);seat.position=point(i,"seat")
  if i<6:seat.rotation.y=PI/2 if i<3 else -PI/2
  art.box(seat,Vector3(0,.35,0),Vector3(.5,.12,.5),finish)
  art.box(seat,Vector3(0,.7,.22),Vector3(.5,.65,.1),finish)

const WHEEL_RADIUS:=.18
static var wheel_mesh:ArrayMesh
static var column_mesh:ArrayMesh
static var wheel_material:StandardMaterial3D
static func wheel_mount()->Transform3D:
 return Transform3D(Basis(Vector3.RIGHT,deg_to_rad(-25.)),point(6,"seat")+Vector3(0,1.03,-.48))
static func append_part(tool:SurfaceTool,mesh:PrimitiveMesh,pose:Transform3D,color:Color)->void:
 var arrays:=mesh.get_mesh_arrays();var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 for i in indices:
  tool.set_color(color);tool.set_normal((pose.basis*normals[i]).normalized());tool.add_vertex(pose*vertices[i])
static func prepare_wheel(node:Node3D)->void:
 if node.has_node("SteeringWheelMount"):return
 if not wheel_mesh:
  var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  var ring:=TorusMesh.new();ring.inner_radius=.165;ring.outer_radius=.195;ring.rings=32;ring.ring_segments=6
  append_part(tool,ring,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3.ZERO),Color("202c2c"))
  var spoke:=BoxMesh.new();spoke.size=Vector3(.18,.025,.028)
  for angle in [PI/6,5*PI/6,3*PI/2]:
   append_part(tool,spoke,Transform3D(Basis(Vector3.BACK,angle),Vector3(cos(angle)*.09,sin(angle)*.09,0)),Color("708886"))
  var hub:=CylinderMesh.new();hub.top_radius=.043;hub.bottom_radius=.043;hub.height=.055;hub.radial_segments=12;hub.rings=1
  append_part(tool,hub,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3.ZERO),Color("344b4a"))
  tool.index();wheel_mesh=tool.commit()
  tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
  var shaft:=CylinderMesh.new();shaft.top_radius=.026;shaft.bottom_radius=.035;shaft.height=.28;shaft.radial_segments=8;shaft.rings=1
  append_part(tool,shaft,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0,-.155)),Color("344b4a"));tool.index();column_mesh=tool.commit()
  wheel_material=StandardMaterial3D.new();wheel_material.vertex_color_use_as_albedo=true;wheel_material.roughness=.7
 var mount:=Node3D.new();mount.name="SteeringWheelMount";node.add_child(mount);mount.transform=wheel_mount()
 var wheel:=MeshInstance3D.new();wheel.name="Wheel";wheel.mesh=wheel_mesh;wheel.material_override=wheel_material;mount.add_child(wheel)
 var column:=MeshInstance3D.new();column.name="Column";column.mesh=column_mesh;column.material_override=wheel_material;mount.add_child(column)
