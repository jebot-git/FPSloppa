extends Node3D
## The medic's modeled optic housing is a laser projector, with bounded ray work.
var model:Node3D
var beam:MeshInstance3D
var spot:MeshInstance3D
var game
var timer:=0.
func setup(weapon:Node3D,data:Dictionary)->void:
 model=weapon;var p:Array=data.laser_anchor;position=Vector3(p[0],p[1],p[2])
 beam=MeshInstance3D.new();beam.mesh=ImmediateMesh.new();beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(beam)
 var finish:=StandardMaterial3D.new();finish.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;finish.albedo_color=Color("ff4b46");finish.emission_enabled=true;finish.emission=finish.albedo_color;beam.material_override=finish
 spot=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=.004;mesh.height=.008;mesh.radial_segments=8;mesh.rings=4;spot.mesh=mesh;spot.material_override=finish;spot.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(spot)
func _process(delta:float)->void:
 if not is_instance_valid(game):
  var parent:Node=get_parent()
  while parent:
   if parent.has_method("local_state"):game=parent;break
   parent=parent.get_parent()
 if not is_instance_valid(game) or not game.active:return
 var state:Dictionary=game.local_state();visible=not state.get("dead",true) and state.get("weapon",-1)==int(model.get_meta("cq_weapon")) and not game.menu_open
 if game.is_vr():visible=visible and game.xr_rig.gun==model and model.visible
 if not visible:return
 timer-=delta
 if timer>0:return
 timer=.05
 var from:=global_position;var to:=from-global_basis.z.normalized()*100.
 var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))
 spot.visible=not hit.is_empty()
 if not hit.is_empty():
  to=hit.position;spot.global_position=to+hit.normal*.002
 var mesh:ImmediateMesh=beam.mesh;mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_LINES);mesh.surface_add_vertex(Vector3.ZERO);mesh.surface_add_vertex(to_local(to));mesh.surface_end()
