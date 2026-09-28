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
var physical_reload
var shoulder_radio=preload("res://deathmatch/vr/shoulder_radio.gd").new()
var support_aim=preload("res://deathmatch/vr/aim_support.gd").new()
var weapon_kick=preload("res://deathmatch/vr/weapon_kick.gd").new()
var virtual_stock=preload("res://deathmatch/vr/virtual_stock.gd").new()
var virtual_stock_enabled:=false
var pump_auto_transfer:=true
var swim_detector=preload("res://deathmatch/vr/swim_strokes.gd").new()
var t_pose_detector=preload("res://deathmatch/vr/t_pose.gd").new()
var swim_input:=Vector3.ZERO
var calibration_sound: AudioStreamPlayer
var crouch_detector=preload("res://deathmatch/vr/physical_crouch.gd").new()
var crouch_height:=1.65
var jump_detector=preload("res://deathmatch/vr/physical_jump.gd").new()
var game
var tracking
var eyes
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
var keypad_finger=preload("res://deathmatch/vr/keypad_finger.gd").new()
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
var weapon_wheel
var foveation_poll:=0.0
var gaze_vrs=preload("res://deathmatch/vr/gaze_vrs.gd").new()
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
var calibration_pending:=true
func setup(arena: Node, test_mode: bool=false) -> bool:
	game=arena
	physical_actions.setup(self);shoulder_radio.setup(self)
	physical_reload=preload("res://deathmatch/vr/physical_reload.gd").new();add_child(physical_reload);physical_reload.setup(self)
	simulated=test_mode
	var xr:=XRServer.find_interface("OpenXR")
	if simulated and xr and xr.is_initialized(): xr.uninitialize()
	if not simulated and (not xr or not xr.is_initialized()): return false
	enabled=true
	var settings:=Preferences.read_settings()
	smooth_turn=settings.smooth_turn;turn_speed=settings.turn_speed;snap_angle=settings.snap_angle
	left_controls=settings.left_controls;seated=settings.seated
	virtual_stock_enabled=settings.virtual_stock
	pump_auto_transfer=settings.pump_auto_transfer
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
		preload("res://deathmatch/maps/filtering.gd").new().apply(hand_model,int(game.presentation.get("texture_filter",2)))
		hand_models.append(hand_model)
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
		apply_foveation_preferences(game.presentation)
		if xr.has_signal("session_begun"):xr.connect("session_begun",configure_foveation)
		if xr.has_signal("session_begun"): xr.connect("session_begun",configure_refresh_rate)
		if xr.has_signal("session_begun"): xr.connect("session_begun",configure_hands)
		configure_hands()
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
	tracking=preload("res://deathmatch/vr/tracking.gd").new()
	add_child(tracking)
	tracking.setup(self)
	tracking.calibration_completed.connect(_body_calibrated)
	eyes=preload("res://deathmatch/vr/eyes.gd").new()
	add_child(eyes)
	eyes.setup(self)
	build_ui()
	head.make_current()
	game.camera=head
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	print("XR_READY ","simulated" if simulated else "OpenXR")
	return true

func configure_foveation() -> void:
	apply_foveation_preferences(game.presentation)

func apply_foveation_preferences(values: Dictionary) -> void:
	if simulated or not enabled:return
	var state: Dictionary=preload("res://deathmatch/vr/foveation.gd").apply(get_viewport(),XRServer.find_interface("OpenXR"),int(values.get("foveation_level",2 if OS.has_feature("android") else 0)),int(values.get("fovea_size",-1)))
	if state!=get_meta("foveation_state",{}):
		set_meta("foveation_state",state)
		print("XR_FOVEATION ",JSON.stringify(state))

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
	panel.screen_size=Vector2(1.9,1.425)
	panel.viewport_size=Vector2(1280,960)
	panel.collision_layer=UI_LAYER
	panel.unshaded=true
	var ui_material:=StandardMaterial3D.new()
	ui_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
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
	status_hud.size=Vector2(status_viewport.size);status_hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	status_viewport.add_child(status_hud)
	status_surface=MeshInstance3D.new()
	var status_quad:=QuadMesh.new();status_quad.size=Vector2(status_viewport.size)*.001
	# Extend upwards for chat without moving or shrinking the existing HUD.
	status_quad.center_offset.y=(status_hud.CHAT_HEIGHT+status_hud.NOTIFY_HEIGHT+status_hud.SELECTION_HEIGHT)*.0005
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
	weapon_wheel=preload("res://deathmatch/vr/weapon_wheel.gd").new();origin.add_child(weapon_wheel);weapon_wheel.setup(self)

	turn_panel=preload("res://deathmatch/vr/turn_panel.gd").new()
	ui_root.add_child(turn_panel);turn_panel.setup(self)
	blackout=MeshInstance3D.new()
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
	damage_overlay=MeshInstance3D.new()
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

