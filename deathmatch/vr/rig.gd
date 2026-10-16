extends Node3D
const Poses=preload("res://deathmatch/vr/poses.gd")
const Art=preload("res://deathmatch/art.gd")
const W=preload("res://deathmatch/weapons.gd")
const RoomScale=preload("res://deathmatch/vr/room_scale.gd")
const Preferences=preload("res://deathmatch/vr/preferences.gd")
const UI_LAYER := 1<<22
var control_edges: Dictionary={}
var aim_guides: Array=[]
var physical_actions=preload("res://deathmatch/vr/physical_actions.gd").new()
var shoulder_radio=preload("res://deathmatch/vr/shoulder_radio.gd").new()
var support_aim=preload("res://deathmatch/vr/aim_support.gd").new()
var swim_detector=preload("res://deathmatch/vr/swim_strokes.gd").new()
var swim_input:=Vector3.ZERO
var shoulder_utility:Node3D
var shoulder_utility_key:=""
var calibration_pose=preload("res://deathmatch/vr/t_pose.gd").new()
var crouch_detector=preload("res://deathmatch/vr/physical_crouch.gd").new()
var crouch_height:=1.65
var jump_detector=preload("res://deathmatch/vr/physical_jump.gd").new()
var game
var enabled:=false
var simulated:=false
var origin: XROrigin3D
var head: XRCamera3D
var left: XRController3D
var right: XRController3D
var left_aim: XRController3D
var right_aim: XRController3D
var pointers: Array=[]
var hand_models: Array=[]
var hand_animators: Array=[]
var panel
var keyboard
var status_surface: MeshInstance3D
var status_hud
var turn_panel
var damage_overlay: MeshInstance3D
var damage_material: ShaderMaterial
var blackout: MeshInstance3D
var gun: Node3D
var offhand_gun: Node3D
var gun_id:=-1
var gun_rules:=""
var sniper_scope
var origin_offset:=Vector3.ZERO
var turn_latched:=false
var cycle_latched:=false
var scores:=false
var left_handed:=false
var left_controls:=false
var seated:=false
var seated_active:=false
var seated_height_offset:=0.0
var smooth_turn:=true
var turn_speed:=120.0
var snap_angle:=30.0
var last_panel:=false
var focused:=true
var cq_utility
var cq_hands
var transport_wheel
var medic_interactions
var virtual_stock=preload("res://deathmatch/vr/virtual_stock.gd").new()
var virtual_stock_enabled:=true
var weapon_kick=preload("res://deathmatch/vr/weapon_kick.gd").new()
var calibration_pending:=true
func setup(arena: Node, test_mode: bool=false) -> bool:
	physical_actions.setup(self);shoulder_radio.setup(self)
	game=arena
	simulated=test_mode
	var xr:=XRServer.find_interface("OpenXR")
	if simulated and xr and xr.is_initialized(): xr.uninitialize()
	if not simulated and (not xr or not xr.is_initialized()): return false
	enabled=true
	if game.has_method("draw_class_players"):
		cq_hands=preload("res://deathmatch/vr/cq_hands.gd").new();add_child(cq_hands);cq_hands.setup(self)
		medic_interactions=preload("res://deathmatch/vr/medic_interactions.gd").new();medic_interactions.setup(self)
		transport_wheel=preload("res://deathmatch/vr/transport_wheel.gd").new();transport_wheel.setup(self)
		cq_utility=preload("res://deathmatch/vr/cq_utility.gd").new();cq_utility.setup(self)
	var settings:=Preferences.read_settings()
	smooth_turn=settings.smooth_turn;turn_speed=settings.turn_speed;snap_angle=settings.snap_angle
	left_controls=settings.left_controls;seated=settings.seated;virtual_stock_enabled=settings.get("virtual_stock",true)
	origin=XROrigin3D.new()
	origin.name="Origin"
	add_child(origin)
	head=XRCamera3D.new()
	head.name="Head"
	head.near=.04
	origin.add_child(head)
	setup_controllers()
	for item in [[left,"left"],[right,"right"]]:
		var hand_model=load("res://addons/godot-xr-tools/hands/scenes/lowpoly/"+item[1]+"_tac_glove_low.tscn").instantiate()
		item[0].add_child(hand_model)
		if game.has_method("draw_class_players"):
			# CQ owns tracked attachment poses. XRTools' physics driver detaches the
			# glove from the controller and otherwise overwrites the late cabin pose.
			hand_model.set_physics_process(false);hand_model.top_level=false;hand_model.transform=Transform3D.IDENTITY
		hand_models.append(hand_model)
		if game.has_method("draw_class_players"):preload("res://tools/voxel_battle/baked_lighting.gd").convert_node(hand_model)
		var fingers=preload("res://deathmatch/vr/glove_fingers.gd").new()
		fingers.setup(hand_model,item[1])
		hand_animators.append(fingers)
		var pointer=load("res://addons/godot-xr-tools/functions/function_pointer.tscn").instantiate()
		pointer.distance=6
		pointer.hand_offset_mode=4 # Aim nodes already supply the runtime's exact pose.
		pointer.y_offset=0
		pointer.collision_mask=UI_LAYER
		pointer.laser_length=1 # Stop at the closest menu/keyboard surface.
		pointer.show_target=true
		pointer.target_radius=.008
		var pointer_material:=StandardMaterial3D.new()
		pointer_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		pointer_material.no_depth_test=true
		pointer_material.render_priority=101
		pointer_material.albedo_color=Color("80f2e6")
		pointer.laser_material=pointer_material
		pointer.target_material=pointer_material
		(left_aim if item[1]=="left" else right_aim).add_child(pointer)
		pointers.append(pointer)
	left.button_pressed.connect(left_button)
	right.button_pressed.connect(right_button)
	if not simulated:
		get_viewport().physics_object_picking=false # VR menu pointers perform their own ray tests.
		get_viewport().use_xr=true
		# Presentation preferences configure VRS once the rig is ready.
		get_viewport().vrs_mode=Viewport.VRS_DISABLED
		if xr.has_signal("session_begun"): xr.connect("session_begun",configure_refresh_rate)
		print("XR_RUNTIME ",JSON.stringify(xr.get_system_info()))
		configure_refresh_rate()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		if xr.has_signal("session_focussed"): xr.connect("session_focussed",func(): focused=true)
		if xr.has_signal("session_visible"): xr.connect("session_visible",func(): focused=false)
	else:
		head.position=Vector3(0,1.65,0)
		left.position=Vector3(-.25,1.2,-.4)
		right.position=Vector3(.25,1.2,-.4)
		left_aim.transform=left.transform
		right_aim.transform=right.transform

	build_ui()
	head.make_current()
	game.camera=head
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	print("XR_READY ","simulated" if simulated else "OpenXR")
	return true
