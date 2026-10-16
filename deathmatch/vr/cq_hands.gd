extends Node3D
## Local tracked affordances; inventory, ammunition and gestures remain authoritative.
const Models=preload("res://deathmatch/conquest/classes/models.gd")
const Hip=preload("res://deathmatch/conquest/classes/hip_mount.gd")
const Art=preload("res://deathmatch/art.gd")
var rig
var holding:=false
var grip_before:=true
var holsters:Dictionary={}
var bag:Node3D
var bag_ammo:Node3D
var carried:Node3D
var ammo_weapon:=-1
var ammo_readout:Label3D
var chamber_readout:Label3D
var weapon_readout:Node3D
var previous:Dictionary={}
var cloak=preload("res://deathmatch/vr/cq_cloak.gd").new()
var debris:Array=[]
func setup(value)->void:
 rig=value;name="CQTrackedEquipment"
 bag=load("res://deathmatch/weapons/cs16/magazine_pouch.scn").instantiate();add_child(bag);bag.hide()
func reset()->void:
 holding=false;grip_before=true;previous.clear()
func row()->Dictionary:
 return rig.game.variant_combat.magazines.states.get(rig.game.multiplayer.get_unique_id(),{}).get("physical",{}).get(rig.game.local_state().get("weapon",-1),{})
func claims_hand(primary:Transform3D,support:Transform3D)->bool:
 var state:=row();var w:int=rig.game.local_state().get("weapon",2)
 if state.get("carry",0)>0 or state.get("grab","")!="" or state.get("stroke",0.)>.05:return true
 var weapon:=Art.held_transform(primary,w,Art.VR_SCALE,"cq_shocktroop")
 if rig.game.bindings.vr_pressed(rig,"offhand_fire") and support.origin.distance_to(weapon*Models.anchor(w,"magazine_anchor"))<.12:return true
 var rack:Vector3=weapon*(Models.anchor(w,"rack_anchor")+Vector3.BACK*.065*state.get("stroke",0.))
 var rack_top:Vector3=rack+weapon.basis.y.normalized()*(.08 if w in [0,2,9] else 0.)
 if Models.metadata(w,"cq_shocktroop").get("reload_kind","")!="pack" and (rig.game.bindings.vr_pressed(rig,"support") or rig.game.bindings.vr_pressed(rig,"offhand_fire")) and support.origin.distance_to(Geometry3D.get_closest_point_to_segment(support.origin,rack,rack_top))<.105 and support.origin.distance_to(weapon*Models.anchor(w,"rack_anchor"))<support.origin.distance_to(weapon*Models.anchor(w,"support_anchor")):return true
 var pose:Dictionary=rig.sample_raw_pose()
 return not pose.is_empty() and Hip.recovery_contains(pose,rig.origin.transform*support.origin)
func mount(primary:bool)->Transform3D:
 return rig.origin.global_transform*preload("res://deathmatch/conquest/classes/equipment_slots.gd").mount(rig.head.transform,rig.left_handed,primary)