func place_menu() -> void:
	if not panel: return
	var yaw:=head.global_rotation.y
	panel.global_transform=Transform3D(Basis(Vector3.UP,yaw),head.global_position+Basis(Vector3.UP,yaw)*Vector3(0,-.05,-1.8))
	keyboard.global_transform=panel.global_transform*Transform3D(Basis(Vector3.RIGHT,-.2),Vector3(0,-1.0,.15))
func recenter() -> void:
	virtual_stock.reset()
	support_aim.reset();jump_detector.reset();crouch_detector.reset();swim_detector.reset();swim_input=Vector3.ZERO;t_pose_detector.reset()
	if not enabled: return
	if seated:
		# Translate the tracking space, preserving real-world reach and movement.
		var physical_height:=head.position.y/XRServer.world_scale
		XRServer.world_scale=1.0
		seated_height_offset=clampf(1.65-physical_height,-.5,1.4)
	elif not simulated and head.position.y>.5:
		XRServer.world_scale=clampf(XRServer.world_scale*1.65/head.position.y,.65,1.5)
	origin_offset=Vector3(-head.position.x,0,-head.position.z)
	origin.position.x=origin_offset.x;origin.position.z=origin_offset.z
	calibration_pending=false
	if tracking: tracking.corrections.clear();tracking.native_corrections.clear();tracking.native_foot_offsets.clear()
	place_menu()
func on_spawn() -> void:
	virtual_stock.reset();support_aim.reset()
	if weapon_wheel:weapon_wheel.reset()
	physical_actions.reset();shoulder_radio.reset()
	if physical_reload:physical_reload.reset()
	swim_detector.reset();swim_input=Vector3.ZERO;t_pose_detector.reset()
	origin_offset=Vector3(-head.position.x,0,-head.position.z)
	scores=false
func movement_hand() -> XRController3D: return right if left_controls else left
func turning_hand() -> XRController3D: return left if left_controls else right
func left_button(action: String) -> void: control_button(action,left)
func right_button(action: String) -> void: control_button(action,right)
func control_button(action: String, _hand: XRController3D) -> void:
	if action=="menu_button":toggle_menu()
func poll_controls() -> void:
	var wheel_pressed: bool=game.bindings.vr_pressed(self,"weapon_wheel")
	if weapon_wheel and focused and wheel_pressed and not control_edges.get("weapon_wheel",false):
		weapon_wheel.toggle(right.get_vector2("primary"))
	control_edges["weapon_wheel"]=wheel_pressed
	for action in ["menu","scores","use","ability"]:
		var pressed: bool=game.bindings.vr_pressed(self,action)
		# The wheel toggle wins a shared click binding while it can be used.
		if game.bindings.vr.get(action,"")==game.bindings.vr.get("weapon_wheel","") and (wheel_open() or can_open_weapon_wheel()):pressed=false
		if action=="scores":
			scores=pressed and game.active and not game.menu_open
			if scores and not control_edges.get(action,false):place_menu()
		if pressed and not control_edges.get(action,false) and focused:
			match action:
				"menu":toggle_menu()
				"use":
					if game.active and not game.menu_open and not wheel_open() and not (game.match_mode.fortress.enabled() and game.bindings.vr.use==game.bindings.vr.ability):
						if multiplayer.is_server():game._use_for(multiplayer.get_unique_id())
						else:game._use_request.rpc_id(1)
				"ability":
					if context_controls_available() and game.match_mode.fortress.enabled() and not physical_actions.busy() and not shoulder_radio.held:
						if multiplayer.is_server():game._use_for(multiplayer.get_unique_id())
						else:game._use_request.rpc_id(1)
		control_edges[action]=pressed

func context_controls_available() -> bool:
	var s: Dictionary=game.local_state()
	return game.active and not s.is_empty() and not s.get("dead",true) and not s.get("spectator",false) and focused and not game.menu_open and not scores and not wheel_open() and not game.map_loading and not game.demos.playing and game.intermission<=0 and not game.lobby.active() and not game.match_mode.special.blocked(multiplayer.get_unique_id()) and not blackout.visible and (simulated or head_tracked() and turning_hand().get_has_tracking_data())

