extends RefCounted
## A small visible handle on the same prone body used by tracked drag selection.
const Patient=preload("res://deathmatch/conquest/classes/patient_geometry.gd")
const RANGE:=3.0
var points:Dictionary={}
static func anchor(at:Vector3,yaw:float)->Vector3:
 return Patient.contact(at,yaw,at+Basis(Vector3.UP,yaw)*Vector3(0,.35,-.6))+Vector3.UP*.18
func create(parent:Node)->Node3D:
 var node:=Node3D.new();node.name="MedicDragPoint";parent.add_child(node)
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("e8c46c");material.no_depth_test=true;material.render_priority=10
 var ring:=MeshInstance3D.new();var mesh:=TorusMesh.new();mesh.inner_radius=.05;mesh.outer_radius=.075;mesh.rings=12;mesh.ring_segments=6;ring.mesh=mesh;ring.rotation.x=PI/2;ring.material_override=material;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;ring.layers=1<<18;node.add_child(ring)
 var dot:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.022;sphere.height=.044;sphere.radial_segments=8;sphere.rings=4;dot.mesh=sphere;dot.material_override=material;dot.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;dot.layers=1<<18;node.add_child(dot)
 node.set_meta("material",material);return node
func draw(game)->void:
 var mine:int=game.multiplayer.get_unique_id()
 var enabled:bool=game.active and not game.menu_open and game.classes.role(mine)=="medic" and not game.local_state().get("dead",true)
 var camera:Camera3D=game.xr_rig.head if game.is_vr() else game.camera
 var eye:Vector3=camera.global_position
 for id in points.keys():
  if not game.classes.downed.has(id) or not game.fighters.has(id):
   if is_instance_valid(points[id]):points[id].queue_free()
   points.erase(id)
  elif is_instance_valid(points[id]):points[id].hide()
 if not enabled:return
 for id in game.classes.downed:
  if id==mine or not game.fighters.has(id) or not game.players.has(id) or game.players[id].dead or not game.match_mode.same_team(mine,id):continue
  var fighter=game.fighters[id];var at:=anchor(fighter.render_position(),fighter.damage_yaw())
  if eye.distance_to(at)>RANGE:continue
  # Body armour and carried weapons must not hide this interaction affordance.
  # World cover still blocks it, so the marker cannot reveal patients through walls.
  var query:=PhysicsRayQueryParameters3D.create(eye,at,1)
  if not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty():continue
  if not is_instance_valid(points.get(id)):points[id]=create(game.get_node("Map"))
  var node:Node3D=points[id];node.show();node.global_position=at;node.global_basis=camera.global_basis
  var near:=false;var dragging:=false
  if game.is_vr():
   for i in 2:
    var hand=game.xr_rig.left if i==0 else game.xr_rig.right
    near=near or hand.global_position.distance_to(Patient.contact(fighter.render_position(),fighter.damage_yaw(),hand.global_position))<.6
   dragging=game.xr_rig.medic_interactions.drag_target==id
  node.get_meta("material").albedo_color=Color("69b9b1") if dragging else Color("dceff0") if near else Color("e8c46c")
  node.scale=Vector3.ONE*(1.2 if near or dragging else 1.)
