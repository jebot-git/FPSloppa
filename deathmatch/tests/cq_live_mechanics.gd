extends SceneTree
const Models=preload("res://deathmatch/conquest/classes/models.gd")
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();root.add_child(game)
 game.start_host("Live mechanics QA",0,200,10,true,"tdm","ut99");game.set_process(false);game.set_physics_process(false)
 if not game.hud:
  game.hud=load("res://deathmatch/interface.gd").new();game.add_child(game.hud);game.hud.setup(game)
 var rig=preload("res://deathmatch/vr/rig.gd").new();game.add_child(rig);rig.setup(game,true);game.xr_rig=rig;rig.set_process(false);rig.calibration_pending=false
 rig.head.position=Vector3(0,1.65,0);game.menu_open=false;rig.focused=true
 var id:int=game.multiplayer.get_unique_id()
 check(preload("res://deathmatch/settings/bindings.gd").new().physical_transport_steering,"VR transport steering defaults to physical wheel control")
 for hand_model in rig.hand_models:
  check(not hand_model.top_level and not hand_model.is_physics_processing(),"tracked glove follows render-time controller without XRTools physics override")
 for pair in [["medic","medical","injector"],["technician","engineering","repair_kit"]]:
  game.classes.ensure(id)["class"]=pair[0];game.classes.states[id].equipped_utility=pair[1]
  check(Models.entry(7,"cq_"+pair[0])==pair[2],"specialist model is class specific: "+pair[0])
  rig.update_shoulder_utility(true);rig.cq_utility.update_box(true)
  var mount:Transform3D=rig.cq_utility.tool_mount()
  var hip:Transform3D=preload("res://deathmatch/conquest/classes/hip_mount.gd").frame(rig.sample_raw_pose())
  var offset:Vector3=hip.affine_inverse()*(rig.global_transform.affine_inverse()*mount.origin)
  check(offset.z>.2 and is_equal_approx(offset.y,.18),"specialist tool mounts behind hip: "+pair[0])
  check(rig.shoulder_utility.global_position.distance_to(mount.origin)<.001,"visible tool matches reachable hip mount")
  check(rig.cq_utility.box_model.visible and rig.cq_utility.box_model.global_position.distance_to(rig.shoulder_mount(false).origin)<.001,"class box is visible on shoulder")
  rig.cq_utility.hand_index=0;rig.cq_utility.box_mode=false;rig.cq_utility.saved_weapon=4;game.desired_weapon=7
  var command:Dictionary={"xr":rig.sample_pose(),"input_blocked":false}
  rig.cq_utility.decorate(command)
  check(command.weapon==7 and command.weapon_held and not command.xr.is_empty(),"held specialist uses utility slot and valid tracked pose")
  rig.cq_utility.release()
 for utility in [["technician","turret",6],["shocktroop","airstrike",8]]:
  game.classes.ensure(id)["class"]=utility[0];game.classes.states[id].equipped_utility=utility[1]
  rig.cq_utility.hand_index=0;rig.cq_utility.box_mode=false
  var tool:Dictionary={"xr":rig.sample_pose(),"input_blocked":false}
  rig.cq_utility.decorate(tool)
  check(tool.weapon==utility[2] and tool.weapon_held,"held utility routes correct native slot: "+utility[1])
  rig.update_shoulder_utility(true)
  if utility[1]=="turret":check(rig.shoulder_utility.find_child("Aim",true,false)!=null,"carried sentry uses turret geometry")
  rig.cq_utility.release()
 # Verify the actual CQ render hook, rather than calling tool rendering directly.
 game.headless=false
 game.classes.dispensers[900001]={"kind":"health","position":Vector3(2,0,1),"remaining":400}
 game.classes.dispensers[900002]={"kind":"ammo","position":Vector3(3,0,1),"remaining":400}
 game.match_mode.draw_objectives()
 for key in [900001,900002]:
  var box:Node3D=game.class_visuals.get("box"+str(key))
  check(is_instance_valid(box) and box.visible and box.position==game.classes.dispensers[key].position,"CQ render hook shows deployed class box: "+str(key))
 game.classes.dispensers.erase(900001);game.classes.dispensers.erase(900002);game.match_mode.draw_objectives()
 check(not game.class_visuals.has("box900001") and not game.class_visuals.has("box900002"),"removed native supplies remove rendered boxes")
 game.headless=true
 var actor=game.fighters[id]
 actor.receive_locomotion({"incapacitated":true,"height":.65});actor.show_alive(true,true)
 check(actor.collision_layer==0 and actor.collision_mask==1,"client incapacitated body keeps world collision without blocking players")
 actor.receive_locomotion({"incapacitated":false,"height":1.65});actor.show_alive(true,true)
 check(actor.collision_layer==2 and actor.collision_mask==3,"client revived body restores normal collision")
 # A technician sees repair status while holding the tool, including cabin access.
 game.classes.ensure(id)["class"]="technician";game.classes.states[id].equipped_utility="engineering"
 rig.cq_utility.hand_index=0;rig.cq_utility.box_mode=false;game.desired_weapon=7
 var vehicle_key:int=game.battery_tanks.rows.keys().filter(func(k):return game.battery_tanks.rows[k].kind=="transport")[0]
 var original:Dictionary=game.battery_tanks.rows[vehicle_key].duplicate(true)
 var vehicle:Dictionary=game.battery_tanks.rows[vehicle_key]
 vehicle.hp=40.;vehicle.team=game.players[id].team;vehicle.position=rig.head.global_position+Vector3(0,-1,-3);vehicle.visual_y=vehicle.position.y
 game.battery_tanks.rendered_rows[vehicle_key]=vehicle
 game.battery_tanks.repair_status.update(game.battery_tanks)
 var bar:Node3D=game.battery_tanks.repair_status.bars.get(vehicle_key)
 check(is_instance_valid(bar) and bar.visible and "40 / 100 HP" in bar.get_node("Value").text,"held repair tool reveals nearby transport health")
 rig.cq_utility.release();game.battery_tanks.repair_status.update(game.battery_tanks)
 check(not bar.visible,"vehicle health bar hides when repair tool is released")
 vehicle.seats[7]=id
 check(rig.repair_cabin_passenger(),"front cabin technician can access repair equipment")
 var fixed_mount:Transform3D=rig.cq_utility.tool_mount()
 var saved_head:Transform3D=rig.head.transform;var saved_rig:Transform3D=rig.global_transform
 rig.head.position+=Vector3(.15,.05,-.1);rig.head.rotate_y(.4);rig.global_position+=Vector3(2,0,3)
 check(rig.cq_utility.tool_mount().is_equal_approx(fixed_mount),"cabin repair mount stays fixed on the dashboard through tracked head motion")
 rig.head.transform=saved_head;rig.global_transform=saved_rig
 for i in 2:rig.hand_models[i].transform=Transform3D.IDENTITY
 var cabin_view=preload("res://deathmatch/conquest/classes/battery_view.gd").new();game.add_child(cabin_view);cabin_view.setup(game,game.battery_tanks);cabin_view.set_process(false);cabin_view.lock_transport_view()
 for i in 2:
  var controller=rig.left if i==0 else rig.right
  check(rig.hand_models[i].global_transform.is_equal_approx(controller.global_transform),"free cabin passenger hand follows late seat correction")
 cabin_view.queue_free();rig.global_transform=saved_rig
 rig.update_shoulder_utility(true)
 check(rig.shoulder_utility.visible and not rig.cq_utility.box_available(),"cabin exposes repair tool while preserving box deployment restriction")
 vehicle.seats[7]=0;vehicle.seats[0]=id
 check(not rig.repair_cabin_passenger(),"side pod keeps ordinary equipment restrictions")
 game.battery_tanks.repair_status.clear();check(game.battery_tanks.repair_status.bars.is_empty(),"vehicle reset clears repair status displays")
 game.battery_tanks.rows[vehicle_key]=original;game.battery_tanks.rendered_rows.erase(vehicle_key)
 # The medic's visible handle shares the native prone contact region.
 var marker_rig_pose:Transform3D=rig.global_transform;rig.global_position=Vector3(0,1000,0)
 var patient_id:=223;game._add_player(patient_id,"Drag target")
 game.players[patient_id].dead=false;game.players[patient_id].spectator=false;game.players[patient_id].team=game.players[id].team
 game.fighters[patient_id].position=rig.head.global_position+Vector3(0,-1.65,-.8)
 game.classes.ensure(id)["class"]="medic";game.classes.states[id].equipped_utility="medical";game.classes.downed[patient_id]={"remaining":10.}
 game.medic_drag_points.draw(game)
 var point:Node3D=game.medic_drag_points.points.get(patient_id)
 check(is_instance_valid(point) and point.visible,"nearby incapacitated ally has a medic drag handle")
 var contact:Vector3=preload("res://deathmatch/conquest/classes/patient_geometry.gd").contact(game.fighters[patient_id].render_position(),game.fighters[patient_id].damage_yaw(),point.global_position)
 check(point.global_position.distance_to(contact)<.6,"visible medic drag handle lies inside the real grip reach")
 game.classes.downed.erase(patient_id);game.medic_drag_points.draw(game)
 check(not game.medic_drag_points.points.has(patient_id),"revival removes the medic drag handle")
 rig.global_transform=marker_rig_pose
 game.fighters[patient_id].queue_free();game.fighters.erase(patient_id);game.players.erase(patient_id);game.classes.states.erase(patient_id)
 var launcher:Node3D=Models.weapon(11,"cq_technician");rig.add_child(launcher);launcher.scale=Vector3.ONE*.65
 var panel=launcher.get_node("GuidanceMonitor")
 panel.update_guidance(launcher,{"elapsed":.75},{},0.)
 check(panel.global_transform.is_equal_approx(launcher.global_transform*Transform3D(Basis.IDENTITY,Models.anchor(11,"monitor_position"))),"T2 guidance panel sits on authored monitor glass at weapon scale")
 launcher.global_position+=Vector3(.1,.2,-.2);launcher.rotate_y(.3)
 check(panel.global_transform.is_equal_approx(preload("res://deathmatch/vr/weapon_display.gd").mount(launcher)),"monitor text follows late gun tracking and recoil without a frame of lag")
 check(panel.screen.mesh.size.x*launcher.scale.x<.064 and panel.screen.mesh.size.y*launcher.scale.y<.043 and panel.label.text=="ACQUIRING\n050%\nHOLD AIM","T2 status fits the physical monitor bezel")
 launcher.queue_free()
 var cell_pose:Transform3D=preload("res://deathmatch/avatars/equipment.gd").cloak_held_pose(Transform3D.IDENTITY)
 check(cell_pose.basis.y.is_equal_approx(Vector3.FORWARD) and cell_pose.basis.get_scale().is_equal_approx(Vector3.ONE),"cloak cell follows thumb axis at authored eighteen-centimetre size")
 var aim=preload("res://deathmatch/vr/aim_support.gd").new()
 for w in [0,2,9]:
  var primary:=Transform3D(Basis(Vector3.UP,.2),Vector3(.2,1.2,-.3));var support:=primary*Transform3D(Basis.IDENTITY,Vector3(0,-.04,-.07))
  var solved:Transform3D=aim.solve(primary,support,w,true,true,"cq",false)
  check(aim.engaged and solved.basis.is_equal_approx(primary.basis),"pistol support preserves wrist angle: "+str(w))
 rig.place_menu();var relative:Transform3D=rig.global_transform.affine_inverse()*rig.panel.global_transform
 rig.global_position+=Vector3(3,0,-4);rig.rotate_y(.5);rig.follow_menu()
 check((rig.global_transform.affine_inverse()*rig.panel.global_transform).is_equal_approx(relative),"menu follows locomotion and body yaw without following head jitter")
 var scope=preload("res://deathmatch/vr/sniper_scope.gd").new();rig.add_child(scope);scope.setup(rig);var model:Node3D=Models.weapon(9,"cq_scout");rig.add_child(model);scope.attach(model)
 check(scope.camera.cull_mask&(1<<18)==0,"scope camera excludes HUD layer")
 rig.sniper_scope=scope;scope.active=true;rig.status_surface.show();rig.update_scope_visibility();check(not rig.status_surface.visible,"scope hides stereo status surface")
 var data:Dictionary={"life":1,"seq":1,"move":Vector2.ZERO,"yaw":0.,"pitch":0.,"weapon":2,"fire":false,"jump":false,"reload":false,"slow":false,"crouch":false,"prone":false,"blocked":false,"xr":preload("res://deathmatch/vr/poses.gd").neutral(),"vr_device":true,"swim":Vector3(.2,.3,-.8),"view_time":0.,"jump_event":0}
 data.xr.offhand_weapon=data.xr.left
 var wire:PackedByteArray=Codec.encode_input(data)
 check(wire.size()==322 and wire.slice(0,4).get_string_from_ascii()=="CQI3","tracked swim wire includes rewind, redundant events and both hands")
 check(Vector3(wire.decode_float(310),wire.decode_float(314),wire.decode_float(318)).distance_to(data.swim)<.00001,"swim stroke survives wire encoding")
 game.players[id].weapon=5;game.clock=10.;game.variant_combat.charges[id]={"at":10.175}
 check("CHARGING 050%" in game.variant_combat.charge_label(id),"native timestamp drives Massacre charging readout")
 for w in [1,4]:
  var gun:Node3D=Models.weapon(w,"cq_shocktroop");rig.add_child(gun);var dot:Node3D=gun.find_child("AlignedRedDot",true,false)
  var metadata:Dictionary=Models.metadata(w,"cq_shocktroop");var p:Array=metadata.red_dot_position
  check(dot.position.distance_to(Vector3(p[0],p[1],p[2]+.001))<.00001,"reticle matches authored rear glass: "+str(w))
  check(dot.get_meta("zero_metres")==50.,"red dot has explicit 50 m zero")
  gun.queue_free()
 var map:OpenXRActionMap=load("res://deathmatch/vr/actions.tres")
 check(map.action_sets[0].get_actions().any(func(a):return a.resource_name=="eye_gaze_pose"),"eye gaze action exists for runtime foveation")
 # Exercise production mounted command generation with the simulated rig.
 game.players[id].weapon=4;game.desired_weapon=4;game.players[id].dead=false;game.players[id].spectator=false
 var key:int=game.battery_tanks.rows.keys()[0];game.battery_tanks.rows[key].pilot=id
 var sampled:Dictionary=game._local_command()
 check(sampled.has("seq") and sampled.has("weapon") and sampled.has("fire"),"mounted command generation returns complete input without wheel API")
 game.battery_tanks.rows[key].pilot=0
 print("CQ_LIVE_MECHANICS ",JSON.stringify({"checks":checks,"failures":failures}))
 game.disconnect_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