func cycle_equipment(direction: int):
	if not context_controls_available():return
	var tf=game.match_mode.fortress
	var s: Dictionary=game.local_state()
	if tf.walkers.mounted(multiplayer.get_unique_id()):return
	if game.armory.effective()=="cs16":
		if game.match_mode.defusal.enabled():game.match_mode.defusal.send("grenade_cycle",direction)
	elif game.match_mode.tribes.enabled():game.match_mode.tribes.cycle_grenade(direction)
	elif tf.enabled() and s.get("tf_class","")=="engineer":
		var choices: Array=["sentry","dispenser"]
		tf.choose(s.get("tf_next","engineer"),choices[posmod(choices.find(s.get("tf_tool","sentry"))+direction,choices.size())])
	else:game.desired_weapon=W.next_owned(game.desired_weapon,direction,s.get("owned",[2]))

func jetpack_button() -> bool:
	# A shared CS binding belongs to magazine release; a separately rebound
	# jetpack button remains available. Double-tap jump works with every loadout.
	return (game.jetpacks.enabled() or game.armory.effective()=="tribes") and not (game.armory.effective()=="cs16" and game.bindings.vr.jetpack==game.bindings.vr.reload) and game.bindings.vr_pressed(self,"jetpack")

func wheel_open() -> bool:
	return is_instance_valid(weapon_wheel) and weapon_wheel.input.opened

func can_open_weapon_wheel() -> bool:
	if not enabled or not focused or not game.active or game.menu_open or scores or game.map_loading or game.intermission>0 or game.demos.playing or game.lobby.active():return false
	var state: Dictionary=game.local_state()
	if state.is_empty() or state.get("dead",true) or state.get("spectator",false):return false
	var id:=multiplayer.get_unique_id()
	if game.match_mode.special.blocked(id) or game.match_mode.fortress.walkers.mounted(id) or physical_actions.busy():return false
	if is_instance_valid(blackout) and blackout.visible:return false
	var hand: XRController3D=left if left_handed else right
	return simulated or head_tracked() and right.get_has_tracking_data() and hand.get_has_tracking_data()

func control_axis(action: String) -> Vector2:
	if is_instance_valid(weapon_wheel) and weapon_wheel.input.captures_stick:
		if action=="turn" and wheel_open():return Vector2.ZERO
		if game.bindings.controller(self,game.bindings.axes.get(action,action))==right:return Vector2.ZERO
	return game.bindings.axis(self,action)

func reload_hand_pressed() -> bool:
	return support_holding() or game.armory.effective()=="cs16" and game.bindings.vr_pressed(self,"offhand_fire")
func support_holding() -> bool:
	if game.bindings.vr_pressed(self,"support"):return true
	if game.armory.effective()!="cs16" or not support_aim.engaged:return false
	var parts: PackedStringArray=String(game.bindings.vr.support).split(":")
	if parts.size()!=2 or parts[1] not in ["grip","trigger"]:return false
	var controller: XRController3D=game.bindings.controller(self,parts[0])
	return (simulated or controller.get_has_tracking_data()) and controller.get_float(parts[1])>.35
func kick_weapon(slot: int,direction: Vector3=Vector3.ZERO):
	if game.armory.effective()=="cs16":weapon_kick.shot(slot,support_aim.engaged,direction)
func weapon_gripped() -> bool:
	var hand: XRController3D=left if left_handed else right
	return (simulated or hand.get_has_tracking_data()) and hand.get_float("grip")>.6
func weapon_pose() -> Transform3D:
	var hand: XRController3D=left if left_handed else right
	var aim: XRController3D=left_aim if left_handed else right_aim
	var other: XRController3D=right if left_handed else left
	var held:=Poses.held_weapon(hand.transform,aim.transform)
	# The straight knife hilt follows the grip's little-finger-to-thumb axis.
	# A gun's independent aim frame otherwise rotates its blade across the palm.
	if game.armory.effective()=="cs16" and game.local_state().get("weapon",-1)==0:held=hand.transform
	if physical_reload:
		var reload_valid: bool=not physical_actions.busy() and not shoulder_radio.held and not game.menu_open and not wheel_open() and not scores and focused and (simulated or hand.get_has_tracking_data() and aim.get_has_tracking_data() and other.get_has_tracking_data()) and not game.match_mode.defusal.gun_holstered(game.multiplayer.get_unique_id())
		var pump_pose: Transform3D=physical_reload.support_weapon(held,other.transform,reload_hand_pressed(),weapon_gripped(),reload_valid)
		if physical_reload.pump_held:return pump_pose
	var valid: bool=game.bindings.two_handed and not physical_actions.busy() and not shoulder_radio.held and not game.menu_open and not wheel_open() and not scores and focused and (simulated or (hand.get_has_tracking_data() and aim.get_has_tracking_data() and other.get_has_tracking_data()))
	if physical_reload and (physical_reload.busy() and game.local_state().get("weapon",-1)!=3 or not support_aim.engaged and physical_reload.claims_hand(held,other.transform,reload_hand_pressed())):valid=false
	if game.armory.effective()=="cs16" and game.bindings.vr_pressed(self,"reload"):valid=false
	if game.match_mode.defusal.gun_holstered(game.multiplayer.get_unique_id()):valid=false
	var weapon: int=game.local_state().get("weapon",game.desired_weapon)
	var supported: Transform3D=support_aim.solve(held,other.transform,weapon,support_holding(),valid,game.armory.effective())
	return virtual_stock.solve(supported,other.transform,head.transform,weapon,left_handed,valid and support_aim.engaged and virtual_stock_enabled and game.armory.effective()=="cs16")