func setup_controllers() -> void:
	# OpenXRInterface maps *_pose action names to these built-in tracker names.
	left=controller("Left","left_hand","grip")
	right=controller("Right","right_hand","grip")
	left_aim=controller("LeftAim","left_hand","aim")
	right_aim=controller("RightAim","right_hand","aim")
func controller(node_name: String,tracker_name: String,pose_name: String) -> XRController3D:
	var c:=XRController3D.new()
	c.name=node_name
	c.tracker=tracker_name
	c.pose=pose_name
	origin.add_child(c)
	return c
func build_ui() -> void:
	panel=load("res://addons/godot-xr-tools/objects/viewport_2d_in_3d.tscn").instantiate()
	panel.name="VRMenu"
	panel.top_level=true
	panel.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	panel.screen_size=Vector2(1.9,1.425)
	panel.viewport_size=Vector2(1280,960)
	panel.collision_layer=UI_LAYER
	panel.unshaded=true
	var ui_material:=StandardMaterial3D.new()
	ui_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ui_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	ui_material.no_depth_test=true
	ui_material.render_priority=100
	panel.material=ui_material
	add_child(panel)
	game.hud.reparent(panel.get_node("Viewport"))
	var ui_root: Control=game.hud.get_child(0)
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui_root.size=panel.viewport_size/1.5
	ui_root.scale=Vector2.ONE*1.5
	keyboard=load("res://addons/godot-xr-tools/objects/virtual_keyboard.tscn").instantiate()
	keyboard.top_level=true
	keyboard.scene=preload("res://deathmatch/vr/keyboard.tscn")
	keyboard.screen_size=Vector2(1.4,.5)
	keyboard.collision_layer=UI_LAYER
	keyboard.input_keyboard=false
	keyboard.material=ui_material.duplicate()
	add_child(keyboard)
	keyboard.get_scene_instance().focus_target=focused_edit
	var status_viewport:=SubViewport.new()
	status_viewport.size=preload("res://deathmatch/vr/status_hud.gd").VIEW_SIZE
	status_viewport.transparent_bg=true
	status_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(status_viewport)
	status_hud=preload("res://deathmatch/vr/status_hud.gd").new()
	if game.has_method("draw_class_players"):status_hud.configure_cq()
	status_hud.size=Vector2(status_viewport.size);status_hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	status_viewport.add_child(status_hud)
	status_surface=MeshInstance3D.new();status_surface.layers=1<<18
	var status_quad:=QuadMesh.new();status_quad.size=Vector2(status_viewport.size)*.001
	# Extend upwards for chat without moving or shrinking the existing HUD.
	status_quad.center_offset.y=(status_hud.KILLFEED_HEIGHT+status_hud.CHAT_HEIGHT+status_hud.NOTIFY_HEIGHT)*.0005
	status_surface.mesh=status_quad;status_surface.position=Vector3(0,-.46,-1.5)
	status_surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var status_material:=StandardMaterial3D.new()
	status_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	status_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	status_material.no_depth_test=true;status_material.render_priority=105
	status_material.albedo_texture=status_viewport.get_texture()
	status_surface.material_override=status_material
	head.add_child(status_surface)
	status_surface.hide()
	apply_hud_preferences(game.presentation)

	turn_panel=preload("res://deathmatch/vr/turn_panel.gd").new()
	ui_root.add_child(turn_panel);turn_panel.setup(self)
	blackout=MeshInstance3D.new();blackout.layers=1<<18
	var sphere:=SphereMesh.new()
	sphere.radius=.08
	sphere.height=.16
	blackout.mesh=sphere
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode=BaseMaterial3D.CULL_FRONT
	material.albedo_color=Color.BLACK
	blackout.material_override=material
	head.add_child(blackout)
	blackout.visible=false
	damage_overlay=MeshInstance3D.new();damage_overlay.layers=1<<18
	damage_overlay.mesh=QuadMesh.new()
	damage_overlay.mesh.size=Vector2(2,2)
	damage_overlay.position.z=-.1
	damage_overlay.extra_cull_margin=1
	damage_overlay.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	damage_material=ShaderMaterial.new()
	damage_material.shader=preload("res://deathmatch/vr/damage.gdshader")
	damage_material.render_priority=120
	damage_overlay.material_override=damage_material
	head.add_child(damage_overlay)
	damage_overlay.hide()
	place_menu()
