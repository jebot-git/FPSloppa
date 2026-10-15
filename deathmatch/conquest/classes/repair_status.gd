extends RefCounted
const RANGE:=20.
const UI_LAYER:=1<<18
var bars:Dictionary={}
static func eligible(row:Dictionary,eye:Vector3,team:int)->bool:
 return row.hp>0 and (row.team<0 or row.team==team) and eye.distance_to(row.position)<=RANGE
func clear()->void:
 for bar in bars.values():
  if is_instance_valid(bar):bar.queue_free()
 bars.clear()
func make_bar(parent:Node)->Node3D:
 var bar:=Node3D.new();bar.name="RepairVehicleHealth";parent.add_child(bar)
 for name in ["Background","Fill"]:
  var mesh:=MeshInstance3D.new();mesh.name=name;mesh.layers=UI_LAYER;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var quad:=QuadMesh.new();quad.size=Vector2(.84,.075);mesh.mesh=quad
  var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.albedo_color=Color("102a30")
  mesh.material_override=material;bar.add_child(mesh)
  if name=="Fill":mesh.position.z=.003
 var label:=Label3D.new();label.name="Value";label.layers=UI_LAYER;label.font=preload("res://deathmatch/ui/cq/theme.gd").FONT;label.font_size=24;label.pixel_size=.006;label.position.y=.13;label.modulate=Color("dcebe8");label.outline_size=6;bar.add_child(label)
 return bar
func update(service)->void:
 var game=service.game;var mine:int=game.multiplayer.get_unique_id()
 var held:bool=game.active and not game.menu_open and game.classes.role(mine)=="technician" and not game.local_state().get("dead",true)
 if game.is_vr():held=held and game.xr_rig.cq_utility.held and not game.xr_rig.cq_utility.box_mode and game.xr_rig.cq_utility.kind()=="engineering"
 else:held=held and game.local_state().get("weapon",-1)==7
 var camera:Camera3D=game.xr_rig.head if game.is_vr() else game.camera
 if not is_instance_valid(camera):held=false
 for key in bars.keys():
  if not service.rows.has(key):bars[key].queue_free();bars.erase(key)
 for key in service.rows:
  var row:Dictionary=service.view_row(key)
  var show:bool=held and eligible(row,camera.global_position,game.local_state().get("team",-1))
  if not show:
   if bars.has(key):bars[key].hide()
   continue
  if not bars.has(key):bars[key]=make_bar(service)
  var bar:Node3D=bars[key];var profile:Dictionary=service.profile(row);var ratio:float=clampf(row.hp/profile.hp,0,1)
  bar.show();bar.global_position=service.visual_origin(row)+Vector3.UP*(profile.size.y+.6)
  if service.can_repair_from_cabin(mine) and service.key_for(mine)==key:
   bar.global_position=service.visual_origin(row)+service.visual_basis(row)*(preload("res://deathmatch/conquest/classes/transport_geometry.gd").point(7,"seat")+Vector3(0,1.,-.65))
  bar.global_basis=camera.global_basis
  var fill:MeshInstance3D=bar.get_node("Fill");fill.scale.x=ratio;fill.position.x=-.42*(1.-ratio)
  fill.material_override.albedo_color=Color("69b9b1") if ratio>=.99 else Color("e8c46c") if ratio>.3 else Color("e27770")
  bar.get_node("Value").text="%s  %d / %d HP"%[profile.name,ceili(row.hp),profile.hp]
