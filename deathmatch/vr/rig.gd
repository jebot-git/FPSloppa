extends Node3D
const Poses=preload("res://deathmatch/vr/poses.gd")
const Art=preload("res://deathmatch/art.gd")
const W=preload("res://deathmatch/weapons.gd")
const RoomScale=preload("res://deathmatch/vr/room_scale.gd")
const Preferences=preload("res://deathmatch/vr/preferences.gd")
const UI_LAYER := 1<<22
var control_edges: Dictionary={}
var support_aim=preload("res://deathmatch/vr/aim_support.gd").new()
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
	simulated=test_mode
	var xr:=XRServer.find_interface("OpenXR")
	if simulated and xr and xr.is_initialized(): xr.uninitialize()
	if not simulated and (not xr or not xr.is_initialized()): return false
	enabled=true
	var settings:=Preferences.read_settings()
	smooth_turn=settings.smooth_turn;turn_speed=settings.turn_speed;snap_angle=settings.snap_angle
	left_controls=settings.left_controls;seated=settings.seated
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
		get_viewport().use_xr=true
		# Full-rate PC shading keeps streamed headset imagery and the HUD clear.
		get_viewport().vrs_mode=Viewport.VRS_XR if OS.has_feature("android") else Viewport.VRS_DISABLED
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
	eyes=preload("res://deathmatch/vr/eyes.gd").new()
	add_child(eyes)
	eyes.setup(self)
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
	status_viewport.size=Vector2i(960,180)
	status_viewport.transparent_bg=true
	status_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(status_viewport)
	status_hud=preload("res://deathmatch/vr/status_hud.gd").new()
	status_hud.size=Vector2(960,180);status_hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	status_viewport.add_child(status_hud)
	status_surface=MeshInstance3D.new()
	var status_quad:=QuadMesh.new();status_quad.size=Vector2(.96,.18)
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
	support_aim.reset();jump_detector.reset()
	if not enabled: return
	if seated:
		# Translate the tracking space, preserving real-world reach and movement.
		var physical_height:=head.position.y/XRServer.world_scale
		XRServer.world_scale=1.0
		seated_height_offset=clampf(1.65-physical_height,-.5,1.4)
	elif not simulated and head.position.y>.5:
		XRServer.world_scale=clampf(XRServer.world_scale*1.65/head.position.y,.65,1.5)
	origin_offset=Vector3(-head.position.x,0,-head.position.z)
	calibration_pending=false
	if tracking: tracking.corrections.clear();tracking.native_corrections.clear()
	place_menu()
func on_spawn() -> void:
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
		if pressed and not control_edges.get(action,false):
			match action:
				"menu":toggle_menu()
				"scores":
					scores=not scores
					if scores:place_menu()
				"use":
					if game.active and not game.menu_open:
						if multiplayer.is_server():game._use_for(multiplayer.get_unique_id())
						else:game._use_request.rpc_id(1)
		control_edges[action]=pressed
func weapon_pose() -> Transform3D:
	var hand: XRController3D=left if left_handed else right
	var aim: XRController3D=left_aim if left_handed else right_aim
	var other: XRController3D=right if left_handed else left
	var held:=Poses.held_weapon(hand.transform,aim.transform)
	var valid: bool=game.bindings.two_handed and not game.menu_open and not scores and focused and (simulated or (hand.get_has_tracking_data() and aim.get_has_tracking_data() and other.get_has_tracking_data()))
	return support_aim.solve(held,other.transform,game.local_state().get("weapon",game.desired_weapon),game.bindings.vr_pressed(self,"support"),valid)
func update_seated(body: Dictionary) -> void:
	seated_active=seated and not (tracking and tracking.has_body_pose(body))
	origin_offset.y=seated_height_offset if seated_active else 0.0
func toggle_menu() -> void:
	game.menu_open=not game.menu_open or not game.active
	game.hud.show_menu(game.menu_open)
	scores=false
	if game.menu_open: place_menu()