func apply_hud_preferences(values: Dictionary) -> void:
	if not is_instance_valid(status_surface):return
	var bounds=preload("res://deathmatch/vr/preferences.gd")
	status_surface.scale=Vector3.ONE*bounds.bounded(values.get("hud_scale",1.0),.7,1.4,1.0)
	status_surface.position=Vector3(0,bounds.bounded(values.get("hud_y",-.46),-.65,.55,-.46),-1.5)

var menu_mount:=Transform3D.IDENTITY
func place_menu() -> void:
	if not panel: return
	var yaw:=head.global_rotation.y
	panel.global_transform=Transform3D(Basis(Vector3.UP,yaw),head.global_position+Basis(Vector3.UP,yaw)*Vector3(0,-.05,-1.8))
	menu_mount=global_transform.affine_inverse()*panel.global_transform
	keyboard.global_transform=panel.global_transform*Transform3D(Basis(Vector3.RIGHT,-.2),Vector3(0,-1.0,.15))
func recenter() -> void:
	support_aim.reset();jump_detector.reset();crouch_detector.reset();swim_detector.reset();swim_input=Vector3.ZERO
	if not enabled: return
	if seated:
		# Translate the tracking space, preserving real-world reach and movement.
		var physical_height:=head.position.y/XRServer.world_scale
		XRServer.world_scale=1.0
		seated_height_offset=clampf(1.65-physical_height,-.5,1.4)
	elif game.has_method("draw_class_players"):
		XRServer.world_scale=1.0
	elif not simulated and head.position.y>.5:
		XRServer.world_scale=clampf(XRServer.world_scale*1.65/head.position.y,.65,1.5)
	origin_offset=Vector3(-head.position.x,0,-head.position.z)
	origin.position.x=origin_offset.x;origin.position.z=origin_offset.z
	calibration_pending=false
	place_menu()
func on_spawn() -> void:
	physical_actions.reset();shoulder_radio.reset();weapon_kick.reset();virtual_stock.reset()
	if cq_hands:cq_hands.reset()
	if cq_utility:cq_utility.reset()
	swim_detector.reset();swim_input=Vector3.ZERO
	origin_offset=Vector3(-head.position.x,0,-head.position.z)
	scores=false
func movement_hand() -> XRController3D: return right if left_controls else left
func turning_hand() -> XRController3D: return left if left_controls else right
func left_button(action: String) -> void: control_button(action,left)
func right_button(action: String) -> void: control_button(action,right)
func control_button(action: String, _hand: XRController3D) -> void:
	if action=="menu_button":toggle_menu()
func poll_controls() -> void:
	for action in ["menu","scores","use"]:
		var pressed: bool=focused and game.bindings.vr_pressed(self,action)
		if action=="scores":
			scores=pressed and game.active and not game.menu_open
			if scores and not control_edges.get(action,false):place_menu()
		if pressed and not control_edges.get(action,false):
			match action:
				"menu":toggle_menu()
				"use":
					if game.active and not game.menu_open:
						if multiplayer.is_server():game._use_for(multiplayer.get_unique_id())
						elif game.has_method("request_cq_use"):game.request_cq_use()
						else:game._use_request.rpc_id(1)
		control_edges[action]=pressed
func sample_raw_pose() -> Dictionary:
	return {"head":origin.transform*head.transform,"left":origin.transform*left.transform,"right":origin.transform*right.transform,"weapon":origin.transform*Poses.held_weapon((left if left_handed else right).transform,(left_aim if left_handed else right_aim).transform),"left_handed":left_handed}
func weapon_pose() -> Transform3D:
	var hand: XRController3D=left if left_handed else right
	var aim: XRController3D=left_aim if left_handed else right_aim
	var other: XRController3D=right if left_handed else left
	var held:=Poses.held_weapon(hand.transform,aim.transform)
	var valid: bool=game.bindings.two_handed and not physical_actions.busy() and not shoulder_radio.held and not game.menu_open and not scores and focused and (simulated or (hand.get_has_tracking_data() and aim.get_has_tracking_data() and other.get_has_tracking_data()))
	var slot:int=game.local_state().get("weapon",game.desired_weapon)
	if cq_hands and cq_hands.claims_hand(held,other.transform):valid=false
	var supported:Transform3D=support_aim.solve(held,other.transform,slot,game.bindings.vr_pressed(self,"support"),valid,"cq" if cq_hands else "doom",cq_hands!=null)
	return virtual_stock.solve(supported,other.transform,head.transform,slot,left_handed,valid and support_aim.engaged and virtual_stock_enabled,"cq",true) if cq_hands else supported
func follow_menu()->void:
	panel.global_transform=global_transform*menu_mount
	keyboard.global_transform=panel.global_transform*Transform3D(Basis(Vector3.RIGHT,-.2),Vector3(0,-1.0,.15))
func update_scope_visibility()->void:
	if sniper_scope and sniper_scope.active:status_surface.hide()
func update_seated(body: Dictionary) -> void:
	seated_active=seated
	origin_offset.y=seated_height_offset if seated_active else 0.0
