extends RefCounted
## A deliberate grip at the visible shoulder equips into either tracked hand.
var rig
var hand_index:=-1
var edges:=[true,true]
var saved_weapon:=4
var box_mode:=false
var box_model:Node3D
var box_role:=""
var box_pending_until:=0.
var armed:=false
var grenade_pending_until:=0.
var trigger_before:=false
var hand_clock:=0.
var samples:Array=[]
var guide:MeshInstance3D
var held:bool:
 get:return hand_index>=0
func setup(value)->void:rig=value
func reset()->void:
 if held and armed:rig.game.resident.request(4)
 if held:release()
 hand_index=-1;armed=false;box_mode=false;edges=[true,true];samples.clear()
 if is_instance_valid(box_model):box_model.hide()
 if is_instance_valid(guide):guide.hide()
func hand()->XRController3D:return rig.left if hand_index==0 else rig.right
func kind()->String:
 var game=rig.game;var id:int=game.multiplayer.get_unique_id()
 return game.classes.states.get(id,{}).get("equipped_utility",game.classes.UTILITIES[game.classes.role(id)][0].id)
func grenade()->bool:return kind() in ["jetpack","healing_grenade"]
func grenade_count()->int:
 var game=rig.game;var id:int=game.multiplayer.get_unique_id()
 var selected:int=game.classes.grenade_kind(id)
 return game.grenades.state(id).counts[selected] if selected>=0 else 0
func grenade_available()->bool:
 if grenade_count()<=0 or hand_clock<grenade_pending_until:return false
 var resident=rig.game.resident
 var state:Dictionary=resident.client_frame.get("players",{}).get(rig.game.multiplayer.get_unique_id(),{})
 return state.is_empty() or float(state.get("grenade_ready",0.))+resident.origin<=rig.game.clock
func tool_mount()->Transform3D:
 if rig.repair_cabin_passenger():return rig.game.battery_tanks.repair_tool_mount(rig.game.multiplayer.get_unique_id())
 var hip:Transform3D=preload("res://deathmatch/conquest/classes/hip_mount.gd").frame(rig.sample_raw_pose())
 return rig.global_transform*hip*Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3(.10 if rig.left_handed else -.10,.18,.24))
func box_mount()->Transform3D:return rig.shoulder_mount(false)
func box_available()->bool:
 var game=rig.game;var id:int=game.multiplayer.get_unique_id()
 return not rig.mounted_for_cq() and kind() in ["medical","engineering"] and hand_clock>=box_pending_until and game.classes.states.get(id,{}).get("dispenser_ready",0.)<=game.clock
func update_box(valid:bool)->void:
 var role:String=rig.game.classes.role(rig.game.multiplayer.get_unique_id())
 var available:bool=box_available()
 if available and (not is_instance_valid(box_model) or box_role!=role):
  if is_instance_valid(box_model):box_model.queue_free()
  box_model=preload("res://deathmatch/conquest/classes/models.gd").weapon(6,"cq_"+role);rig.add_child(box_model);box_role=role
  preload("res://tools/voxel_battle/baked_lighting.gd").convert_node(box_model)
 if is_instance_valid(box_model):
  box_model.visible=valid and available and (not held or box_mode)
  var pose:Transform3D=preload("res://deathmatch/vr/poses.gd").held_weapon(hand().global_transform,(rig.left_aim if hand_index==0 else rig.right_aim).global_transform) if held and box_mode else box_mount()
  box_model.global_transform=preload("res://deathmatch/art.gd").held_transform(pose,6,.65,"cq_"+role)