func update_seated(body: Dictionary) -> void:
	seated_active=seated and not (tracking and tracking.has_body_pose(body))
	origin_offset.y=seated_height_offset if seated_active else 0.0
func toggle_menu() -> void:
	if weapon_wheel:weapon_wheel.close()
	game.menu_open=not game.menu_open or not game.active
	game.hud.show_menu(game.menu_open)
	scores=false
	if game.menu_open: place_menu()
func _process(delta: float) -> void:
	process_priority=-30
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not enabled or game.quitting: return
	if not simulated:
		foveation_poll+=delta
		if foveation_poll>=.5:
			foveation_poll=0.0
			if preload("res://deathmatch/vr/foveation.gd").mode(XRServer.find_interface("OpenXR"))!=get_meta("foveation_state",{}).get("mode",""):
				apply_foveation_preferences(game.presentation)
	poll_controls()
	left.visible=simulated or left.get_has_tracking_data()
	right.visible=simulated or right.get_has_tracking_data()
	var fingers: Dictionary=tracking.sample() if tracking else {}
	for i in range(hand_animators.size()):
		hand_animators[i].curls=fingers.get("left_curls" if i==0 else "right_curls",PackedFloat32Array([0,0,0,0,0]))
	var mine:=multiplayer.get_unique_id()
	# During departure/shutdown a fighter can outlive the active player state.
	# Do not build weapon/avatar visuals from an empty local-state dictionary.
	var actor=game.fighters.get(mine) if game.active and not game.local_state().is_empty() else null
	if actor:
		global_transform=Transform3D(Basis(Vector3.UP,game.local_yaw),game.match_mode.defusal.observer_origin(actor.render_position()))
	elif not game.spawn_points.is_empty():
		global_transform=Transform3D(Basis(Vector3.UP,game.spawn_yaws[0] if not game.spawn_yaws.is_empty() else 0.0),game.spawn_points[0])
	update_seated(fingers)
	crouch_height=crouch_detector.sample(head.position.y,game.bindings.physical_crouch and not seated_active and focused and head_tracked() and not calibration_pending,game.bindings.physical_prone)
	jump_detector.sample(head.position.y,delta,game.bindings.physical_jump and not seated_active and not calibration_pending and focused and not game.menu_open and head_tracked() and actor!=null and not game.local_state().get("dead",true),actor!=null and actor.is_supported())
	var tracked_hands: bool=head_tracked() and (simulated or left.get_has_tracking_data() and right.get_has_tracking_data())
	var living: bool=actor!=null and not game.local_state().get("dead",true) and not game.local_state().get("spectator",false)
	var swimming: bool=living and actor.in_water and focused and tracked_hands and not game.menu_open and not scores and game.intermission<=0 and not game.match_mode.special.blocked(mine)
	swim_input=swim_detector.sample(head.transform,left.position,right.position,delta,swimming)
	var can_calibrate: bool=focused and tracked_hands and not seated and not calibration_pending and tracking!=null and tracking.enabled and (actor==null or living and actor.is_supported() and not actor.in_water and not game.match_mode.special.blocked(mine))
	var calibrate_now: bool=t_pose_detector.sample(head.transform,left.position,right.position,delta,can_calibrate)
	# Query extra trackers only during a candidate gesture, not every idle frame.
	if t_pose_detector.held>0 or calibrate_now:
		if not tracking.full_body_available():t_pose_detector.reset();t_pose_detector.latched=false
		elif calibrate_now:
			# A T-pose aligns body sensors without changing floor, world scale,
			# or controller reach. Recenter remains an explicit action.
			tracking.calibrate(true)
	if tracking and t_pose_detector.held>0:tracking.status="Hold T-pose · %.1f s"%maxf(0,t_pose_detector.HOLD_SECONDS-t_pose_detector.held)
	origin.position=origin_offset+Vector3.UP*(actor.render_view_offset() if actor else 0.0)
	if calibration_pending and (simulated or head.position.y>.5): recenter()
	if weapon_wheel:
		if weapon_wheel.input.captures_stick:cycle_latched=true
		weapon_wheel.update(right.get_vector2("primary"))
	if actor and not game.menu_open and focused:
		var stick: Vector2=control_axis("turn")
		apply_turn(stick.x,delta)
		global_basis=Basis(Vector3.UP,game.local_yaw)
	var equipment_stick: Vector2=game.bindings.axis(self,"turn")
	if absf(equipment_stick.y)>.75:
		if not cycle_latched:cycle_equipment(1 if equipment_stick.y>0 else -1)
		cycle_latched=true
	if absf(equipment_stick.y)<.3 and not wheel_open():cycle_latched=false
	var mounted: bool=game.match_mode.fortress.walkers.mounted(mine)
	var grenade_chord: bool=(game.match_mode.tribes.enabled() or game.match_mode.defusal.enabled() and game.match_mode.defusal.utility.shoulder_selected(mine)>=0) and game.bindings.vr_pressed(self,"support") and game.bindings.vr_pressed(self,"offhand_fire")
	shoulder_radio.update(not grenade_chord and game.match_mode.defusal.utility.selected(mine)<0 and not mounted and living and tracked_hands and focused and not game.menu_open and not scores and not blackout.visible)
	physical_actions.update(delta,not game.match_mode.defusal.busy(mine) and not mounted and not shoulder_radio.held and living and tracked_hands and focused and not game.menu_open and not scores and not wheel_open())
	var menu_visible: bool=game.menu_open or scores or (focused and game.bindings.pressed("scores")) or not game.active
	var burning: bool=actor!=null and game.match_mode.fortress.burning(actor.peer_id)
	damage_material.set_shader_parameter("burning",1.0 if burning else 0.0)
	damage_overlay.visible=(burning or game.hurt_flash>0 or actor!=null and actor.underwater) and focused and not menu_visible
	damage_material.set_shader_parameter("underwater",1.0 if actor!=null and actor.underwater else 0.0)
	damage_material.set_shader_parameter("strength",clampf(game.hurt_flash/.35,0,1))
	if menu_visible and not last_panel: place_menu()
	last_panel=menu_visible
	status_surface.visible=actor!=null and focused and not menu_visible
	status_hud.update_chat(game.chat_feed,game.clock)
	status_hud.grenade_notice.update_selection(game,mine)
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
		status_hud.update_player_status(preload("res://deathmatch/ui/player_status.gd").read(game,game.multiplayer.get_unique_id()))
		status_hud.update_water(actor.underwater,actor.air_left)
		status_hud.update_burning(burning)
		status_hud.update_capture(game.match_mode.capture_status())
		status_hud.update_vote(game.votes.snapshot() if game.multiplayer.is_server() else game.votes.view)
		status_hud.update_network(game.loading.snapshot(),game.local_ping,game.multiplayer.is_server())
		status_hud.update_status(s,game.round_left,game.frag_limit,leader,game.intermission>0,game.voice and game.voice.transmitting,game.variant_combat.charge_label(game.multiplayer.get_unique_id())+_objective_hud(s),game.voice and game.voice.team_channel(),game.match_mode.fortress.weapon_data(game.multiplayer.get_unique_id(),s.weapon),game.armory.max_ammo(),game.match_mode.defusal.enabled(),preload("res://deathmatch/ui/player_status.gd").vitals(game,game.multiplayer.get_unique_id()))
		var art_rules: String=game.match_mode.fortress.art_rules(mine,s.weapon)
		if s.weapon!=gun_id or gun_rules!=art_rules:
			weapon_kick.reset()
			if is_instance_valid(gun): gun.free()
			if is_instance_valid(offhand_gun): offhand_gun.free()
			offhand_gun=null
			if s.weapon==2 and game.armory.dual():
				offhand_gun=Art.weapon(2,int(game.presentation.get("texture_filter",2)));add_child(offhand_gun)
			gun=Art.weapon(s.weapon,int(game.presentation.get("texture_filter",2)),art_rules)
			(left_aim if left_handed else right_aim).add_child(gun)
			gun_id=s.weapon;gun_rules=art_rules
		if gun.get_parent()!=(left_aim if left_handed else right_aim): gun.reparent(left_aim if left_handed else right_aim,false)
		gun.visible=not game.match_mode.defusal.gun_holstered(mine) and not game.lobby.active() and not s.dead and not menu_visible and (simulated or ((left_aim if left_handed else right_aim).get_has_tracking_data() and (left if left_handed else right).get_has_tracking_data()))
		var grip: XRController3D=left if left_handed else right
		var aim: XRController3D=left_aim if left_handed else right_aim
		weapon_kick.update(delta)
		var raw_visible:=clear_weapon_pose(origin.global_transform*weapon_pose(),s.weapon)
		var visible_pose: Transform3D=weapon_kick.apply(raw_visible) if art_rules=="cs16" else raw_visible
		gun.global_transform=Art.held_transform(visible_pose,s.weapon,Art.VR_SCALE,art_rules)
		if s.weapon==1 and not game.armory.experimental():Art.clip_saw(gun)
		if is_instance_valid(offhand_gun):
			var other_grip: XRController3D=right if left_handed else left
			var other_aim: XRController3D=right_aim if left_handed else left_aim
			offhand_gun.visible=not game.match_mode.fortress.walkers.mounted(multiplayer.get_unique_id()) and not physical_actions.busy() and not shoulder_radio.held and not game.lobby.active() and not s.dead and not menu_visible and focused and (simulated or (other_grip.get_has_tracking_data() and other_aim.get_has_tracking_data()))
			offhand_gun.global_transform=Art.held_transform(clear_weapon_pose(Poses.held_weapon(other_grip.global_transform,other_aim.global_transform),2),2)
		if aim_guides.is_empty():
			for i in 2:
				var guide=preload("res://deathmatch/vr/aim_guide.gd").new();add_child(guide);aim_guides.append(guide)
		aim_guides[0].update(visible_pose,s.weapon,gun.visible,art_rules)
		if is_instance_valid(offhand_gun):
			var other_grip:XRController3D=right if left_handed else left
			var other_aim:XRController3D=right_aim if left_handed else left_aim
			aim_guides[1].update(clear_weapon_pose(Poses.held_weapon(other_grip.global_transform,other_aim.global_transform),2),2,offhand_gun.visible)
		else:aim_guides[1].hide()
		# Local IK reads current tracking directly; it must not wait for a network echo.
		var pose:=sample_pose()
		actor.xr_pose=pose.duplicate(true)
		if (game.match_mode.defusal.enabled() or game.match_mode.tribes.enabled()) and (physical_actions.gesture.held or not physical_actions.equipment.item.is_empty()):
			var side: String="right" if left_handed else "left"
			actor.xr_pose.body.erase(side+"_hand");actor.xr_pose.body[side+"_curls"]=PackedFloat32Array([.8,.85,.95,.95,.95])
		if art_rules=="cs16" and not pose.is_empty() and gun.visible:
			var snaps: Dictionary={}
			var primary_side: String="left" if left_handed else "right"
			if not physical_reload.pump_held:
				snaps[primary_side]=global_transform.affine_inverse()*visible_pose*raw_visible.affine_inverse()*grip.global_transform
			if (support_aim.engaged or physical_reload.pump_held) and (not physical_reload.busy() or s.weapon==3):
				var side: String="right" if left_handed else "left"
				var snap: Transform3D=preload("res://deathmatch/counterstrike/models.gd").support_pose(gun.global_transform,s.weapon,not left_handed)
				var row: Array=game.variant_combat.cs.status(mine)
				if s.weapon==3 and row.size()==11:snap.origin+=gun.global_basis*Vector3.BACK*.105*row[6]/100.0
				snaps[side]=global_transform.affine_inverse()*snap
				actor.xr_pose.body.erase(side+"_hand");actor.xr_pose.body[side+"_curls"]=PackedFloat32Array([.8,.85,.95,.95,.95])
			actor.xr_pose.snapped_hands=snaps
		actor.set_local_body(not menu_visible and focused and not pose.is_empty())
		keypad_finger.present(self,actor)
		blackout.visible=not s.spectator and not game.match_mode.defusal.observing() and RoomScale.head_blocked(actor,pose,game.local_yaw)
	else:
		for guide in aim_guides:guide.hide()
		for model in hand_models: model.visible=true
		if gun: gun.visible=false
		if offhand_gun: offhand_gun.visible=false
		blackout.visible=false
	if not sniper_scope and is_instance_valid(gun) and gun.has_meta("scope_rear"):
		sniper_scope=preload("res://deathmatch/vr/sniper_scope.gd").new();add_child(sniper_scope);sniper_scope.setup(self)
	if sniper_scope:sniper_scope.update_rig()
	if gaze_vrs:gaze_vrs.update(self)
	if physical_reload:physical_reload.update(delta,living and tracked_hands and focused and not menu_visible and not wheel_open() and not shoulder_radio.held and not blackout.visible and game.intermission<=0 and not game.map_loading and not game.match_mode.special.blocked(mine))