func _process(delta: float) -> void:
	if not enabled: return
	poll_controls()
	left.visible=simulated or left.get_has_tracking_data()
	right.visible=simulated or right.get_has_tracking_data()
	var fingers: Dictionary=tracking.sample() if tracking else {}
	for i in range(hand_animators.size()):
		hand_animators[i].curls=fingers.get("left_curls" if i==0 else "right_curls",PackedFloat32Array([0,0,0,0,0]))
	var mine:=multiplayer.get_unique_id()
	var actor=game.fighters.get(mine)
	if actor:
		global_transform=Transform3D(Basis(Vector3.UP,game.local_yaw),actor.position)
	elif not game.spawn_points.is_empty():
		global_transform=Transform3D(Basis(Vector3.UP,game.spawn_yaws[0] if not game.spawn_yaws.is_empty() else 0.0),game.spawn_points[0])
	update_seated(fingers)
	jump_detector.sample(head.position.y,delta,game.bindings.physical_jump and not seated_active and not calibration_pending and focused and not game.menu_open and head_tracked() and actor!=null and not game.local_state().get("dead",true),actor!=null and actor.is_on_floor())
	origin.position=origin_offset+Vector3.UP*(actor.view_offset if actor else 0.0)
	if calibration_pending and (simulated or head.position.y>.5): recenter()
	if actor and not game.menu_open and focused:
		var stick: Vector2=game.bindings.axis(self,"turn")
		apply_turn(stick.x,delta)
		if absf(stick.y)>.75 and not cycle_latched and not game.local_state().get("spectator",false):
			game.desired_weapon=W.next_owned(game.desired_weapon,1 if stick.y>0 else -1,game.local_state().get("owned",[2]))
			cycle_latched=true
		if absf(stick.y)<.3: cycle_latched=false
	var menu_visible: bool=game.menu_open or scores or game.intermission>0 or not game.active
	damage_overlay.visible=game.hurt_flash>0 and focused and not menu_visible
	damage_material.set_shader_parameter("strength",clampf(game.hurt_flash/.35,0,1))
	if menu_visible and not last_panel: place_menu()
	last_panel=menu_visible
	status_surface.visible=actor!=null and focused and not menu_visible
	if not menu_visible:turn_panel.hide()
	panel.visible=menu_visible
	panel.enabled=menu_visible
	var focused_control=focused_edit()
	keyboard.visible=menu_visible and (focused_control is LineEdit or focused_control is TextEdit)
	keyboard.enabled=keyboard.visible
	for i in range(pointers.size()):
		pointers[i].enabled=menu_visible and focused and (simulated or (left_aim if i==0 else right_aim).get_has_tracking_data())
		pointers[i].visible=pointers[i].enabled
	if actor:
		var s: Dictionary=game.local_state()
		var leader:=0
		for player in game.players.values():leader=maxi(leader,player.kills)
		status_hud.update_status(s,game.round_left,game.frag_limit,leader,game.intermission>0,game.voice and game.voice.transmitting,_objective_hud(s))
		if s.weapon!=gun_id:
			if is_instance_valid(gun): gun.free()
			if is_instance_valid(offhand_gun): offhand_gun.free()
			offhand_gun=null
			if s.weapon==2:
				offhand_gun=Art.weapon(2);add_child(offhand_gun)
			gun=Art.weapon(s.weapon)
			(left_aim if left_handed else right_aim).add_child(gun)
			gun_id=s.weapon
		if gun.get_parent()!=(left_aim if left_handed else right_aim): gun.reparent(left_aim if left_handed else right_aim,false)
		gun.visible=not game.lobby.active() and not s.dead and not menu_visible and (simulated or ((left_aim if left_handed else right_aim).get_has_tracking_data() and (left if left_handed else right).get_has_tracking_data()))
		var grip: XRController3D=left if left_handed else right
		var aim: XRController3D=left_aim if left_handed else right_aim
		gun.global_transform=Art.held_transform(origin.global_transform*weapon_pose(),s.weapon)
		if is_instance_valid(offhand_gun):
			var other_grip: XRController3D=right if left_handed else left
			var other_aim: XRController3D=right_aim if left_handed else left_aim
			offhand_gun.visible=not game.lobby.active() and not s.dead and not menu_visible and focused and (simulated or (other_grip.get_has_tracking_data() and other_aim.get_has_tracking_data()))
			offhand_gun.global_transform=Art.held_transform(Poses.held_weapon(other_grip.global_transform,other_aim.global_transform),2)
		# Local IK reads current tracking directly; it must not wait for a network echo.
		var pose:=sample_pose()
		actor.xr_pose=pose
		actor.set_local_body(not menu_visible and focused and tracking.enabled and tracking.has_body_pose(pose.get("body",{})))
		for model in hand_models: model.visible=not actor.local_body_visible
		var from: Vector3=actor.position+Vector3.UP*1.45
		var wall:=PhysicsRayQueryParameters3D.create(from,head.global_position,1)
		blackout.visible=not s.spectator and (not game.get_world_3d().direct_space_state.intersect_ray(wall).is_empty() or head.global_position.distance_to(from)>1.3)
	else:
		for model in hand_models: model.visible=true
		if gun: gun.visible=false
		if offhand_gun: offhand_gun.visible=false
		blackout.visible=false
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
	return Preferences.save_settings({"smooth_turn":smooth_turn,"turn_speed":turn_speed,"snap_angle":snap_angle,"left_controls":left_controls,"seated":seated})
