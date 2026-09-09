extends Node3D
const Poses=preload("res://deathmatch/vr/poses.gd")
const Art=preload("res://deathmatch/art.gd")
const W=preload("res://deathmatch/weapons.gd")
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
var panel
var keyboard
var wrist: Label3D
var blackout: MeshInstance3D
var gun: Node3D
var gun_id:=-1
var origin_offset:=Vector3.ZERO
var turn_latched:=false
var cycle_latched:=false
var scores:=false
var left_handed:=false
var smooth_turn:=true
var last_panel:=false
var focused:=true
var calibration_pending:=true
var room_delta:=Vector3.ZERO
func setup(arena: Node, test_mode: bool=false) -> bool:
	game=arena
	simulated=test_mode
	var xr:=XRServer.find_interface("OpenXR")
	if simulated and xr and xr.is_initialized(): xr.uninitialize()
	if not simulated and (not xr or not xr.is_initialized()): return false
	enabled=true
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
		var pointer=load("res://addons/godot-xr-tools/functions/function_pointer.tscn").instantiate()
		pointer.distance=6
		item[0].add_child(pointer)
		pointers.append(pointer)
	left.button_pressed.connect(left_button)
	right.button_pressed.connect(right_button)
	if not simulated:
		get_viewport().use_xr=true
		get_viewport().vrs_mode=Viewport.VRS_XR
		if xr.has_signal("session_begun"): xr.connect("session_begun",configure_refresh_rate)
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
	panel.collision_layer=1<<22
	panel.unshaded=true
	var ui_material:=StandardMaterial3D.new()
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
	keyboard.screen_size=Vector2(1.4,.5)
	keyboard.collision_layer=1<<22
	keyboard.material=ui_material.duplicate()
	add_child(keyboard)
	wrist=Label3D.new()
	wrist.font_size=36
	wrist.pixel_size=.0018
	wrist.outline_size=8
	wrist.modulate=Color("80f2e6")
	wrist.position=Vector3(0,.09,.06)
	wrist.rotation_degrees=Vector3(-75,0,0)
	left.add_child(wrist)
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
	place_menu()
func place_menu() -> void:
	if not panel: return
	var yaw:=head.global_rotation.y
	panel.global_transform=Transform3D(Basis(Vector3.UP,yaw),head.global_position+Basis(Vector3.UP,yaw)*Vector3(0,-.05,-1.8))
	keyboard.global_transform=panel.global_transform*Transform3D(Basis(Vector3.RIGHT,-.2),Vector3(0,-1.0,.15))
func recenter() -> void:
	if not enabled: return
	if not simulated and head.position.y>.5:
		XRServer.world_scale=clampf(XRServer.world_scale*1.65/head.position.y,.65,1.5)
	origin_offset=Vector3(-head.position.x,0,-head.position.z)
	calibration_pending=false
	if tracking: tracking.corrections.clear()
	place_menu()
func on_spawn() -> void:
	origin_offset=Vector3(-head.position.x,0,-head.position.z)
	scores=false
func left_button(action: String) -> void:
	if action=="by_button":
		scores=not scores
		if scores: place_menu()
	elif action=="menu_button": toggle_menu()
	elif action=="ax_button" and game.active and not game.menu_open:
		if multiplayer.is_server(): game._use_for(multiplayer.get_unique_id())
		else: game._use_request.rpc_id(1)
func right_button(action: String) -> void:
	if action=="by_button": toggle_menu()
func toggle_menu() -> void:
	game.menu_open=not game.menu_open or not game.active
	game.hud.show_menu(game.menu_open)
	scores=false
	if game.menu_open: place_menu()
