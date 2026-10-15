extends SceneTree
## Real renderer check: body geometry cannot hide the medic handle; world cover can.
class Rules extends RefCounted:
 var downed:Dictionary={2:{"remaining":10.}}
 func role(_id):return "medic"
class Match extends RefCounted:
 func same_team(_a,_b):return true
class Patient extends Node3D:
 func render_position():return global_position
 func damage_yaw():return 0.
class Game extends Node3D:
 var active:=true
 var menu_open:=false
 var classes=Rules.new()
 var match_mode=Match.new()
 var players:Dictionary={1:{"dead":false,"team":0},2:{"dead":false,"team":0}}
 var fighters:Dictionary={}
 var camera:Camera3D
 func is_vr():return false
 func local_state():return players[1]
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func capture(path:String)->Image:
 await RenderingServer.frame_post_draw
 var result:=root.get_texture().get_image();result.save_png(path);return result
func amber(image:Image)->int:
 var count:=0
 for y in image.get_height():
  for x in image.get_width():
   var c:=image.get_pixel(x,y)
   if c.r>.65 and c.g>.4 and c.b<.6 and c.r>c.b*1.4:count+=1
 return count
func run():
 root.size=Vector2i(960,640)
 var game:=Game.new();root.add_child(game)
 var map:=Node3D.new();map.name="Map";game.add_child(map)
 var patient:=Patient.new();map.add_child(patient);game.fighters[2]=patient
 game.camera=Camera3D.new();game.add_child(game.camera);game.camera.position=Vector3(0,1.5,1.8);game.camera.look_at(Vector3(0,.53,-.6));game.camera.current=true
 var body:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.65,.6,1.3);body.mesh=box;body.position=Vector3(0,.55,-.6)
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(.12,.18,.2);body.material_override=material;map.add_child(body)
 var markers=preload("res://deathmatch/conquest/classes/medic_drag_points.gd").new()
 await physics_frame;markers.draw(game);await process_frame
 var visible:=await capture("/tmp/cq-cabin-display-fixes/drag-visible.png")
 check(markers.points.has(2) and markers.points[2].visible,"medic handle is created in renderer fixture")
 check(amber(visible)>30,"medic handle renders over opaque patient armour")
 var wall:=StaticBody3D.new();wall.collision_layer=1;wall.position=Vector3(0,1.,.6)
 var shape:=CollisionShape3D.new();var solid:=BoxShape3D.new();solid.size=Vector3(3,3,.15);shape.shape=solid;wall.add_child(shape);map.add_child(wall)
 await physics_frame;await physics_frame;markers.draw(game);await process_frame
 var hidden:=await capture("/tmp/cq-cabin-display-fixes/drag-covered.png")
 check(not markers.points[2].visible and amber(hidden)==0,"world cover hides the medic handle")
 game.active=false;markers.draw(game);body.hide();wall.queue_free()
 var launcher:Node3D=preload("res://deathmatch/conquest/classes/models.gd").weapon(5,"cq_technician");map.add_child(launcher)
 var panel=preload("res://deathmatch/vr/weapon_display.gd").new();map.add_child(panel);panel.setup();panel.update_display(launcher,"CHARGING 050% · 0.18s",true,true)
 game.camera.position=Vector3(0,.245,.13);game.camera.look_at(preload("res://deathmatch/conquest/classes/models.gd").anchor(5,"monitor_position"));game.camera.fov=35
 await process_frame;await process_frame
 var display:=await capture("/tmp/cq-cabin-display-fixes/massacre-display.png")
 check(panel.viewport.size==Vector2i(320,200) and panel.label.text=="CHARGING 050%\n0.18s","Massacre status is rendered inside a bounded monitor texture")
 check(amber(display)>30,"charging message is visible on authored monitor glass")
 print("CQ_DRAG_DISPLAY_RENDER ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