func clear_weapon_pose(pose: Transform3D,_weapon: int) -> Transform3D:
	# Collision still blocks/clips authoritative shots. Moving the visual weapon
	# independently of its tracked palm makes reload sockets detach from the hand.
	return pose

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
	return Preferences.save_settings({"smooth_turn":smooth_turn,"turn_speed":turn_speed,"snap_angle":snap_angle,"left_controls":left_controls,"seated":seated,"virtual_stock":virtual_stock_enabled,"pump_auto_transfer":pump_auto_transfer})
func sample_pose() -> Dictionary:
	var aim: XRController3D=left_aim if left_handed else right_aim
	var hand: XRController3D=left if left_handed else right
	var pose: Dictionary={"head":origin.transform*head.transform,"left":origin.transform*left.transform,"right":origin.transform*right.transform,"weapon":origin.transform*weapon_pose(),"left_handed":left_handed,"height":crouch_height}
	if physical_reload and physical_reload.pump_held:pose.pump=true
	var other_hand: XRController3D=right if left_handed else left
	var other_aim: XRController3D=right_aim if left_handed else left_aim
	if simulated or (other_hand.get_has_tracking_data() and other_aim.get_has_tracking_data()):
		pose.offhand_weapon=origin.transform*Poses.held_weapon(other_hand.transform,other_aim.transform)
	pose.body=tracking.sample() if tracking else {}
	# A body tracker must not replace active controller palms with estimated wrists.
	for side in ["left","right"]:
		if simulated or get(side).get_has_tracking_data():pose.body.erase(side+"_hand")
	for i in range(hand_animators.size()):
		hand_animators[i].curls=pose.body.get("left_curls" if i==0 else "right_curls",PackedFloat32Array([0,0,0,0,0]))
	pose.face=eyes.sample() if eyes else {}
	var tip: Vector3=keypad_finger.sample(self,pose)
	if tip.is_finite():pose.index_tip=tip
	return Poses.validate(pose)