func toggle_menu() -> void:
	if game.has_method("draw_class_players") and game.loadout_menu and game.loadout_menu.pending:
		game.menu_open=true;game.hud.show_menu(true);game.hud.menu_pages.navigate("cq_prepare");return
	if game.menu_open and game.hud and game.hud.menu_back():return
	game.menu_open=not game.menu_open or not game.active
	game.hud.show_menu(game.menu_open)
	scores=false
	if game.menu_open: place_menu()
func _process(delta: float) -> void:
	process_priority=-30
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not enabled or game.quitting: return
	poll_controls()
	left.visible=simulated or left.get_has_tracking_data()
	right.visible=simulated or right.get_has_tracking_data()
	for i in hand_animators.size():
		hand_animators[i].curls=preload("res://deathmatch/vr/hand_input.gd").local_sample(left if i==0 else right,"left" if i==0 else "right")

	var mine:=multiplayer.get_unique_id()
	# During departure/shutdown a fighter can outlive the active player state.
	# Do not build weapon/avatar visuals from an empty local-state dictionary.
	var actor=game.fighters.get(mine) if game.active and not game.local_state().is_empty() else null
	if actor:
		global_transform=Transform3D(Basis(Vector3.UP,game.local_yaw),actor.render_position())
	elif not game.spawn_points.is_empty():
		global_transform=Transform3D(Basis(Vector3.UP,game.spawn_yaws[0] if not game.spawn_yaws.is_empty() else 0.0),game.spawn_points[0])
	update_seated({})
	crouch_height=crouch_detector.sample(head.position.y,game.bindings.physical_crouch and not seated_active and focused and head_tracked() and not calibration_pending,game.bindings.physical_prone)
	jump_detector.sample(head.position.y,delta,game.bindings.physical_jump and not seated_active and not calibration_pending and focused and not game.menu_open and head_tracked() and actor!=null and not game.local_state().get("dead",true),actor!=null and actor.is_supported())
	var tracked_hands: bool=head_tracked() and (simulated or left.get_has_tracking_data() and right.get_has_tracking_data())
	var living: bool=actor!=null and not game.local_state().get("dead",true) and not game.local_state().get("spectator",false)
	if medic_interactions:medic_interactions.update(living and tracked_hands and focused and not game.menu_open and not mounted_for_cq())
	if cq_utility:cq_utility.update(delta,living and tracked_hands and focused and not game.menu_open and (not mounted_for_cq() or repair_cabin_passenger()))
	if cq_hands:cq_hands.update(delta,living and tracked_hands and focused and not game.menu_open and not mounted_for_cq())
	support_aim.advance(delta);virtual_stock.advance(delta);weapon_kick.update(delta)
	var swimming: bool=living and actor.in_water and focused and tracked_hands and not game.menu_open and not scores and game.intermission<=0 and not game.match_mode.special.blocked(mine)
	swim_input=swim_detector.sample(head.transform,left.position,right.position,delta,swimming)
	water_view_offset=game.water_view_raise(actor,origin_offset.y+head.position.y+actor.view_offset) if actor else 0.0
	origin.position=origin_offset+Vector3.UP*((actor.view_offset if actor and not cq_hands else 0.0)+water_view_offset)
	if calibration_pending and (simulated or head.position.y>.5): recenter()
	if actor and not game.menu_open and focused:
		var stick: Vector2=game.bindings.axis(self,"turn")
		if not transport_wheel or transport_wheel.driver_key()<0:apply_turn(stick.x,delta)
		global_basis=Basis(Vector3.UP,game.local_yaw)
		if not game.has_method("draw_class_players") and absf(stick.y)>.75 and not cycle_latched and not game.local_state().get("spectator",false):
			game.desired_weapon=W.next_owned(game.desired_weapon,1 if stick.y>0 else -1,game.local_state().get("owned",[2]))
			cycle_latched=true
		if absf(stick.y)<.3: cycle_latched=false
	var mounted: bool=game.match_mode.fortress.walkers.mounted(mine) or game.handle_vehicle_player(mine,0.0)
	if calibration_pose.sample(head.transform,left.position,right.position,delta,living and tracked_hands and focused and not seated_active and not mounted and not game.menu_open and not scores and not game.player_incapacitated(mine)):
		recenter();feedback(.5,.15);feedback(.5,.15,true)
	if not game.has_method("draw_class_players") and actor and is_instance_valid(actor.avatar) and actor.avatar.has_method("hand_pose"):
		actor.xr_pose=sample_pose();actor.avatar.target_xr_pose=actor.xr_pose
		actor.avatar.stance=actor.stance;actor.avatar.aim_pitch=game.local_state().get("pitch",0.0)
		# Local tracked attachments must refresh immediately, including hidden bodies.
		actor.avatar.advance_animation(delta if actor.avatar.process_mode==Node.PROCESS_MODE_DISABLED and not actor.frozen else 0.0)
	shoulder_radio.update(not mounted and living and tracked_hands and focused and not game.menu_open and not scores and not blackout.visible)
	update_shoulder_utility(living and (not mounted or repair_cabin_passenger()))
	physical_actions.update(delta,not mounted and not shoulder_radio.held and living and tracked_hands and focused and not game.menu_open and not scores)
	var menu_visible: bool=game.menu_open or scores or (focused and game.bindings.pressed("scores")) or not game.active
	var burning: bool=actor!=null and game.match_mode.fortress.burning(actor.peer_id)
	damage_material.set_shader_parameter("burning",1.0 if burning else 0.0)
	damage_overlay.visible=(burning or game.hurt_flash>0 or actor!=null and actor.underwater) and focused and not menu_visible
	damage_material.set_shader_parameter("underwater",1.0 if actor!=null and actor.underwater else 0.0)
	damage_material.set_shader_parameter("strength",clampf(game.hurt_flash/.35,0,1))
	if menu_visible and (not last_panel or panel.global_position.distance_to(head.global_position)>3.5): place_menu()
	if menu_visible:follow_menu()
	last_panel=menu_visible
	status_surface.visible=actor!=null and focused and not menu_visible
	status_hud.update_chat(game.chat_feed,game.clock)
	status_hud.update_killfeed(game.feed,game.clock)
	if not menu_visible:turn_panel.hide()
	panel.visible=menu_visible
	panel.enabled=menu_visible
	scroll_dropdowns(delta,menu_visible)
	var focused_control=focused_edit()
	keyboard.visible=menu_visible and (focused_control is LineEdit or focused_control is TextEdit)
	keyboard.enabled=keyboard.visible
	for i in range(pointers.size()):
		pointers[i].distance=6 if menu_visible else 28
		pointers[i].enabled=(menu_visible or game.lobby.active()) and focused and (simulated or (left_aim if i==0 else right_aim).get_has_tracking_data())
		pointers[i].visible=pointers[i].enabled
	if actor:
		var s: Dictionary=game.local_state()
		var leader:=0
		for player in game.players.values():leader=maxi(leader,player.kills)
		if game.has_method("draw_class_players"):status_hud.update_radio_scope(game.voice.radio_scope())
		status_hud.update_player_status(preload("res://deathmatch/ui/player_status.gd").read(game,game.multiplayer.get_unique_id()))
		status_hud.update_water(actor.underwater,actor.air_left)
		status_hud.update_burning(burning)
		status_hud.update_capture(game.match_mode.capture_status())
		status_hud.update_vote(game.votes.snapshot() if game.multiplayer.is_server() else game.votes.view)
		status_hud.update_network(game.loading.snapshot(),game.local_ping,game.multiplayer.is_server())
		status_hud.update_status(s,game.round_left,game.frag_limit,leader,game.intermission>0,game.voice and game.voice.transmitting,game.variant_combat.charge_label(game.multiplayer.get_unique_id())+_objective_hud(s),game.voice and game.voice.team_channel(),game.match_mode.fortress.weapon_data(game.multiplayer.get_unique_id(),s.weapon),game.armory.max_ammo(),preload("res://deathmatch/ui/cq/hud.gd").ammo_readout(game,game.multiplayer.get_unique_id()) if game.has_method("draw_class_players") else {})
		var art_rules: String=game.match_mode.fortress.art_rules(mine,s.weapon)
		if s.weapon!=gun_id or gun_rules!=art_rules:
			if is_instance_valid(gun): gun.free()
			if is_instance_valid(offhand_gun): offhand_gun.free()
			offhand_gun=null
			if s.weapon==2 and game.armory.dual():
				offhand_gun=Art.weapon(2,int(game.presentation.get("texture_filter",2)));add_child(offhand_gun)
			gun=Art.weapon(s.weapon,int(game.presentation.get("texture_filter",2)),art_rules)
			(left_aim if left_handed else right_aim).add_child(gun)
			gun_id=s.weapon;gun_rules=art_rules
		if gun.get_parent()!=(left_aim if left_handed else right_aim): gun.reparent(left_aim if left_handed else right_aim,false)
		gun.visible=not game.handle_vehicle_player(mine,0.0) and not game.lobby.active() and not s.dead and not menu_visible and (simulated or ((left_aim if left_handed else right_aim).get_has_tracking_data() and (left if left_handed else right).get_has_tracking_data()))
		var grip: XRController3D=left if left_handed else right
		var aim: XRController3D=left_aim if left_handed else right_aim
		var visible_pose:=attached_hand(false,origin.global_transform*weapon_pose())
		gun.global_transform=Art.held_transform(weapon_kick.apply(visible_pose) if cq_hands else visible_pose,s.weapon,Art.VR_SCALE,art_rules)
		if cq_hands:gun.visible=gun.visible and cq_hands.holding and s.weapon==game.desired_weapon and not cq_utility.held
		if cq_hands:preload("res://deathmatch/conquest/classes/models.gd").animate_reload(gun,cq_hands.row())

		if is_instance_valid(offhand_gun):
			var other_grip: XRController3D=right if left_handed else left
			var other_aim: XRController3D=right_aim if left_handed else left_aim
			offhand_gun.visible=not game.handle_vehicle_player(mine,0.0) and not game.match_mode.fortress.walkers.mounted(multiplayer.get_unique_id()) and not physical_actions.busy() and not shoulder_radio.held and not game.lobby.active() and not s.dead and not menu_visible and focused and (simulated or (other_grip.get_has_tracking_data() and other_aim.get_has_tracking_data()))
			offhand_gun.global_transform=Art.held_transform(attached_hand(true,Poses.held_weapon(other_grip.global_transform,other_aim.global_transform)),2)
		if aim_guides.is_empty():
			for i in 2:
				var guide=preload("res://deathmatch/vr/aim_guide.gd").new();add_child(guide);aim_guides.append(guide)
		aim_guides[0].update(visible_pose,s.weapon,gun.visible and not cq_hands,art_rules)
		if is_instance_valid(offhand_gun):
			var other_grip:XRController3D=right if left_handed else left
			var other_aim:XRController3D=right_aim if left_handed else left_aim
			aim_guides[1].update(attached_hand(true,Poses.held_weapon(other_grip.global_transform,other_aim.global_transform)),2,offhand_gun.visible)
		else:aim_guides[1].hide()
		# Headset/controller poses control aiming; UT99 bodies use vertex animation.
		var pose:=sample_pose()
		actor.xr_pose=pose
		actor.set_local_body(false)
		for i in hand_models.size():
			var model:Node3D=hand_models[i]
			model.visible=not actor.local_body_visible and (not mounted or transport_seated())
			var offhand:bool=(i==0)!=left_handed
			var grip_pose:Transform3D=(left if i==0 else right).global_transform
			grip_pose.origin=attached_hand(offhand,grip_pose).origin
			if cq_hands and gun.visible:
				if not offhand:
					var raw:=origin.global_transform*Poses.held_weapon(grip.transform,aim.transform)
					grip_pose=weapon_kick.apply(visible_pose)*raw.affine_inverse()*grip_pose
				elif support_aim.engaged:
					grip_pose=preload("res://deathmatch/conquest/classes/models.gd").support_pose(gun.global_transform,s.weapon,i==0)
					hand_animators[i].curls=PackedFloat32Array([.8,.85,.95,.95,.95])
			model.global_transform=grip_pose
		if medic_interactions:medic_interactions.attach_hand()
		var from: Vector3=actor.position+Vector3.UP*actor.torso_height()
		var wall:=PhysicsRayQueryParameters3D.create(from,head.global_position,1)
		blackout.visible=not game.handle_vehicle_player(mine,0.0) and not s.spectator and (not game.get_world_3d().direct_space_state.intersect_ray(wall).is_empty() or head.global_position.distance_to(from)>1.3)
	else:
		for guide in aim_guides:guide.hide()
		for model in hand_models: model.visible=true
		if gun: gun.visible=false
		if offhand_gun: offhand_gun.visible=false
		blackout.visible=false
	if not sniper_scope and is_instance_valid(gun) and gun.has_meta("scope_rear"):
		sniper_scope=preload("res://deathmatch/vr/sniper_scope.gd").new();add_child(sniper_scope);sniper_scope.setup(self)
	if sniper_scope:
		sniper_scope.update_rig()
		update_scope_visibility()
