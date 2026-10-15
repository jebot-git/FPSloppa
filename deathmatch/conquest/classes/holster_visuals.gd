extends Node3D
## Remote presentation of the authority's grip state; shares local mount geometry.
const Slots=preload("res://deathmatch/conquest/classes/equipment_slots.gd")
const Models=preload("res://deathmatch/conquest/classes/models.gd")
const Art=preload("res://deathmatch/art.gd")
var game
var rows:Dictionary={}
func setup(arena)->void:game=arena
func draw()->void:
 for key in rows.keys():
  if not game.fighters.has(rows[key].owner):rows[key].node.queue_free();rows.erase(key)
 for row in rows.values():row.node.hide()
 if not game.active:return
 var mine:int=game.multiplayer.get_unique_id()
 for id in game.fighters:
  if id==mine or not game.players.has(id):continue
  var state:Dictionary=game.players[id];var actor=game.fighters[id]
  var held:bool=game.classes.states.get(id,{}).get("weapon_held",true)
  var allowed:bool=not state.dead and not state.spectator and not game.battery_tanks.mounted(id) and (not game.classes.cloaked(id) or game.match_mode.same_team(id,mine))
  if is_instance_valid(actor.avatar):
   var gun:Node3D=actor.avatar.get("gun")
   if not is_instance_valid(gun):gun=actor.avatar.get_node_or_null("Upper/WeaponModel")
   if is_instance_valid(gun):gun.visible=allowed and held
  var slots:Array=Slots.equipped(game,id)
  var pose:Dictionary=state.xr
  var head:Transform3D=pose.get("head",Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)))
  var yaw:=Basis(Vector3.UP,head.basis.get_euler().y);var side:float=-1. if pose.get("left_handed",false) else 1.
  for i in slots.size():
   var w:int=slots[i];var key:=str(id)+":"+str(i)
   if not rows.has(key) or rows[key].weapon!=w:
    if rows.has(key):rows[key].node.queue_free()
    var model:Node3D=Models.weapon(w,"cq_"+game.classes.role(id));add_child(model);rows[key]={"node":model,"owner":id,"weapon":w}
   var mount:=Slots.mount(head,pose.get("left_handed",false),i==0)
   rows[key].node.global_transform=Art.held_transform(Transform3D(Basis(Vector3.UP,state.yaw),actor.render_position())*mount,w,Art.VR_SCALE,"cq_"+game.classes.role(id))
   rows[key].node.visible=allowed and (not held or state.weapon!=w)
