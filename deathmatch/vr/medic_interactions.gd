extends RefCounted
## Tracked contact selection; native authority owns revival and collision-safe dragging.
const Equipment=preload("res://deathmatch/avatars/equipment.gd")
const PatientGeometry=preload("res://deathmatch/conquest/classes/patient_geometry.gd")
var rig
var drag_hand:=-1
var drag_target:=0
var grip_edges:Array=[true,true]
var injection_target:=0
var injection_basis:=Basis.IDENTITY
var injection_offset:=Vector3.ZERO
func setup(value)->void:rig=value
func chest(id:int)->Vector3:return rig.game.fighters[id].render_position()+Vector3.UP*.35
func contact(id:int,point:Vector3)->Vector3:
 var fighter=rig.game.fighters[id]
 return PatientGeometry.contact(fighter.render_position(),fighter.damage_yaw() if fighter.has_method("damage_yaw") else fighter.rotation.y,point)
func patient(id:int)->bool:
 var game=rig.game;var mine:int=game.multiplayer.get_unique_id()
 return game.classes.downed.has(id) and game.fighters.has(id) and game.players.has(id) and not game.players[id].dead and game.players[id].team==game.players[mine].team
func free_hand(i:int)->bool:
 var utility=rig.cq_utility
 return not (utility.held and utility.hand_index==i) and not (rig.cq_hands.holding and i==(0 if rig.left_handed else 1)) and not (rig.shoulder_radio.held and rig.shoulder_radio.held_hand==i)
func update(valid:bool)->void:
 var game=rig.game;var mine:int=game.multiplayer.get_unique_id()
 if not valid or game.classes.role(mine)!="medic":
  drag_hand=-1;drag_target=0;injection_target=0;grip_edges=[true,true];return
 for i in 2:
  var hand=rig.left if i==0 else rig.right
  var tracked:bool=rig.simulated or hand.get_has_tracking_data()
  var pressed:bool=tracked and hand.get_float("grip")>.6
  if drag_hand==i and (not pressed or not patient(drag_target) or not free_hand(i) or hand.global_position.distance_to(contact(drag_target,hand.global_position))>1.5):drag_hand=-1;drag_target=0
  if drag_hand<0 and pressed and not grip_edges[i] and free_hand(i):
   var nearest:=.6
   for id in game.classes.downed:
    if not patient(id):continue
    var distance:float=hand.global_position.distance_to(contact(id,hand.global_position))
    if distance<nearest:nearest=distance;drag_hand=i;drag_target=id
  grip_edges[i]=pressed if tracked else true
 var utility=rig.cq_utility
 var injecting:bool=utility.held and not utility.box_mode and utility.kind()=="medical" and utility.hand().get_float("trigger")>.6
 if not injecting:
  injection_target=0;return
 var target:=0
 for id in game.classes.injecting:
  if patient(id) and game.classes.injecting[id].medic==mine and game.classes.injecting[id].progress>0:target=id;break
 if target!=injection_target:
  injection_target=target
  if target!=0:
   var pose:Transform3D=Equipment.injector_pose(utility.hand().global_transform)
   injection_basis=pose.basis
   var tip:Vector3=pose*Equipment.injector_tip()
   injection_offset=contact(target,tip)-chest(target)
   rig.feedback(.25,.08,utility.hand_index!=(0 if rig.left_handed else 1))
func injector_pose()->Transform3D:
 return Transform3D(injection_basis,chest(injection_target)+injection_offset-injection_basis*Equipment.injector_tip())
func decorate(command:Dictionary)->void:
 if drag_hand<0 or command.input_blocked:return
 var hand=rig.left if drag_hand==0 else rig.right
 if hand.get_float("grip")<=.6 or (not rig.simulated and not hand.get_has_tracking_data()):return
 command.cq_drag=true
 if not command.xr.is_empty():
  command.xr=command.xr.duplicate()
  # Native drag uses the offhand: preserve physical poses and identify which
  # free hand was deliberately gripped against the incapacitated body.
  var left_handed:bool=drag_hand==1
  if command.xr.left_handed!=left_handed:
   var weapon:Transform3D=command.xr.weapon
   command.xr.weapon=command.xr.get("offhand_weapon",command.xr.left if left_handed else command.xr.right)
   command.xr.offhand_weapon=weapon
  command.xr.left_handed=left_handed
  if not rig.cq_utility.held:command.fire=false;command.melee=false
func attach_hand()->void:
 if injection_target==0 or not patient(injection_target):return
 var i:int=rig.cq_utility.hand_index
 if i<0:return
 rig.hand_models[i].global_transform=injector_pose()*Equipment.injector_grip().affine_inverse()
 rig.hand_animators[i].curls=PackedFloat32Array([.85,.9,.95,.95,.95])
