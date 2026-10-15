extends SceneTree
const Models=preload("res://deathmatch/conquest/classes/models.gd")
const Art=preload("res://deathmatch/art.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize():run.call_deferred()
func run():
 var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();root.add_child(game)
 game.start_host("VR port QA",0,200,10,true,"tdm","ut99");game.set_process(false);game.set_physics_process(false)
 if not game.hud:
  game.hud=load("res://deathmatch/interface.gd").new();game.add_child(game.hud);game.hud.setup(game)
 if not game.xr_rig:
  game.xr_rig=preload("res://deathmatch/vr/rig.gd").new();game.add_child(game.xr_rig);game.xr_rig.setup(game,true)
 elif not game.xr_rig.enabled:game.xr_rig.setup(game,true)
 var rig=game.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.head.position=Vector3(0,1.65,0)
 var raw:=Transform3D(Basis(Vector3.UP,.3),Vector3(.55,1.4,.3))
 check(rig.attached_hand(false,raw).is_equal_approx(raw),"first-person hands bypass avatar IK and vertex bobbing")
 var before:Transform3D=rig.shoulder_mount(false);rig.head.position+=Vector3(.2,.15,-.1)
 check((rig.shoulder_mount(false).origin-before.origin).distance_to(rig.origin.global_basis*Vector3(.2,.15,-.1))<.00001,"body attachments follow headset translation")
 XRServer.world_scale=1.2;rig.recenter();check(is_equal_approx(XRServer.world_scale,1.),"calibration preserves metre-scale world and tank dimensions")
 check(is_instance_valid(rig.cq_hands.bag),"physical ammunition pouch exists")
 var chest:Vector3=rig.cq_hands.mount(true).origin;var hip:Vector3=rig.cq_hands.mount(false).origin
 rig.cq_hands.sample_hold([4,2],chest,false,true);rig.cq_hands.sample_hold([4,2],chest,true,true)
 check(rig.cq_hands.holding and game.desired_weapon==4,"gripping chest mount draws primary")
 rig.cq_hands.sample_hold([4,2],chest,false,true)
 check(not rig.cq_hands.holding,"releasing gun returns it to holster")
 rig.cq_hands.sample_hold([4,2],hip,true,true)
 check(rig.cq_hands.holding and game.desired_weapon==2,"hip grip swaps directly to secondary")
 rig.cq_hands.reset()
 var command:Dictionary={"life":1,"seq":1,"move":Vector2.ZERO,"yaw":0.,"pitch":0.,"weapon":4,"fire":true,"jump":false,"reload":false,"slow":false,"crouch":false,"prone":false,"blocked":false,"vr_device":true,"weapon_held":false}
 var protocol=preload("res://deathmatch/native/authority_protocol.gd")
 var wire:PackedByteArray=protocol.encode_input(command)
 check(wire.size()==48 and wire.decode_u16(30)&24576==8192,"released grip is explicit in bounded input wire")
 command.weapon_held=true;wire=protocol.encode_input(command)
 check(wire.decode_u16(30)&24576==24576,"drawn grip is explicit in bounded input wire")
 check(rig.virtual_stock_enabled,"virtual stock port enabled")
 for w in [0,1,2,3,4,9,10]:
  var model:Node3D=Models.weapon(w,"cq_shocktroop");root.add_child(model)
  var well=model.find_child("InsertedAmmo",true,false);var lever=model.find_child("ChargingHandle",true,false)
  check(well!=null and well.position.distance_to(Models.anchor(w,"magazine_anchor"))<.00001,"authored magazine anchor %d"%w)
  check(lever!=null and lever.position.distance_to(Models.anchor(w,"rack_anchor"))<.00001,"authored charging lever %d"%w)
  check((Art.held_transform(raw,w,Art.VR_SCALE,"cq_shocktroop")*Art.muzzle(w,"cq_shocktroop")).distance_to(raw* (Models.muzzle(w,"cq_shocktroop")*.65))<.00001,"model/barrel world origin %d"%w)
  model.queue_free()
 var scope=load("res://deathmatch/vr/sniper_scope.gd").new();root.add_child(scope)
 var pistol=Models.weapon(9,"cq_scout");root.add_child(pistol);var other=Models.weapon(1,"cq_shocktroop");root.add_child(other)
 scope.attach(pistol);scope.zoom_index=2;scope.attach(other);scope.attach(pistol)
 check(scope.zoom_index==2,"optic zoom survives holster/model attachment changes")
 for kind in ["light","heavy"]:
  var tank=load("res://deathmatch/models/hover_tanks/"+kind+".glb").instantiate()
  var bounds:AABB=game.battery_tanks.normalise_model(tank)
  check(absf(bounds.position.y+tank.position.y)<.0001 and absf(bounds.get_center().x+tank.position.x)<.0001,"tank floor origin and centre "+kind);tank.free()
 var tag=preload("res://deathmatch/ui/colored_nametag.gd").new();root.add_child(tag);tag.fixed_size=true;tag.set_player_name("^1Red ^4Blue",0,Color.RED)
 check(tag.pieces.size()>=2 and tag.pieces.all(func(p):return p.fixed_size),"coloured name runs preserve VR size")
 var count:int=tag.pieces.size();tag.set_player_name("^1Red ^4Blue",0,Color.RED);check(tag.pieces.size()==count,"unchanged name reuses labels")
 check(game.music==null or game.music.players.is_empty(),"CQ has ambience without soundtrack")
 var remote:=909;game.players[remote]=game._new_state("Remote holster QA",remote);game.players[remote].owned=[4,2];game.players[remote].weapon=4
 game.players[remote].xr={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left_handed":false}
 game._create_fighter(remote);game.fighters[remote].set_physics_process(false);game.fighters[remote].set_process(false)
 game.classes.ensure(remote).weapon_held=false
 var holsters=preload("res://deathmatch/conquest/classes/holster_visuals.gd").new();game.add_child(holsters);holsters.setup(game);holsters.draw()
 check(holsters.rows.size()==2 and holsters.rows.values().all(func(r):return r.node.visible),"released remote weapon returns to body mounts")
 var remote_gun:Node3D=game.fighters[remote].avatar.get_node("Upper/WeaponModel")
 check(not remote_gun.visible,"remote hand weapon hides on grip release")
 game.classes.states[remote].weapon_held=true;holsters.draw()
 check(not holsters.rows[str(remote)+":0"].node.visible and holsters.rows[str(remote)+":1"].node.visible and remote_gun.visible,"remote draw shows held primary and holstered secondary")
 game.fighters[remote].queue_free();game.fighters.erase(remote);game.players.erase(remote);game.classes.states.erase(remote);holsters.draw()
 check(holsters.rows.is_empty(),"departed remote holster models are released")
 holsters.queue_free()
 var was_headless:bool=game.headless;game.headless=false
 game.loadout_menu=load("res://deathmatch/conquest/classes/loadout_menu.gd").new();game.add_child(game.loadout_menu);game.loadout_menu.setup(game,game.hud)
 game.loadout_menu.begin_deployment()
 check(game.loadout_menu.pending and game.menu_open and game.loadout_menu.deploy_button.disabled,"deployment waits for player preparation and confirmation")
 game.loadout_menu.choose_class("medic")
 check(game.classes.ensure(game.multiplayer.get_unique_id()).next=="medic","class choice is available before deployment")
 var preview=preload("res://deathmatch/vr/calibration_preview.gd").new();root.add_child(preview);preview.setup(game);preview._process(0.)
 check(is_instance_valid(preview.preview),"calibration submenu creates a separate local avatar preview")
 check(preview.viewport.world_3d!=root.world_3d,"preview uses a private render world")
 for button in preview.get_children():
  if button is Button and button.text=="CONFIRM AVATAR ALIGNMENT":button.pressed.emit()
 check(game.loadout_menu.calibration_confirmed and not game.loadout_menu.deploy_button.disabled,"confirming local avatar alignment enables deployment")
 var selected_skin:String=game.avatars.library.selected
 game.avatars.library.selected="changed-skin";game.loadout_menu.refresh()
 check(not game.loadout_menu.calibration_confirmed and game.loadout_menu.deploy_button.disabled,"changing skin invalidates previous avatar confirmation")
 game.avatars.library.selected=selected_skin
 for button in preview.get_children():
  if button is Button and button.text=="CONFIRM AVATAR ALIGNMENT":button.pressed.emit()
 for button in preview.get_children():
  if button is Button and button.text=="CALIBRATE / RECENTER":button.pressed.emit()
 check(not game.loadout_menu.calibration_confirmed and game.loadout_menu.deploy_button.disabled,"recalibration requires renewed avatar confirmation")
 if OS.get_cmdline_user_args().has("--capture"):
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  preview.viewport.get_texture().get_image().save_png("/tmp/cq-calibration-preview.png")
 preview.queue_free();game.headless=was_headless
 # A parented camera must stream POIs around its world location, not tracking-space zero.
 var structures=preload("res://tools/streamed_heightfield/structures.gd").new();root.add_child(structures)
 structures.setup();structures.culling_enabled=false
 var parent:=Node3D.new();root.add_child(parent);parent.position=structures.placements[0].position
 var camera:=Camera3D.new();parent.add_child(camera);camera.position=Vector3(0,1.65,0);structures.update(camera)
 check(structures.visible_sites>0,"parented XR camera streams nearby static structures")
 scope.queue_free();pistol.queue_free();other.queue_free();tag.queue_free();structures.queue_free();parent.queue_free()
 game.disconnect_game();game.queue_free();await process_frame;await process_frame
 print("CQ_VR_PORT_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