func command(sequence: int) -> Dictionary:
	var blocked: bool=game.menu_open or scores or not focused
	var combat_blocked: bool=blocked or wheel_open()
	var de_blocked: bool=game.match_mode.defusal.combat_blocked(game.multiplayer.get_unique_id())
	var aim: XRController3D=left_aim if left_handed else right_aim
	var hand: XRController3D=left if left_handed else right
	var tracked: bool=simulated or (hand.get_has_tracking_data() and aim.get_has_tracking_data())
	var stick: Vector2=control_axis("move") if not blocked else Vector2.ZERO
	if stick.length()<.18: stick=Vector2.ZERO
	var movement:=Basis(Vector3.UP,head.rotation.y)*Vector3(stick.x,0,-stick.y)
	var pose:=sample_pose()
	var trigger: bool=game.bindings.vr_pressed(self,"fire")
	var physical_weapon: bool=game.armory.vr_physical_only(game.desired_weapon)
	var optic_aim: bool=game.armory.effective()=="cs16" and game.desired_weapon==9 and is_instance_valid(sniper_scope) and sniper_scope.active
	var other_hand: XRController3D=right if left_handed else left
	var other_trigger: bool=game.bindings.vr_pressed(self,"offhand_fire")
	var reload_grip: bool=not combat_blocked and tracked and pose.has("offhand_weapon") and not blackout.visible and not shoulder_radio.held and reload_hand_pressed()
	var room:=Vector3.ZERO
	if not blocked and not pose.is_empty():
		room=RoomScale.pose_request(pose)
	var jump: bool=game.bindings.vr_pressed(self,"jump") or jump_detector.consume()
	var bomb_controls: Dictionary={"de_grip":weapon_gripped(),"de_tap":other_trigger,"de_trigger":trigger}
	combat_blocked=combat_blocked or de_blocked
	var result: Dictionary={"seq":sequence,"fly":control_axis("turn").y if (game.local_state().get("spectator",false) or game.match_mode.defusal.observing()) and not blocked else 0.0,"move":Vector2(movement.x,movement.z).limit_length(1),"yaw":game.local_yaw,"pitch":0.0,"melee":not shoulder_radio.held and not combat_blocked and tracked and not pose.is_empty() and not blackout.visible,"physical":physical_actions.available and not shoulder_radio.held and not combat_blocked,"input_blocked":combat_blocked or not tracked or blackout.visible,"reload":not combat_blocked and tracked and not blackout.visible and game.bindings.vr_pressed(self,"reload"),"reload_grip":reload_grip,"alt_fire":(not physical_weapon or game.armory.effective()=="cs16" and game.desired_weapon==0) and (game.bindings.vr_pressed(self,"alt_fire") or optic_aim) and not (physical_reload and (physical_reload.busy() or reload_grip and physical_reload.claims_hand(weapon_pose(),other_hand.transform,true))) and not physical_actions.busy() and not shoulder_radio.held and not combat_blocked and tracked and not pose.is_empty() and not blackout.visible,"offhand_fire":other_trigger and not physical_actions.busy() and not shoulder_radio.held and game.armory.dual() and game.desired_weapon==2 and not combat_blocked and pose.has("offhand_weapon") and not blackout.visible,"fire":trigger and not physical_weapon and not combat_blocked and tracked and not pose.is_empty() and not blackout.visible,"weapon":game.desired_weapon,"slow":game.bindings.vr_pressed(self,"slow") and not wheel_open(),"prone":crouch_detector.prone,"leg_assist":game.bindings.tracked_leg_animation,"jump":not blocked and jump,"respawn":not combat_blocked and (trigger or game.bindings.vr_pressed(self,"jump")),"xr":pose,"room":room,"swim":swim_input if not blocked and not pose.is_empty() else Vector3.ZERO}
	# Preserve the raw secondary edge across reload/UI filtering. Keep an
	# accepted press held for network delivery, but never revive a rejected one.
	var secondary_pressed: bool=game.bindings.vr_pressed(self,"alt_fire")
	if game.armory.effective()=="cs16" and game.desired_weapon==2:
		var contact: bool=preload("res://deathmatch/counterstrike/reload_state.gd").usp_suppressor_contact(pose)
		if secondary_pressed and not control_edges.get("usp_secondary",false):control_edges["usp_alt_allowed"]=result.alt_fire and contact and not result.reload
		if not result.alt_fire or not contact or result.reload:control_edges["usp_alt_allowed"]=false
		result.alt_fire=result.alt_fire and control_edges.get("usp_alt_allowed",false)
	else:control_edges["usp_alt_allowed"]=false
	control_edges["usp_secondary"]=secondary_pressed
	# Bomb contacts remain usable while the weapon is holstered for interaction.
	result.jetpack=jetpack_button() and not result.input_blocked
	result.ski=game.armory.effective()=="tribes" and not result.input_blocked and game.bindings.vr_pressed(self,"jump")
	result.input_blocked=blocked or wheel_open() or not tracked or blackout.visible
	if game.match_mode.defusal.enabled():result.physical=physical_actions.available and not shoulder_radio.held and not result.input_blocked
	if not result.input_blocked:
		result.merge(bomb_controls)
		if game.match_mode.defusal.preparing():result.reload=game.bindings.vr_pressed(self,"reload")
	return result
func _body_calibrated() -> void:
	if not is_instance_valid(calibration_sound):
		calibration_sound=AudioStreamPlayer.new();calibration_sound.bus="ArenaEffects";calibration_sound.volume_db=-10
		calibration_sound.stream=preload("res://deathmatch/audio/calibration_complete.wav");add_child(calibration_sound)
	calibration_sound.play()
	feedback(.25,.06)
	if game:game.status("Body tracking calibrated")

func feedback(strength: float,seconds: float=.08,offhand: bool=false) -> void:
	var use_left:=left_handed!=offhand
	if enabled and not simulated: (left if use_left else right).trigger_haptic_pulse("haptic",0,clampf(strength,0,1),seconds,0)

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

func configure_hands() -> void:
	var xr:=XRServer.find_interface("OpenXR") as OpenXRInterface
	if xr and xr.is_initialized():
		xr.set_motion_range(OpenXRInterface.HAND_LEFT,OpenXRInterface.HAND_MOTION_RANGE_UNOBSTRUCTED)
		xr.set_motion_range(OpenXRInterface.HAND_RIGHT,OpenXRInterface.HAND_MOTION_RANGE_UNOBSTRUCTED)

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
