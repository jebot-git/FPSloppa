extends Node3D
## Bounded local thermal tracker rendered on the railgun's authored display.
const RANGE:=150.0
class Screen extends Control:
 var targets:Array=[]
 func _draw()->void:
  draw_rect(Rect2(0,0,256,128),Color("06131b"))
  draw_rect(Rect2(2,2,252,124),Color("44dcca"),false,2)
  draw_string(ThemeDB.fallback_font,Vector2(9,18),"THERMAL TRACK · 150 m",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("70ffdb"))
  draw_line(Vector2(128,26),Vector2(128,119),Color("184d50"))
  for target in targets:
   var p:Vector2=target.point;var color:=Color("ffb56b")
   draw_circle(p-Vector2(0,6),3,color);draw_line(p-Vector2(0,2),p+Vector2(0,6),color,3)
   draw_line(p+Vector2(-4,1),p+Vector2(4,1),color,2)
   draw_line(p+Vector2(0,6),p+Vector2(-4,11),color,2);draw_line(p+Vector2(0,6),p+Vector2(4,11),color,2)
   draw_string(ThemeDB.fallback_font,p+Vector2(6,6),"%dm"%target.distance,HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)
var model:Node3D
var viewport:SubViewport
var screen:Screen
var game
var timer:=0.
func setup(weapon:Node3D,data:Dictionary)->void:
 model=weapon
 viewport=SubViewport.new();viewport.size=Vector2i(256,128);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(viewport)
 screen=Screen.new();screen.size=viewport.size;viewport.add_child(screen)
 var panel:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(data.display_size[0],data.display_size[1]);panel.mesh=quad
 var point:Array=data.display_anchor;panel.position=Vector3(point[0],point[1],point[2]);var angles:Array=data.get("display_rotation",[0.,0.,0.]);panel.rotation=Vector3(angles[0],angles[1],angles[2])
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_texture=viewport.get_texture();panel.material_override=material;panel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(panel)
func _process(delta:float)->void:
 timer-=delta
 if timer>0:return
 timer=.1
 if not is_instance_valid(game):
  var node:Node=get_parent()
  while node:
   if node.has_method("local_state"):game=node;break
   node=node.get_parent()
 if not is_instance_valid(game) or not game.active:return
 if game.is_vr() and not game.xr_rig.is_ancestor_of(model):set_process(false);return
 var origin:=model.global_position;var frame:=model.global_basis.orthonormalized();var mine:Dictionary=game.local_state();var targets:Array=[]
 for id in game.fighters:
  var player:Dictionary=game.players.get(id,{})
  if player.is_empty() or player.dead or player.spectator or player.team==mine.team:continue
  var point:Vector3=frame.inverse()*(game.fighters[id].global_position+Vector3.UP-origin)
  if point.length_squared()>RANGE*RANGE or point.z>=-.5:continue
  var projection:=Vector2(point.x,-point.y)/-point.z
  if absf(projection.x)>.7 or absf(projection.y)>.4:continue
  targets.append({"point":Vector2(128,76)+projection*Vector2(155,100),"distance":point.length()})
 screen.targets=targets;screen.queue_redraw();viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