func update(delta:float,valid:bool)->void:
 var game=rig.game;var mine:int=game.multiplayer.get_unique_id()
 var main:XRController3D=rig.left if rig.left_handed else rig.right
 var support:XRController3D=rig.right if rig.left_handed else rig.left
 var pressed:bool=main.get_float("grip")>.6
 var slots:Array=preload("res://deathmatch/conquest/classes/equipment_slots.gd").equipped(game,mine)
 sample_hold(slots,main.global_position,pressed,valid and not rig.cq_utility.held and (rig.medic_interactions==null or rig.medic_interactions.drag_hand!=(0 if rig.left_handed else 1)))
 if slots.size()==2:
  for i in 2:
   var w:int=slots[i]
   if not holsters.has(i) or holsters[i].weapon!=w:
    if holsters.has(i):holsters[i].node.queue_free()
    var model:Node3D=Models.weapon(w,"cq_"+game.classes.role(mine));add_child(model);holsters[i]={"weapon":w,"node":model}
   var at:=mount(i==0);var model:Node3D=holsters[i].node
   model.global_transform=Art.held_transform(at,w,Art.VR_SCALE,"cq_shocktroop");model.visible=valid and (not holding or game.desired_weapon!=w)
 bag.visible=valid;bag.global_transform=rig.global_transform*Hip.pouch(rig.sample_raw_pose())
 var state:=row();var w:int=game.local_state().get("weapon",2)
 if valid and is_instance_valid(rig.gun):
  if ammo_weapon!=w:
   if is_instance_valid(carried):carried.queue_free()
   if is_instance_valid(bag_ammo):bag_ammo.queue_free()
   bag_ammo=Models.ammunition(rig.gun,w);bag.add_child(bag_ammo);bag_ammo.position.y=.08;bag_ammo.scale=Vector3.ONE*Art.VR_SCALE
   carried=Models.ammunition(rig.gun,w);add_child(carried);ammo_weapon=w
  bag_ammo.visible=state.get("carry",0)==0
  carried.visible=state.get("carry",0)>0
  var support_aim:XRController3D=rig.right_aim if rig.left_handed else rig.left_aim
  carried.global_transform=Models.ammunition_pose(support.global_transform,support_aim.global_transform)
  if not is_instance_valid(ammo_readout):
   ammo_readout=Label3D.new();ammo_readout.layers=1<<18;ammo_readout.font=preload("res://deathmatch/ui/cq/theme.gd").FONT;ammo_readout.font_size=36;ammo_readout.pixel_size=.001;ammo_readout.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(ammo_readout)
   chamber_readout=Label3D.new();chamber_readout.layers=1<<18;chamber_readout.font=ammo_readout.font;chamber_readout.font_size=24;chamber_readout.pixel_size=.0008;chamber_readout.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(chamber_readout)
  var ammo:Dictionary=preload("res://deathmatch/ui/cq/hud.gd").ammo_readout(game,mine)
  var rounds:int=state.get("carried_rounds",0) if state.get("carry",0)==4 else mini(ammo.capacity,ammo.reserve+ammo.loaded)
  ammo_readout.visible=carried.visible;ammo_readout.text="%02d / %02d"%[rounds,ammo.capacity];ammo_readout.modulate=Color("ff827a") if rounds==0 else Color("73e5df");ammo_readout.global_position=carried.global_position+Vector3.UP*.10
  chamber_readout.visible=false

  if not previous.is_empty() and previous.get("weapon",-1)==w and previous.get("mag",true) and not state.get("mag",true) and state.get("carry",0)!=4:
   var dropped:=Models.ammunition(rig.gun,w);add_child(dropped)
   dropped.global_transform=Transform3D(rig.gun.global_basis,rig.gun.to_global(Models.anchor(w,"magazine_anchor")))
   debris.append({"node":dropped,"life":2.,"velocity":Vector3.DOWN*.3})
   rig.feedback(.25,.06,true)
   while debris.size()>4:debris.pop_front().node.queue_free()
 cloak.update(valid and game.classes.cloaked(mine),rig.hand_models+[rig.gun,rig.shoulder_utility,carried]+holsters.values().map(func(h):return h.node))
 var show_panel:bool=valid and w==5 and is_instance_valid(rig.gun) and rig.gun.visible
 if show_panel and not is_instance_valid(weapon_readout):
  weapon_readout=preload("res://deathmatch/vr/weapon_display.gd").new();add_child(weapon_readout);weapon_readout.setup()
 if is_instance_valid(weapon_readout):weapon_readout.update_display(rig.gun,game.variant_combat.charge_label(mine).trim_suffix(" · "),game.variant_combat.charges.has(mine),show_panel)
 previous=state.duplicate();previous.weapon=w
 if not valid and is_instance_valid(carried):carried.hide()
 if not valid and is_instance_valid(ammo_readout):ammo_readout.hide();chamber_readout.hide()
 for i in range(debris.size()-1,-1,-1):
  var d:Dictionary=debris[i];d.life-=delta;d.velocity+=Vector3.DOWN*9.8*delta;d.node.global_position+=d.velocity*delta
  if d.life<=0:d.node.queue_free();debris.remove_at(i)

func sample_hold(slots:Array,hand_at:Vector3,pressed:bool,valid:bool)->void:
 if not valid or not pressed:holding=false
 if valid and pressed and not grip_before:
  for i in mini(2,slots.size()):
   if hand_at.distance_to(mount(i==0).origin)<.22:
    rig.game.desired_weapon=slots[i];holding=true;break
 grip_before=pressed