func attached_hand(offhand:bool,fallback:Transform3D) -> Transform3D:
	# Local controller tracking is independent of remote/avatar arm constraints.
	if game.has_method("draw_class_players"):return fallback
	var actor=game.fighters.get(multiplayer.get_unique_id())
	if actor and is_instance_valid(actor.avatar) and actor.avatar.has_method("hand_pose"):
		return actor.avatar.global_transform*actor.avatar.hand_pose(offhand)
	return fallback
func shoulder_mount(mainhand:bool) -> Transform3D:
	if game.has_method("draw_class_players"):
		var side:float=(-1.0 if left_handed else 1.0)*(-1.0 if mainhand else 1.0)
		return origin.global_transform*Transform3D(Basis(Vector3.UP,head.rotation.y),head.position+Basis(Vector3.UP,head.rotation.y)*Vector3(side*.23,-.25,.04))
	var actor=game.fighters.get(multiplayer.get_unique_id())
	if actor and is_instance_valid(actor.avatar) and actor.avatar.has_method("equipment_socket"):
		return actor.avatar.global_transform*actor.avatar.equipment_socket(mainhand)
	var side:float=(-1.0 if left_handed else 1.0)*(-1.0 if mainhand else 1.0)
	return origin.global_transform*Transform3D(Basis(Vector3.UP,head.rotation.y),head.position+Vector3(side*.23,-.25,.04))