func sample_pose() -> Dictionary:
	var aim: XRController3D=left_aim if left_handed else right_aim
	var hand: XRController3D=left if left_handed else right
	var pose: Dictionary={"head":origin.transform*head.transform,"left":origin.transform*left.transform,"right":origin.transform*right.transform,"weapon":origin.transform*weapon_pose(),"left_handed":left_handed}
	var other_hand: XRController3D=right if left_handed else left
	var other_aim: XRController3D=right_aim if left_handed else left_aim
	if simulated or (other_hand.get_has_tracking_data() and other_aim.get_has_tracking_data()):
		pose.offhand_weapon=origin.transform*Poses.held_weapon(other_hand.transform,other_aim.transform)
	pose.body=tracking.sample() if tracking else {}
	for i in range(hand_animators.size()):
		hand_animators[i].curls=pose.body.get("left_curls" if i==0 else "right_curls",PackedFloat32Array([0,0,0,0,0]))
	pose.face=eyes.sample() if eyes else {}
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
	var other_hand: XRController3D=right if left_handed else left
	var other_trigger: bool=game.bindings.vr_pressed(self,"offhand_fire")
	var room:=Vector3.ZERO
	if not blocked and not pose.is_empty():
		var horizontal:=Vector3(pose.head.origin.x,0,pose.head.origin.z)
		room=RoomScale.request(horizontal)
	var jump: bool=game.bindings.vr_pressed(self,"jump") or jump_detector.consume()
	return {"seq":sequence,"fly":game.bindings.axis(self,"turn").y if game.local_state().get("spectator",false) and not blocked else 0.0,"move":Vector2(movement.x,movement.z).limit_length(1),"yaw":game.local_yaw,"pitch":0.0,"melee":not blocked and tracked and not pose.is_empty() and not blackout.visible,"offhand_fire":other_trigger and game.desired_weapon==2 and not blocked and pose.has("offhand_weapon") and not blackout.visible,"fire":trigger and not blocked and tracked and not pose.is_empty() and not blackout.visible,"weapon":game.desired_weapon,"slow":game.bindings.vr_pressed(self,"slow"),"jump":not blocked and jump,"respawn":not blocked and (trigger or game.bindings.vr_pressed(self,"jump")),"xr":pose,"room":room}
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
	if mode.kind=="ft" and mode.special.frozen.has(game.multiplayer.get_unique_id()):return "FROZEN · THAW %.1f / 3s"%mode.special.frozen[game.multiplayer.get_unique_id()]
	var extra: String=" [R]" if s.team==0 else " [B]" if s.team==1 else ""
	if mode.kind=="koth":extra+=" CONTESTED" if mode.hill_owner==-2 else " HOLD" if mode.hill_owner==s.team and s.team>=0 else ""
	if mode.kind=="ctf" and mode.flags.size()==2:
		for flag in mode.flags:
			if flag.carrier==game.multiplayer.get_unique_id():extra+=" CARRYING FLAG"
	return "%s R%d B%d / %d"%[mode.kind.to_upper(),mode.scores[0],mode.scores[1],mode.limit()]+extra

func head_tracked() -> bool:
	if simulated:return true
	var tracker=XRServer.get_tracker("head")
	if tracker==null:return false
	var pose=tracker.get_pose("default")
	return pose!=null and pose.has_tracking_data
