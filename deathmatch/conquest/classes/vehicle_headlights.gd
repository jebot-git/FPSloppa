extends RefCounted
## Four unshadowed cones shared by all map/avatar receiver shaders.
## Driver's pair first, then nearest lit vehicle. Hull orientation, never turret aim.
const MAX_VEHICLES:=2
const RANGE:=60.0
var selected:Array=[]
var previous:Array=[]
static func lamp_pose(row:Dictionary,side:int,size:Vector3)->Transform3D:
 var local:=Vector3(side*minf(size.x*.34,1.2),1.15 if row.kind=="transport" else size.y*.65,-size.z*.5-.02)
 var normal:Vector3=row.get("normal",Vector3.UP);var forward:Vector3=Basis(Vector3.UP,row.yaw)*Vector3.FORWARD
 var right:=forward.cross(normal).normalized();var basis:=Basis(right,normal,-normal.cross(right).normalized())
 var origin:=Vector3(row.position.x,row.get("visual_y",row.position.y),row.position.z)
 var direction:Vector3=(basis*Vector3(-side*.025,-.025,-1)).normalized()
 return Transform3D(Basis.looking_at(direction, basis.y),origin+basis*local)
func clear()->void:
 selected.clear();upload([])
func upload(values:Array)->void:
 if values==previous:return
 previous=values.duplicate()
 for i in 4:
  RenderingServer.global_shader_parameter_set("cq_lamp_position"+str(i),values[i*2] if i*2<values.size() else Vector4.ZERO)
  RenderingServer.global_shader_parameter_set("cq_lamp_axis"+str(i),values[i*2+1] if i*2+1<values.size() else Vector4.ZERO)
func update(service)->void:
 var camera:Camera3D=service.game.world_view_camera()
 if not camera:clear();return
 var mine:int=service.game.multiplayer.get_unique_id()
 var candidates:Array=[]
 for key in service.rendered_rows:
  var row:Dictionary=service.rendered_rows[key]
  if row.hp<=0 or not row.get("headlights",false):continue
  var distance:float=camera.global_position.distance_squared_to(row.position)
  if distance>150.*150.:continue
  candidates.append({"key":key,"priority":-1. if row.pilot==mine else distance})
 candidates.sort_custom(func(a,b):return a.priority<b.priority if a.priority!=b.priority else a.key<b.key)
 selected.clear();var values:Array=[]
 for candidate in candidates.slice(0,MAX_VEHICLES):
  selected.append(candidate.key)
  var row:Dictionary=service.rendered_rows[candidate.key]
  for side in [-1,1]:
   var pose:=lamp_pose(row,side,service.profile(row).size);var direction:Vector3=-pose.basis.z
   values.append(Vector4(pose.origin.x,pose.origin.y,pose.origin.z,RANGE));values.append(Vector4(direction.x,direction.y,direction.z,6.))
 upload(values)
static func prepare(model:Node3D,row:Dictionary,size:Vector3)->void:
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(1,.94,.8)
 var holder:=Node3D.new();holder.name="HeadlightLenses";model.add_child(holder)
 var local_row:Dictionary=row.duplicate();local_row.position=Vector3.ZERO;local_row.visual_y=0.;local_row.yaw=0.;local_row.normal=Vector3.UP
 for side in [-1,1]:
  var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.22,.15,.08);box.material=material;mesh.mesh=box;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;holder.add_child(mesh);mesh.transform=lamp_pose(local_row,side,size)