func compensate_room_move(shift: Vector3) -> void:
	# Preserve the physical head/hand world positions, including when collision clips a move.
	origin_offset-=shift
	origin.position.x=origin_offset.x;origin.position.z=origin_offset.z
func apply_turn(axis: float,delta: float) -> void:
	if smooth_turn:
		if absf(axis)>.18:game.local_yaw=wrapf(game.local_yaw-axis*delta*deg_to_rad(turn_speed),-PI,PI)
	elif absf(axis)>.7 and not turn_latched:
		game.local_yaw=wrapf(game.local_yaw-signf(axis)*deg_to_rad(snap_angle),-PI,PI)
		turn_latched=true
	if absf(axis)<.3:turn_latched=false
func save_turn_settings() -> Error:
	turn_latched=false
	return Preferences.save_settings({"smooth_turn":smooth_turn,"turn_speed":turn_speed,"snap_angle":snap_angle,"left_controls":left_controls,"seated":seated,"virtual_stock":virtual_stock_enabled})
var water_view_offset:=0.0
func sample_pose() -> Dictionary:
	var physical_origin:=origin.transform
	physical_origin.origin.y-=water_view_offset
	var aim: XRController3D=left_aim if left_handed else right_aim
	var hand: XRController3D=left if left_handed else right
	var pose: Dictionary={"head":physical_origin*head.transform,"left":physical_origin*left.transform,"right":physical_origin*right.transform,"weapon":physical_origin*(weapon_kick.apply(weapon_pose()) if cq_hands else weapon_pose()),"left_handed":left_handed,"height":crouch_height}
	var other_hand: XRController3D=right if left_handed else left
	var other_aim: XRController3D=right_aim if left_handed else left_aim
	if simulated or (other_hand.get_has_tracking_data() and other_aim.get_has_tracking_data()):
		pose.offhand_weapon=physical_origin*Poses.held_weapon(other_hand.transform,other_aim.transform)
	if transport_wheel and transport_wheel.is_bike() and transport_wheel.driver_key()>=0:
		for i in 2:
			if not transport_wheel.hands[i].is_empty():pose["left" if i==0 else "right"]=global_transform.affine_inverse()*hand_models[i].global_transform
		pose.weapon=pose.left if left_handed else pose.right
		if pose.has("offhand_weapon"):pose.offhand_weapon=pose.right if left_handed else pose.left
	return Poses.validate(pose)

