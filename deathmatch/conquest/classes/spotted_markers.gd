extends Node3D
## Cosmetic markers consume existing team-shared spotting; they never acquire targets.
const ROOT:="res://deathmatch/conquest/classes/icons/spotted/"
const TITLES={"shocktroop":"SHOCKTROOP","scout":"SCOUT","medic":"MEDIC","technician":"TECHNICIAN","light":"LIGHT TANK","heavy":"HEAVY TANK","rocket":"ROCKET TANK","transport":"TRANSPORT"}
var game
var markers:Dictionary={}
var textures:Dictionary={}
var next_update:=0.
func setup(arena)->void:game=arena
static func targets(arena,viewer:int)->Dictionary:
 var result:Dictionary={}
 if not arena.players.has(viewer) or not arena.classes.alive(viewer):return result
 for id in arena.players:
  if arena.players[id].team==arena.players[viewer].team or not arena.spotting.visible(arena,viewer,id):continue
  if arena.battery_tanks.mounted(id):continue
  var role:String=arena.classes.role(id)
  result["player:"+str(id)]={"kind":role,"position":arena.fighters[id].position+Vector3.UP*2.35}
 for key in arena.battery_tanks.rows:
  var row:Dictionary=arena.battery_tanks.rows[key];var driver:int=row.pilot
  if row.hp<=0 or driver==0 or row.team==arena.players[viewer].team or not arena.spotting.visible(arena,viewer,driver):continue
  if not TITLES.has(row.kind):continue
  result["vehicle:"+str(key)]={"kind":row.kind,"position":row.position+Vector3.UP*(arena.battery_tanks.profile(row).size.y+1.)}
 return result
func sync(desired:Dictionary)->void:
 for key in markers.keys():
  if not desired.has(key):markers[key].queue_free();markers.erase(key)
 for key in desired:
  var row:Dictionary=desired[key]
  if not markers.has(key):
   var marker:=Node3D.new();add_child(marker);markers[key]=marker
   var icon:=Sprite3D.new();icon.name="Icon";icon.billboard=BaseMaterial3D.BILLBOARD_ENABLED;icon.fixed_size=true;icon.pixel_size=.0012;icon.offset=Vector2(0,32);icon.no_depth_test=true;icon.shaded=false;icon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;marker.add_child(icon)
   var caption:=Label3D.new();caption.name="Caption";caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED;caption.fixed_size=true;caption.no_depth_test=true;caption.font_size=14;caption.pixel_size=.0018;caption.outline_size=5;caption.modulate=Color("ffbd80");marker.add_child(caption)
  var marker:Node3D=markers[key];marker.position=row.position
  if not textures.has(row.kind):textures[row.kind]=load(ROOT+row.kind+".svg")
  marker.get_node("Icon").texture=textures[row.kind];marker.get_node("Caption").text=TITLES[row.kind]
func clear()->void:
 for marker in markers.values():marker.queue_free()
 markers.clear()
func _process(_delta:float)->void:
 if not game:return
 if game.headless or not game.active:clear();return
 if game.clock<next_update:return
 next_update=game.clock+.1
 sync(targets(game,game.multiplayer.get_unique_id()))