func _process(delta: float) -> void:
	if not enabled: return
	left.visible=simulated or left.get_has_tracking_data()
	right.visible=simulated or right.get_has_tracking_data()
	var mine:=multiplayer.get_unique_id()
	var actor=game.fighters.get(mine)
	if actor:
		global_transform=Transform3D(Basis(Vector3.UP,game.local_yaw),actor.position)
	elif not game.spawn_points.is_empty():
		global_transform=Transform3D(Basis(Vector3.UP,game.spawn_yaws[0] if not game.spawn_yaws.is_empty() else 0.0),game.spawn_points[0])
	origin.position=origin_offset
	if calibration_pending and (simulated or head.position.y>.5): recenter()
	if actor and not game.menu_open and focused:
		var stick:=right.get_vector2("primary")
		if smooth_turn: game.local_yaw=wrapf(game.local_yaw-stick.x*delta*2.1,-PI,PI)
		elif absf(stick.x)>.7 and not turn_latched:
			game.local_yaw=wrapf(game.local_yaw-signf(stick.x)*PI/6,-PI,PI)
			turn_latched=true
		if absf(stick.x)<.3: turn_latched=false
		if absf(stick.y)>.75 and not cycle_latched:
			game.desired_weapon=W.next_owned(game.desired_weapon,1 if stick.y>0 else -1,game.local_state().get("owned",[2]))
			cycle_latched=true
		if absf(stick.y)<.3: cycle_latched=false
	var menu_visible: bool=game.menu_open or scores or not game.active
	if menu_visible and not last_panel: place_menu()
	last_panel=menu_visible
	panel.visible=menu_visible
	panel.enabled=menu_visible
	var focused_control=focused_edit()
	keyboard.visible=menu_visible and (focused_control is LineEdit or focused_control is TextEdit)
	keyboard.enabled=keyboard.visible
	for i in range(pointers.size()):
		pointers[i].enabled=menu_visible and (simulated or (left if i==0 else right).get_has_tracking_data())
		pointers[i].visible=pointers[i].enabled
	if actor:
		var s: Dictionary=game.local_state()
		wrist.text="%03d HP  /  %03d ARM\n%s · %d\n%s"%[s.hp,s.armor,W.DATA[s.weapon].name,s.ammo[maxi(0,W.DATA[s.weapon].ammo)],"FRAGGED · A / trigger to respawn" if s.dead else "B menu · stick ↑↓ weapons"]
		if game.voice and game.voice.transmitting: wrist.text+="\nMIC LIVE"
		if s.weapon!=gun_id:
			if is_instance_valid(gun): gun.free()
			gun=Art.weapon(s.weapon)
			gun.scale=Vector3.ONE*.65
			(left_aim if left_handed else right_aim).add_child(gun)
			gun_id=s.weapon
		if gun.get_parent()!=(left_aim if left_handed else right_aim): gun.reparent(left_aim if left_handed else right_aim,false)
		gun.visible=not s.dead and not game.menu_open and (simulated or (left_aim if left_handed else right_aim).get_has_tracking_data())
		gun.position=Vector3(0,-.025,game.recoil*.018)
		gun.rotation.x=game.recoil*.025
		var from: Vector3=actor.position+Vector3.UP*1.45
		var wall:=PhysicsRayQueryParameters3D.create(from,head.global_position,1)
		blackout.visible=not game.get_world_3d().direct_space_state.intersect_ray(wall).is_empty() or head.global_position.distance_to(from)>1.3
	else:
		wrist.text="ENTRYWAY / ARENA VR\nTrigger: select · B: menu"
		if gun: gun.visible=false
		blackout.visible=false
func command(sequence: int) -> Dictionary:
	var blocked: bool=game.menu_open or scores or not focused
	var aim: XRController3D=left_aim if left_handed else right_aim
	var hand: XRController3D=left if left_handed else right
	var tracked: bool=simulated or (hand.get_has_tracking_data() and aim.get_has_tracking_data())
	var stick:=left.get_vector2("primary") if not blocked else Vector2.ZERO
	if stick.length()<.18: stick=Vector2.ZERO
	var movement:=Basis(Vector3.UP,head.rotation.y)*Vector3(stick.x,0,-stick.y)
	var pose: Dictionary={"head":origin.transform*head.transform,"left":origin.transform*left.transform,"right":origin.transform*right.transform,"weapon":origin.transform*aim.transform,"left_handed":left_handed}
	pose.body=tracking.sample() if tracking else {}
	pose.face=eyes.sample() if eyes else {}
	pose=Poses.validate(pose)
	var trigger: bool=hand.get_float("trigger")>.55
	var room:=Vector3.ZERO
	if not blocked and not pose.is_empty():
		var horizontal:=Vector3(pose.head.origin.x,0,pose.head.origin.z)
		if horizontal.length()>.18: room=(horizontal-horizontal.normalized()*.18).limit_length(.08)
	return {"seq":sequence,"move":Vector2(movement.x,movement.z).limit_length(1),"yaw":game.local_yaw,"pitch":0.0,"fire":trigger and not blocked and tracked and not pose.is_empty() and not blackout.visible,"weapon":game.desired_weapon,"slow":left.is_button_pressed("primary_click"),"jump":not blocked and right.is_button_pressed("ax_button"),"respawn":not blocked and (trigger or right.is_button_pressed("ax_button")),"xr":pose,"room":room}
func feedback(strength: float,seconds: float=.08) -> void:
	if enabled and not simulated: (left if left_handed else right).trigger_haptic_pulse("haptic",0,clampf(strength,0,1),seconds,0)

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