func command(sequence: int) -> Dictionary:
	var blocked: bool=game.menu_open or scores or not focused
	var aim: XRController3D=left_aim if left_handed else right_aim
	var hand: XRController3D=left if left_handed else right
	var tracked: bool=simulated or (hand.get_has_tracking_data() and aim.get_has_tracking_data())
	var stick: Vector2=game.bindings.axis(self,"move") if not blocked else Vector2.ZERO
	if stick.length()<.18: stick=Vector2.ZERO
	var movement:=Basis(Vector3.UP,head.rotation.y)*Vector3(stick.x,0,-stick.y)
	var pose:=sample_pose()
	var trigger: bool=game.bindings.vr_pressed(self,"fire")
	var physical_weapon: bool=game.armory.vr_physical_only(game.desired_weapon)
	var other_hand: XRController3D=right if left_handed else left
	var other_trigger: bool=game.bindings.vr_pressed(self,"offhand_fire")
	var room:=Vector3.ZERO
	if not blocked and not pose.is_empty():
		var horizontal:=Vector3(pose.head.origin.x,0,pose.head.origin.z)
		room=RoomScale.request(horizontal)
	var jump: bool=game.bindings.vr_pressed(self,"jump") or jump_detector.consume()
	return {"weapon_held":cq_hands.holding if cq_hands else true,"seq":sequence,"fly":game.bindings.axis(self,"turn").y if game.local_state().get("spectator",false) and not blocked else 0.0,"move":Vector2(movement.x,movement.z).limit_length(1),"yaw":game.local_yaw,"pitch":0.0,"melee":(cq_hands==null or cq_hands.holding) and not shoulder_radio.held and not blocked and tracked and not pose.is_empty() and not blackout.visible,"physical":physical_actions.available and not shoulder_radio.held,"input_blocked":blocked or not tracked or blackout.visible,"alt_fire":not physical_weapon and game.bindings.vr_pressed(self,"alt_fire") and not physical_actions.busy() and not shoulder_radio.held and not blocked and tracked and not pose.is_empty() and not blackout.visible,"offhand_fire":other_trigger and not physical_actions.busy() and not shoulder_radio.held and game.armory.dual() and game.desired_weapon==2 and not blocked and pose.has("offhand_weapon") and not blackout.visible,"fire":trigger and (cq_hands==null or cq_hands.holding) and not physical_weapon and not blocked and tracked and not pose.is_empty() and not blackout.visible,"weapon":game.desired_weapon,"slow":game.bindings.vr_pressed(self,"slow"),"prone":crouch_detector.prone,"jump":not blocked and jump,"respawn":not blocked and (trigger or game.bindings.vr_pressed(self,"jump")),"xr":pose,"room":room,"swim":swim_input if not blocked and not pose.is_empty() else Vector3.ZERO}
func feedback(strength: float,seconds: float=.08,offhand: bool=false) -> void:
	var use_left:=left_handed!=offhand
	if enabled and not simulated: (left if use_left else right).trigger_haptic_pulse("haptic",0,clampf(strength,0,1),seconds,0)
func hand_empty(index:int)->bool:
	var controller:XRController3D=left if index==0 else right
	if controller.get_float("grip")>.35:return false
	if cq_utility and cq_utility.held and cq_utility.hand_index==index:return false
	if shoulder_radio.held and shoulder_radio.held_hand==index:return false
	if medic_interactions and medic_interactions.drag_hand==index:return false
	if cq_hands:
		var primary:int=0 if left_handed else 1
		if index==primary and cq_hands.holding:return false
		if index!=primary:
			var reload_state:Dictionary=cq_hands.row()
			if reload_state.get("carry",0)>0 or reload_state.get("grab","")!="" or reload_state.get("stroke",0.)>.05:return false
		if index!=primary and cq_hands.holding:
			var weapon_hand:XRController3D=left if left_handed else right
			var aim:XRController3D=left_aim if left_handed else right_aim
			if support_aim.engaged or cq_hands.claims_hand(Poses.held_weapon(weapon_hand.transform,aim.transform),controller.transform):return false
	return true

func focused_edit() -> Control:
	var viewport: SubViewport=panel.get_node("Viewport")
	var windows:=viewport.get_embedded_subwindows()
	for window in windows:
		if window.visible and window.gui_get_focus_owner(): return window.gui_get_focus_owner()
	return viewport.gui_get_focus_owner()

func configure_refresh_rate() -> void:
	var xr:=XRServer.find_interface("OpenXR") as OpenXRInterface
	if not xr or not OS.has_feature("android"): return
	var rates:=xr.get_available_display_refresh_rates()
	var preferred:=1000.0
	for rate in rates:
		if rate>=72.0: preferred=minf(preferred,rate)
	if preferred<1000: xr.set_display_refresh_rate(preferred)