func update(delta:float,valid:bool)->void:
 hand_clock+=delta
 update_box(valid)
 var controllers:=[rig.left,rig.right]
 if not valid:
  reset();return
 for i in 2:
  var down:bool=controllers[i].get_float("grip")>.6
  var dragging:bool=rig.medic_interactions!=null and rig.medic_interactions.drag_hand==i
  var at_box:bool=box_available() and hand_clock>=box_pending_until and controllers[i].global_position.distance_to(box_mount().origin)<.20
  if not held and not dragging and down and not edges[i] and not rig.shoulder_radio.held and (not grenade() or grenade_available()) and (at_box or controllers[i].global_position.distance_to(tool_mount().origin if kind() in ["medical","engineering"] else rig.shoulder_mount(false).origin)<.25):
   box_mode=at_box
   hand_index=i;saved_weapon=rig.game.desired_weapon;armed=false;trigger_before=false;samples.clear();rig.cq_hands.holding=false
   if not grenade() and kind() not in ["recon","recon_drone"]:rig.game.desired_weapon=6 if box_mode else 7 if kind() in ["medical","engineering"] else 8
   rig.feedback(.3,.06,i!=(0 if rig.left_handed else 1))
  edges[i]=down
 if not held:return
 var active:XRController3D=hand();var grip:bool=active.get_float("grip")>.6;var trigger:bool=active.get_float("trigger")>.6
 var point:Vector3=active.position-rig.head.position
 samples.append({"at":hand_clock,"point":point})
 while samples.size()>2 and hand_clock-samples[0].at>.1:samples.pop_front()
 var speed:=0.
 if samples.size()>1:speed=point.distance_to(samples[0].point)/maxf(.001,hand_clock-samples[0].at)
 if box_mode and not grip:
  # Reliable release action identifies the physical hand; native physics carries
  # the box to the ground and only enables supply after it lands.
  rig.game.resident.request(0,6,hand_index+1);box_pending_until=hand_clock+.5
  release();return
 if grenade():
  update_guide()
  if trigger and not trigger_before and not armed:
   rig.game.resident.request(2,2+hand_index);armed=true;rig.feedback(.3,.06,hand_index!=(0 if rig.left_handed else 1))
   if rig.game.effects:rig.game.effects.play("cq_field_bolt_pull",active.global_position,-6)
  if armed and (not grip or not trigger and trigger_before and speed>1.4):
   rig.game.resident.request(3);grenade_pending_until=hand_clock+.65;release();return
 elif trigger and not trigger_before and kind() in ["recon","recon_drone"]:rig.game.resident.request(0)
 if not grip:
  if armed:rig.game.resident.request(4)
  release();return
 trigger_before=trigger
func release()->void:
 hand_index=-1;armed=false;box_mode=false;rig.game.desired_weapon=saved_weapon;rig.cq_hands.holding=false;samples.clear()
 if is_instance_valid(guide):guide.hide()
func decorate(command:Dictionary)->void:
 if not held:return
 if grenade():
  # Keep physical left/right identity stable across release. Native ARM carries
  # the throwing hand explicitly; the other tracked aim guides the trajectory.
  command.fire=false;command.alt_fire=false;command.offhand_fire=false;command.weapon_held=false;command.melee=false
  return
 var active:=hand();var aim:XRController3D=rig.left_aim if hand_index==0 else rig.right_aim
 var pose:Dictionary=command.xr
 if pose.is_empty():return
 pose=pose.duplicate();pose.left_handed=hand_index==0;pose.weapon=rig.origin.transform*(preload("res://deathmatch/avatars/equipment.gd").injector_pose(active.transform) if kind()=="medical" and not box_mode else preload("res://deathmatch/vr/poses.gd").held_weapon(active.transform,aim.transform))
 var other:XRController3D=rig.right if hand_index==0 else rig.left;var other_aim:XRController3D=rig.right_aim if hand_index==0 else rig.left_aim
 pose.offhand_weapon=rig.origin.transform*preload("res://deathmatch/vr/poses.gd").held_weapon(other.transform,other_aim.transform)
 command.xr=preload("res://deathmatch/vr/poses.gd").validate(pose)
 command.weapon=rig.game.desired_weapon;command.weapon_held=true
 command.fire=not box_mode and kind() not in ["recon","recon_drone"] and not grenade() and active.get_float("trigger")>.6 and not command.input_blocked
 command.reload=false;command.reload_grip=false;command.reload_trigger=false;command.offhand_fire=false;command.alt_fire=false;command.melee=false;command.cq_drag=false

func update_guide()->void:
 if not is_instance_valid(guide):
  guide=MeshInstance3D.new();guide.mesh=ImmediateMesh.new();rig.add_child(guide);guide.top_level=true;guide.global_transform=Transform3D.IDENTITY
  var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("e8c46c");guide.material_override=material;guide.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var other:XRController3D=rig.right if hand_index==0 else rig.left
 var other_aim:XRController3D=rig.right_aim if hand_index==0 else rig.left_aim
 var mesh:ImmediateMesh=guide.mesh;mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
 mesh.surface_add_vertex(other.global_position);mesh.surface_add_vertex(other.global_position-other_aim.global_basis.z*1.2);mesh.surface_end();guide.show()
