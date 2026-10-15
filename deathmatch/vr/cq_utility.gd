extends RefCounted
## A deliberate grip at the visible shoulder equips into either tracked hand.
var rig
var hand_index:=-1
var edges:=[true,true]
var saved_weapon:=4
var armed:=false
var trigger_before:=false
var hand_clock:=0.
var samples:Array=[]
var guide:MeshInstance3D
var held:bool:
 get:return hand_index>=0
func setup(value)->void:rig=value
func reset()->void:
 if held and armed:rig.game.resident.request(4)
 hand_index=-1;armed=false;edges=[true,true];samples.clear()
 if is_instance_valid(guide):guide.hide()
func hand()->XRController3D:return rig.left if hand_index==0 else rig.right
func kind()->String:
 var game=rig.game;var id:int=game.multiplayer.get_unique_id()
 return game.classes.states.get(id,{}).get("equipped_utility",game.classes.UTILITIES[game.classes.role(id)][0].id)
func grenade()->bool:return kind() in ["jetpack","healing_grenade"]
func update(delta:float,valid:bool)->void:
 hand_clock+=delta
 var controllers:=[rig.left,rig.right]
 if not valid:
  reset();return
 for i in 2:
  var down:bool=controllers[i].get_float("grip")>.6
  if not held and down and not edges[i] and not rig.shoulder_radio.held and controllers[i].global_position.distance_to(rig.shoulder_mount(false).origin)<.25:
   hand_index=i;saved_weapon=rig.game.desired_weapon;armed=false;trigger_before=false;samples.clear();rig.cq_hands.holding=false
   if not grenade() and kind() not in ["recon","recon_drone"]:rig.game.desired_weapon=7 if kind() in ["medical","engineering"] else 8
   rig.feedback(.3,.06,i!=(0 if rig.left_handed else 1))
  edges[i]=down
 if not held:return
 var active:XRController3D=hand();var grip:bool=active.get_float("grip")>.6;var trigger:bool=active.get_float("trigger")>.6
 var point:Vector3=active.position-rig.head.position
 samples.append({"at":hand_clock,"point":point})
 while samples.size()>2 and hand_clock-samples[0].at>.1:samples.pop_front()
 var speed:=0.
 if samples.size()>1:speed=point.distance_to(samples[0].point)/maxf(.001,hand_clock-samples[0].at)
 if grenade():
  update_guide()
  if trigger and not trigger_before and not armed:
   rig.game.resident.request(2,1);armed=true;rig.feedback(.3,.06,hand_index!=(0 if rig.left_handed else 1))
  if armed and (not grip or not trigger and trigger_before and speed>1.4):
   rig.game.resident.request(3);release();return
 elif trigger and not trigger_before and kind() in ["recon","recon_drone"]:rig.game.resident.request(0)
 if not grip:
  if armed:rig.game.resident.request(4)
  release();return
 trigger_before=trigger
func release()->void:
 hand_index=-1;armed=false;rig.game.desired_weapon=saved_weapon;rig.cq_hands.holding=false;samples.clear()
 if is_instance_valid(guide):guide.hide()
func decorate(command:Dictionary)->void:
 if not held:return
 var active:=hand();var aim:XRController3D=rig.left_aim if hand_index==0 else rig.right_aim
 var pose:Dictionary=command.xr
 if pose.is_empty():return
 pose=pose.duplicate();pose.left_handed=hand_index==0;pose.weapon=rig.origin.transform*preload("res://deathmatch/vr/poses.gd").held_weapon(active.transform,aim.transform)
 var other:XRController3D=rig.right if hand_index==0 else rig.left;var other_aim:XRController3D=rig.right_aim if hand_index==0 else rig.left_aim
 pose.offhand_weapon=rig.origin.transform*preload("res://deathmatch/vr/poses.gd").held_weapon(other.transform,other_aim.transform)
 if grenade():pose.weapon.basis=pose.offhand_weapon.basis
 command.xr=preload("res://deathmatch/vr/poses.gd").validate(pose)
 command.weapon=rig.game.desired_weapon;command.weapon_held=true
 command.fire=kind() not in ["recon","recon_drone"] and not grenade() and active.get_float("trigger")>.6 and not command.input_blocked
 command.reload=false;command.reload_grip=false;command.reload_trigger=false;command.offhand_fire=false;command.alt_fire=false;command.melee=false;command.cq_drag=false

func update_guide()->void:
 if not is_instance_valid(guide):
  guide=MeshInstance3D.new();guide.mesh=ImmediateMesh.new();rig.add_child(guide);guide.top_level=true;guide.global_transform=Transform3D.IDENTITY
  var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("e8c46c");guide.material_override=material;guide.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var other:XRController3D=rig.right if hand_index==0 else rig.left
 var other_aim:XRController3D=rig.right_aim if hand_index==0 else rig.left_aim
 var mesh:ImmediateMesh=guide.mesh;mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
 mesh.surface_add_vertex(other.global_position);mesh.surface_add_vertex(other.global_position-other_aim.global_basis.z*1.2);mesh.surface_end();guide.show()