func _objective_hud(s: Dictionary) -> String:
	var mode=game.match_mode
	var vote: Dictionary=game.votes.snapshot() if game.multiplayer.is_server() else game.votes.view
	if not vote.is_empty():return "VOTE: "+vote.title+" · OPEN MENU"
	if not mode.team_game():return mode.kind.to_upper() if mode.kind!="dm" else ""
	if mode.freeze_tag() and mode.special.frozen.has(game.multiplayer.get_unique_id()):return "FROZEN · THAW %.1f / 3s"%mode.special.frozen[game.multiplayer.get_unique_id()]
	var extra: String=" [R]" if s.team==0 else " [B]" if s.team==1 else ""
	if mode.kind=="koth":extra+=" CONTESTED" if mode.hill_owner==-2 else " HOLD" if mode.hill_owner==s.team and s.team>=0 else ""
	if mode.kind in ["ctf","tf"] and mode.flags.size()==2:
		for flag in mode.flags:
			if flag.carrier==game.multiplayer.get_unique_id():extra+=" CARRYING FLAG"
	return "%s R%d B%d / %d"%[mode.kind.to_upper(),mode.scores[0],mode.scores[1],mode.limit()]+extra

func head_tracked() -> bool:
	if simulated:return true
	var tracker=XRServer.get_tracker("head")
	if tracker==null:return false
	var pose=tracker.get_pose("default")
	return pose!=null and pose.has_tracking_data

func scroll_dropdowns(delta: float,menu_visible: bool) -> void:
	if not focused:return
	var targets: Dictionary={}
	for index in pointers.size():
		var hand: XRController3D=left if index==0 else right
		if not simulated and not hand.get_has_tracking_data():continue
		# OpenXR stick Y is positive up; canvas scrolling is positive down.
		var axis: float=-hand.get_vector2("primary").y
		var viewport: Viewport=game.hud.get_viewport() if menu_visible else null
		var target=pointers[index].target
		if not menu_visible and is_instance_valid(target) and target.has_method("global_to_viewport"):
			viewport=target.get_parent().get_node_or_null("Viewport")
		if viewport and absf(axis)>absf(float(targets.get(viewport,0.0))):targets[viewport]=axis
	for viewport in targets:
		preload("res://deathmatch/ui/choice.gd").scroll_active(viewport,targets[viewport],delta)

func update_shoulder_utility(valid:bool) -> void:
	if not game.has_method("class_throw"):return
	var id:=multiplayer.get_unique_id()
	var rules=game.classes
	var row:Dictionary=rules.states.get(id,{})
	var key:String=row.get("equipped_utility",rules.UTILITIES[rules.role(id)][0].id)
	if key!=shoulder_utility_key:
		shoulder_utility_key=key
		if is_instance_valid(shoulder_utility):shoulder_utility.free()
		shoulder_utility=preload("res://deathmatch/avatars/equipment.gd").utility(key);add_child(shoulder_utility)
		shoulder_utility.set_meta("stowed_scale",shoulder_utility.scale)
		preload("res://tools/voxel_battle/baked_lighting.gd").convert_node(shoulder_utility)
	if is_instance_valid(shoulder_utility):
		shoulder_utility.visible=valid and not physical_actions.busy()
		var carried:bool=cq_utility and cq_utility.held and not cq_utility.box_mode
		if key in ["jetpack","healing_grenade"]:
			shoulder_utility.visible=shoulder_utility.visible and (carried or cq_utility.grenade_available())
			preload("res://deathmatch/conquest/classes/grenade_visuals.gd").show_armed(shoulder_utility,carried and cq_utility.armed)
		if carried and cq_utility.grenade():
			shoulder_utility.global_transform=preload("res://deathmatch/conquest/classes/grenade_visuals.gd").held_pose(cq_utility.hand().global_transform,cq_utility.hand_index==0)
		elif carried and key=="medical":
			var equipment=preload("res://deathmatch/avatars/equipment.gd")
			var tool_pose:Transform3D=medic_interactions.injector_pose() if medic_interactions and medic_interactions.injection_target!=0 else equipment.injector_pose(cq_utility.hand().global_transform)
			shoulder_utility.global_transform=Transform3D(tool_pose.basis.scaled(Vector3.ONE*equipment.injector_scale()),tool_pose.origin)
		elif carried and key in ["recon","recon_drone"]:
			shoulder_utility.global_transform=preload("res://deathmatch/avatars/equipment.gd").cloak_held_pose(cq_utility.hand().global_transform)
		elif carried:
			var aim:XRController3D=left_aim if cq_utility.hand_index==0 else right_aim
			shoulder_utility.global_transform=Art.held_transform(Poses.held_weapon(cq_utility.hand().global_transform,aim.global_transform),7 if key in ["medical","engineering"] else 6 if key=="turret" else 8,.65,"cq_"+rules.role(id))
		else:
			shoulder_utility.global_transform=cq_utility.tool_mount() if key in ["medical","engineering"] and cq_utility else shoulder_mount(false)
			shoulder_utility.scale=shoulder_utility.get_meta("stowed_scale")

func transport_seated()->bool:
	if not game.has_method("draw_class_players"):return false
	var key:int=game.battery_tanks.key_for(game.multiplayer.get_unique_id())
	return key>=0 and game.battery_tanks.rows[key].kind in ["transport","bike"]
func repair_cabin_passenger()->bool:
	return game.has_method("draw_class_players") and game.battery_tanks.can_repair_from_cabin(game.multiplayer.get_unique_id())
func mounted_for_cq() -> bool:
	return game.has_method("draw_class_players") and game.battery_tanks.mounted(game.multiplayer.get_unique_id())
