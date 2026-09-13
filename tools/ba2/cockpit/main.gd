extends Node3D
## Local BA-2 cockpit laboratory. Never joins or changes a running match.
const Controls=preload("res://tools/ba2/cockpit/controls.gd")
const Joystick=preload("res://tools/ba2/cockpit/joystick.gd")
const SEAT=Vector3(0,-4096,0)
const EYE=Vector3(0,1.25,0)
var controls=Controls.new()
var game
var pilot
var rig
var room: Node3D
var console: Node3D
var feed: SubViewport
var range_root: Node3D
var robot: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var camera: Camera3D
var hud
var sticks: Array[Node3D]=[]
var grips: Array[Vector3]=[]
var grabbed: Array[bool]=[false,false]
var previous_grip: Array[bool]=[true,true]
var grab_start: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var buttons: Array[StandardMaterial3D]=[]
var stick_axes: Array[Vector2]=[Vector2.ZERO,Vector2.ZERO]
var mounts: Array=[]
var targets: Array=[]
var impacts: Array[Vector2]=[Vector2.ZERO,Vector2.ZERO]
var hits: Array[int]=[0,0]
var rounds: Array[int]=[0,0]
var aim_points: Array[Vector3]=[Vector3.ZERO,Vector3.ZERO]
var obstructed: Array[bool]=[false,false]
var elapsed:=0.0
var route_time:=0.0
var walking:=true
var ready_for_input:=false
var focused:=true
var transient: Array=[]
var test_mode:=false
var screen: MeshInstance3D
var audio_players: Array[AudioStreamPlayer]=[]
var seat_tracking_ready:=false

func _ready() -> void:
	test_mode=OS.get_cmdline_user_args().has("--cockpit-test")
	game=load("res://deathmatch/arena.tscn").instantiate();add_child(game)
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);game.set_process_input(false)
	game.voice.set_mode(0);game.voice.set_process(false)
	game.music.stop();game.music.set_process(false)
	if game.hud:game.hud.hide();game.hud.set_process(false)
	for child in game.get_node("Map").get_children():child.queue_free()
	game.pickups.clear();game.current_map=game.lobby.ID
	game.spawn_points=[SEAT];game.spawn_yaws=[0.0]
	game.multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	game._add_player(1,"BA-2 Pilot")
	pilot=game.fighters[1];pilot.position=SEAT;pilot.velocity=Vector3.ZERO
	pilot.set_physics_process(false);pilot.stepped_last_frame=true;pilot.set_local_body(true)
	room=Node3D.new();room.name="RemoteCockpit";add_child(room);room.position=SEAT
	build_room();build_range()
	for side in 2:
		var sound:=AudioStreamPlayer.new();add_child(sound);sound.stream=load("res://deathmatch/audio/weapon_4.wav");sound.volume_db=-17;sound.bus="ArenaEffects";sound.max_polyphony=3;audio_players.append(sound)
	rig=game.xr_rig if game.is_vr() else null
	if rig:
		rig.set_process(false);rig.calibration_pending=false
		for obj in [rig.panel,rig.keyboard,rig.status_surface,rig.damage_overlay,rig.blackout]:
			if is_instance_valid(obj):obj.hide();obj.process_mode=Node.PROCESS_MODE_DISABLED
		for pointer in rig.pointers:pointer.hide();pointer.process_mode=Node.PROCESS_MODE_DISABLED
		for controller in [rig.left,rig.right]:
			for connection in controller.button_pressed.get_connections():controller.button_pressed.disconnect(connection.callable)
			controller.button_pressed.connect(func(button):
				if button=="by_button":recenter_seat()
				if button=="ax_button":calibrate_seated_trackers(true))
		XRServer.world_scale=1.0
		rig.position=SEAT
		recenter_seat()
	else:
		var viewer:=Camera3D.new();room.add_child(viewer);viewer.position=EYE;viewer.near=.03;viewer.fov=78;viewer.make_current();game.camera=viewer
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	ready_for_input=true
	print("BA2_COCKPIT_READY xr=",rig!=null," isolated_world=",feed.world_3d!=get_world_3d())
	if test_mode:run_checks.call_deferred()

func material(color: Color,glow: float=0.0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.72
	if glow>0:m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=glow
	return m
func box(parent: Node3D,pos: Vector3,size: Vector3,color: Color,solid: bool=false) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=size;mesh.mesh=shape;mesh.material_override=material(color);parent.add_child(mesh);mesh.position=pos
	if solid:
		var body:=StaticBody3D.new();parent.add_child(body);body.position=pos
		var col:=CollisionShape3D.new();var b:=BoxShape3D.new();b.size=size;col.shape=b;body.add_child(col)
	return mesh
func label3(parent: Node3D,text: String,pos: Vector3,size: int=32) -> void:
	var label:=Label3D.new();parent.add_child(label);label.text=text;label.position=pos;label.font_size=size;label.pixel_size=.0014;label.modulate=Color("80e9df");label.no_depth_test=false
func build_room() -> void:
	var layout=preload("res://deathmatch/vehicles/ba2/cockpit_room.gd").new()
	layout.build(room)
	console=layout.console;sticks=layout.sticks;buttons=layout.buttons;grips=layout.grips

func build_range() -> void:
	feed=SubViewport.new();feed.name="RobotCameraFeed";feed.size=Vector2i(1280,720);feed.own_world_3d=true;feed.render_target_update_mode=SubViewport.UPDATE_ALWAYS;feed.msaa_3d=Viewport.MSAA_2X;add_child(feed)
	range_root=Node3D.new();feed.add_child(range_root)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("111f31");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("8ba6c4");env.environment.ambient_light_energy=.7;range_root.add_child(env)
	var sun:=DirectionalLight3D.new();range_root.add_child(sun);sun.rotation_degrees=Vector3(-50,30,0);sun.light_energy=1.5
	box(range_root,Vector3(0,-.2,50),Vector3(100,.3,180),Color("26363d"),true)
	for x in range(-30,31,5):box(range_root,Vector3(x,.005,50),Vector3(.035,.02,160),Color("487074"))
	for z in range(-20,141,5):box(range_root,Vector3(0,.008,z),Vector3(70,.02,.035),Color("487074"))
	for x in [-24,24]:box(range_root,Vector3(x,5,50),Vector3(2,10,130),Color("273849"),true)
	for z in [30,50,75]:
		for x in [-7,0,7]:
			var target:=StaticBody3D.new();range_root.add_child(target);target.position=Vector3(x,6,z);target.set_meta("target",true)
			box(target,Vector3.ZERO,Vector3(2.6,4,.4),Color("c7784d"))
			box(target,Vector3(0,0,-.22),Vector3(.06,3,.02),Color("ffe3a2"));box(target,Vector3(0,0,-.24),Vector3(1.8,.06,.02),Color("ffe3a2"))
			var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(2.6,4,.4);collision.shape=shape;target.add_child(collision);targets.append(target)
	var doc:=GLTFDocument.new();var state:=GLTFState.new()
	assert(doc.append_from_file("res://tools/ba2/animated/BA2-10m-walk.glb",state)==OK)
	robot=doc.generate_scene(state);range_root.add_child(robot)
	skeleton=robot.find_children("*","Skeleton3D",true,false)[0];animation=robot.find_child("AnimationPlayer",true,false)
	animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;animation.get_animation("WalkLoop").loop_mode=Animation.LOOP_LINEAR;animation.play("WalkStart");animation.advance(0)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/ba2/cockpit/mounts.json"))
	for side in ["L","R"]:
		var row: Dictionary=data[side];var v: Array=row.muzzle_local;var index:=skeleton.find_bone(row.bone);assert(index>=0)
		mounts.append({"bone":index,"point":Vector3(v[0],v[1],v[2]),"barrels":row.muzzles_local.map(func(p):return Vector3(p[0],p[1],p[2])),"rest":skeleton.get_bone_rest(index).basis,"pitch_sign":signf((skeleton.global_basis*skeleton.get_bone_global_rest(index).basis.z).y)})
	camera=Camera3D.new();range_root.add_child(camera);camera.fov=70;camera.near=.1;camera.far=180;camera.make_current()
	hud=load("res://tools/ba2/cockpit/hud.gd").new();hud.station=self;feed.add_child(hud);hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(3.2,1.8);screen.mesh=quad;console.add_child(screen);screen.position=Vector3(0,1.49,-2.17)
	var surface:=StandardMaterial3D.new();surface.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;surface.albedo_texture=feed.get_texture();surface.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR;screen.material_override=surface
	update_robot(0)

func recenter_seat() -> void:
	if not rig:return
	# Translate/yaw only: no player locomotion, world scaling, or calibration reset.
	var forward: Vector3=-rig.head.transform.basis.z
	var yaw:=atan2(-forward.x,-forward.z)
	rig.origin.basis=Basis(Vector3.UP,-yaw)
	var centred: Vector3=rig.origin.basis*rig.head.position
	rig.origin.position=Vector3(-centred.x,0,-centred.z)
	# Keep the tracking floor and full-body posture intact. The furniture adapts
	# to a standing or seated pilot; the chair never constrains the tracked rig.
	console.position.y=clampf(centred.y-EYE.y,-.55,.95)
	for side in 2:grips[side]=console.transform*sticks[side].transform*Vector3(0,.19,0)
	rig.origin_offset=Vector3.ZERO;rig.crouch_height=1.65
	for side in 2:grabbed[side]=false;previous_grip[side]=true
func calibrate_seated_trackers(force: bool) -> void:
	if not rig or not rig.focused:return
	var tracking=rig.tracking
	# External trackers need mount orientation corrections. Preserve measured
	# joint positions: the normal standing calibration would straighten the legs.
	var slime: Dictionary=tracking.osc.current(Time.get_ticks_msec()*.001)
	if slime.has("head") and (force or tracking.corrections.is_empty()):
		var source: Transform3D=slime.head
		var heading:=Basis(Vector3.UP,rig.head.rotation.y-source.basis.get_euler().y)
		tracking.osc_alignment=Transform3D(heading,rig.head.position-heading*source.origin*XRServer.world_scale)
	var raw: Dictionary=tracking.external()
	for key in raw:
		if force or not tracking.corrections.has(key):
			tracking.corrections[key]=Transform3D(raw[key].basis.inverse(),Vector3.ZERO)
	if force and not raw.is_empty():rig._body_calibrated()

func joystick_input(side: int,hand_local: Vector3,grip: bool,trigger: bool,tracked: bool) -> bool:
	if not focused or not tracked:
		grabbed[side]=false;previous_grip[side]=true;stick_axes[side]=Vector2.ZERO;return false
	if not grip:grabbed[side]=false
	elif not previous_grip[side] and hand_local.distance_to(grips[side])<.23:
		grabbed[side]=true;grab_start[side]=hand_local
	previous_grip[side]=grip
	if hand_local.distance_to(grips[side])>.5:grabbed[side]=false
	if grabbed[side]:
		stick_axes[side]=Joystick.axis(hand_local-grab_start[side])
	else:stick_axes[side]=Vector2.ZERO
	return grabbed[side] and trigger
func _process(delta: float) -> void:
	if not ready_for_input:return
	elapsed+=delta
	var fire: Array=[false,false]
	if rig:
		focused=rig.focused
		if not seat_tracking_ready and (rig.simulated or rig.head.position.length()>.1):
			recenter_seat();seat_tracking_ready=true
		rig.position=SEAT;rig.rotation=Vector3.ZERO
		calibrate_seated_trackers(false)
		pilot.xr_pose=rig.sample_pose();game.players[1].xr=pilot.xr_pose
		for side in 2:
			var hand: XRController3D=rig.left if side==0 else rig.right
			fire[side]=joystick_input(side,room.to_local(hand.global_position),hand.get_float("grip")>.65,hand.get_float("trigger")>.55,rig.simulated or hand.get_has_tracking_data())
			if side<rig.hand_models.size():rig.hand_models[side].visible=not pilot.local_body_visible or pilot.avatar_hash.is_empty()
	else:
		stick_axes[1]=Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_DOWN)))
		fire=[Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)]
	pilot.position=SEAT;pilot.velocity=Vector3.ZERO
	pilot.set_local_body(rig!=null)
	var fired: Array=controls.step(delta,stick_axes[1],fire,focused)
	update_robot(delta)
	for side in fired:shoot(side)
	for side in 2:
		buttons[side].albedo_color=Color("ff745e") if controls.locked[side] else (Color("8ce9df") if grabbed[side] else Color("ff8861"))
		sticks[side].get_node("Pivot").quaternion=Joystick.tilt(stick_axes[side])
		var ray:=muzzle(side);var hit:=cast(ray.origin,ray.basis.y.normalized())
		aim_points[side]=hit.position
		impacts[side]=camera.unproject_position(hit.position)
		obstructed[side]=false
		for barrel in 2:
			var source:=muzzle(side,barrel).origin
			var endpoint:=cast(source,(aim_points[side]-source).normalized(),source.distance_to(aim_points[side])+.04)
			if endpoint.position.distance_to(aim_points[side])>.25:obstructed[side]=true
	for entry in transient.duplicate():
		entry.life-=delta
		if entry.life<=0:entry.node.queue_free();transient.erase(entry)
	hud.queue_redraw()
func update_robot(delta: float) -> void:
	if walking:
		delta=minf(delta,maxf(0,34.6-route_time))
		route_time+=delta
		if route_time>=34.6:walking=false
		var clip:="WalkStart" if route_time<6.6 else "WalkLoop"
		if animation.current_animation!=clip:animation.play(clip)
		animation.seek(route_time if route_time<6.6 else fmod(route_time-6.6,5.6),true);animation.advance(0)
		var t:=route_time
		robot.position.z=.9*(pow(t/2,3)-.5*pow(t/2,4)) if t<2 else .45*(t-1)
	# Latest authored rig: the cannon mount is a single local-X hinge.
	for mount in mounts:
		var hinge:=Basis(Vector3.RIGHT,deg_to_rad(controls.aim.y)*mount.pitch_sign)
		skeleton.set_bone_pose_rotation(mount.bone,(mount.rest.orthonormalized()*hinge).get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()
	var body:=skeleton.get_bone_global_pose(skeleton.find_bone("Body"))
	var body_origin: Vector3=skeleton.global_transform*body.origin
	# Camera is forward of the body, between the guns; a fixed monoscopic feed.
	var body_rotation: Basis=(skeleton.global_basis*body.basis*skeleton.get_bone_global_rest(skeleton.find_bone("Body")).basis.inverse()).orthonormalized()
	camera.position=body_origin+body_rotation*Vector3(0,1.3,4.8)
	camera.basis=body_rotation*Basis(Vector3.UP,PI)
func muzzle(side: int,barrel: int=-1) -> Transform3D:
	var mount: Dictionary=mounts[side]
	var bone: Transform3D=skeleton.global_transform*skeleton.get_bone_global_pose(mount.bone)
	return Transform3D(bone.basis,bone*(mount.point if barrel<0 else mount.barrels[barrel]))
func cast(from: Vector3,direction: Vector3,distance: float=150.0) -> Dictionary:
	var to:=from+direction*distance
	var query:=PhysicsRayQueryParameters3D.create(from,to,1)
	var result:=range_root.get_world_3d().direct_space_state.intersect_ray(query)
	return result if not result.is_empty() else {"position":to,"collider":null}
func shoot(side: int) -> void:
	if side<audio_players.size():audio_players[side].play()
	var axis:=muzzle(side)
	var aim: Vector3=cast(axis.origin,axis.basis.y.normalized()).position
	# One trigger cycle, sound, haptic and heat increment per pair. Every barrel
	# still performs its own collision ray to prevent firing through cover.
	for barrel in 2:
		var source:=muzzle(side,barrel).origin
		var hit:=cast(source,(aim-source).normalized(),source.distance_to(aim)+.04)
		var to: Vector3=hit.position;rounds[side]+=1
		if is_instance_valid(hit.collider) and hit.collider.get_meta("target",false):hits[side]+=1
		var beam:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.top_radius=.035;shape.bottom_radius=.035;shape.height=source.distance_to(to);beam.mesh=shape
		range_root.add_child(beam);beam.position=(source+to)*.5
		beam.quaternion=Quaternion(Vector3.UP,(to-source).normalized());beam.material_override=material(Color("ffcd7e"),2);transient.append({"node":beam,"life":.075})
		var flash:=box(range_root,to,Vector3(.18,.18,.18),Color("ffdca1"));flash.material_override=material(Color("ffdca1"),2);transient.append({"node":flash,"life":.12})
	if rig:
		var hand: XRController3D=rig.left if side==0 else rig.right
		hand.trigger_haptic_pulse("haptic",0,.3,.065,0)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:get_tree().quit()
		if event.keycode==KEY_R:recenter_seat()
		if event.keycode==KEY_C:calibrate_seated_trackers(true)
		if event.keycode==KEY_SPACE:walking=not walking
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:focused=false;grabbed=[false,false];previous_grip=[true,true]
	if what==NOTIFICATION_APPLICATION_FOCUS_IN:focused=true
	if what==NOTIFICATION_WM_CLOSE_REQUEST:get_tree().quit()

func run_checks() -> void:
	await get_tree().physics_frame
	var checks: Array=[]
	var circle_valid:=true
	for i in 16:
		var direction:=Vector2.from_angle(TAU*i/16)
		var axis:=Joystick.axis(Vector3(direction.x,0,-direction.y)*Joystick.RADIUS)
		var shaft: Vector3=Joystick.tilt(axis)*Vector3.UP
		circle_valid=circle_valid and axis.is_equal_approx(direction) and absf(shaft.angle_to(Vector3.UP)-Joystick.VISUAL_TILT)<.0001
	checks.append(["circular hand travel has uniform visual tilt",circle_valid])
	checks.append(["small hand jitter stays neutral",Joystick.axis(Vector3(.005,.05,.005))==Vector2.ZERO])
	checks.append(["vertical hand movement does not tilt stick",Joystick.axis(Vector3(0,.15,0))==Vector2.ZERO])
	var just_outside:=Joystick.axis(Vector3(Joystick.RADIUS*(Joystick.DEADZONE+.001),0,0))
	checks.append(["smooth entry through joystick deadzone",just_outside.length()>0 and just_outside.length()<.002])
	checks.append(["circular gate clamps excessive hand travel",is_equal_approx(Joystick.axis(Vector3(.3,0,-.3)).length(),1.0)])
	var c=Controls.new()
	for i in 600:c.step(1.0/60,Vector2(1,1),[true,false])
	checks.append(["aim limits",c.aim.is_equal_approx(Controls.LIMIT)])
	checks.append(["independent overheat",c.shots[0]==8 and c.shots[1]==0 and c.locked[0]])
	for i in 600:c.step(1.0/60,Vector2.ZERO,[false,false])
	checks.append(["cooldown recovers after release",not c.locked[0] and c.heat[0]==0])
	var before: int=c.shots[0];c.step(.1,Vector2.ONE,[true,true],false)
	checks.append(["disabled cannot fire",c.shots[0]==before and c.shots[1]==0])
	focused=true;joystick_input(0,grips[0],false,false,true)
	checks.append(["grip acquires and fires",joystick_input(0,grips[0],true,true,true)])
	checks.append(["loss stops fire",not joystick_input(0,grips[0],true,true,false)])
	checks.append(["recovery requires fresh grip",not joystick_input(0,grips[0],true,true,true)])
	checks.append(["cockpit world isolated",feed.world_3d!=get_world_3d()])
	walking=false;controls.aim=Vector2.ZERO;update_robot(0)
	var zero: Vector3=muzzle(0).basis.y.normalized()
	checks.append(["barrels face robot forward",zero.dot(Vector3.BACK)>.995])
	controls.aim=Controls.LIMIT;update_robot(0)
	var aimed: Vector3=muzzle(0).basis.y.normalized()
	checks.append(["hinge aims up without sideways swivel",absf(aimed.x-zero.x)<.005 and aimed.y>zero.y+.03])
	for mount in mounts:
		var relative: Vector3=(mount.rest.inverse()*Basis(skeleton.get_bone_pose_rotation(mount.bone))).get_euler()
		checks.append(["cannon only rotates around local X",absf(relative.y)<.0001 and absf(relative.z)<.0001 and absf(rad_to_deg(relative.x))<=4.001])
	checks.append(["both cannons track together",aimed.dot(muzzle(1).basis.y.normalized())>.999])
	controls.aim=Vector2.ZERO;update_robot(0)
	# Place one test plate directly on the real muzzle ray, not on the camera centre.
	var start:=muzzle(0);targets[0].position=start.origin+start.basis.y.normalized()*15
	await get_tree().physics_frame
	var before_hits: int=hits[0];var before_rounds: int=rounds[0]
	shoot(0);checks.append(["paired muzzles both hit their aim target",hits[0]-before_hits==2 and rounds[0]-before_rounds==2 and rounds[1]==0])
	var aim: Vector3=cast(muzzle(0).origin,muzzle(0).basis.y.normalized()).position
	var endpoints: Array[Vector3]=[]
	for barrel in 2:
		var source:=muzzle(0,barrel).origin
		endpoints.append(cast(source,(aim-source).normalized(),source.distance_to(aim)+.04).position)
	checks.append(["upper and lower shots converge",endpoints[0].distance_to(endpoints[1])<.01 and endpoints[0].distance_to(aim)<.01])
	checks.append(["separate real barrel origins",muzzle(0,0).origin.distance_to(muzzle(0,1).origin)>.3])
	var near:=muzzle(0,0).origin.lerp(aim,.15)
	var blocker:=StaticBody3D.new();range_root.add_child(blocker);blocker.position=near
	var blocking_shape:=CollisionShape3D.new();var small_box:=BoxShape3D.new();small_box.size=Vector3(.25,.25,.25);blocking_shape.shape=small_box;blocker.add_child(blocking_shape)
	await get_tree().physics_frame
	before_hits=hits[0];shoot(0)
	checks.append(["individual barrel respects cover",hits[0]-before_hits==1])
	blocker.queue_free()
	var head_pose:=Transform3D(Basis.IDENTITY,Vector3(.1,1.18,.08))
	pilot.xr_pose={"head":head_pose,"body":{"hips":Transform3D(Basis.IDENTITY,Vector3(0,.65,0))}}
	pilot.velocity=Vector3(4,8,2)
	await get_tree().create_timer(.15).timeout
	checks.append(["pilot immobilised",pilot.position==SEAT and pilot.velocity==Vector3.ZERO])
	checks.append(["anchored pilot is supported",pilot.is_supported()])
	if not rig:checks.append(["body targets preserved",pilot.xr_pose.head==head_pose and pilot.xr_pose.body.has("hips")])
	if rig and rig.simulated:
		var physical_height: float=rig.head.position.y
		recenter_seat()
		checks.append(["standing height preserved",is_equal_approx((rig.origin.transform*rig.head.transform).origin.y,physical_height) and is_zero_approx(rig.origin.position.y)])
		checks.append(["controls adapt to pilot height",is_equal_approx(grips[0].y,physical_height-EYE.y+.98)])
		var body:=XRBodyTracker.new();body.name="/user/ba2_test_body";body.has_tracking_data=true
		for entry in [[XRBodyTracker.JOINT_HIPS,Vector3(0,.99,.08)],[XRBodyTracker.JOINT_LEFT_FOOT,Vector3(-.2,.45,-.3)]]:
			body.set_joint_transform(entry[0],Transform3D(Basis.IDENTITY,entry[1]))
			body.set_joint_flags(entry[0],XRBodyTracker.JOINT_FLAG_POSITION_VALID|XRBodyTracker.JOINT_FLAG_ORIENTATION_VALID)
		XRServer.add_tracker(body)
		rig.head.position+=Vector3(.08,-.05,0);rig.left.position+=Vector3(-.05,.1,0)
		await get_tree().create_timer(.15).timeout
		checks.append(["live head and hand targets",pilot.xr_pose.head.origin.is_equal_approx((rig.origin.transform*rig.head.transform).origin) and pilot.xr_pose.left.origin.is_equal_approx((rig.origin.transform*rig.left.transform).origin)])
		checks.append(["native seated hips and feet",pilot.xr_pose.body.has("hips") and pilot.xr_pose.body.has("left_foot") and pilot.xr_pose.body.left_foot.origin.is_equal_approx(rig.origin.transform*Vector3(-.2,.45,-.3))])
		checks.append(["tracking cannot translate pilot",pilot.position==SEAT])
		XRServer.remove_tracker(body)
		var external:=XRPositionalTracker.new();external.name="/user/vive_tracker_htcx/role/waist";external.type=XRServer.TRACKER_CONTROLLER
		external.set_pose("tracker_pose",Transform3D(Basis(Vector3.UP,PI),Vector3(0,.95,.1)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);XRServer.add_tracker(external)
		calibrate_seated_trackers(true)
		await get_tree().create_timer(.15).timeout
		checks.append(["external seated position preserved",pilot.xr_pose.body.has("hips") and pilot.xr_pose.body.hips.origin.is_equal_approx(rig.origin.transform*Vector3(0,.95,.1))])
		XRServer.remove_tracker(external)
		await get_tree().create_timer(1).timeout
		checks.append(["loaded avatar body visible",not pilot.avatar_hash.is_empty() and pilot.local_body_visible and pilot.avatar.visible])
	if rig and rig.simulated:
		var controller_trackers: Array[XRControllerTracker]=[]
		for side in 2:
			var tracker:=XRControllerTracker.new();tracker.name="left_hand" if side==0 else "right_hand";XRServer.add_tracker(tracker);controller_trackers.append(tracker)
			var pose:=Transform3D(Basis.IDENTITY,rig.origin.transform.affine_inverse()*grips[side])
			tracker.set_pose("grip",pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_pose("aim",pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
			tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0)
		await get_tree().create_timer(.1).timeout
		for tracker in controller_trackers:tracker.set_input("grip",1.0)
		await get_tree().create_timer(.1).timeout
		var shot_count: int=controls.shots[0]
		controller_trackers[0].set_input("trigger",1.0)
		await get_tree().create_timer(.1).timeout
		checks.append(["left XR trigger fires only left turret",controls.shots[0]>shot_count and controls.shots[1]==0])
		controller_trackers[0].set_input("trigger",0.0)
		var pose:=Transform3D(Basis.IDENTITY,rig.origin.transform.affine_inverse()*(grips[1]+Vector3(.08,0,-.05)))
		controller_trackers[1].set_pose("grip",pose,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		controller_trackers[1].set_input("trigger",1.0)
		await get_tree().create_timer(.2).timeout
		checks.append(["right XR joystick aims and fires",is_zero_approx(controls.aim.x) and controls.aim.y>.1 and controls.shots[1]>0])
		for tracker in controller_trackers:tracker.set_input("grip",0.0)
		await get_tree().create_timer(.1).timeout
		shot_count=controls.shots[1]
		await get_tree().create_timer(.2).timeout
		checks.append(["grip release stops held trigger",controls.shots[1]==shot_count and not grabbed[1]])
		for tracker in controller_trackers:XRServer.remove_tracker(tracker)
	var failed:=checks.filter(func(c):return not c[1])
	var report={"checks":checks,"failures":failed,"engine":Engine.get_version_info().string,"xr":rig!=null,"avatar":pilot.avatar_hash}
	var file:=FileAccess.open(("res://test-results/ba2/cockpit/checks-vr.json" if rig else "res://test-results/ba2/cockpit/checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("BA2_COCKPIT_CHECKS ",JSON.stringify(report))
	await get_tree().create_timer(2).timeout
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://test-results/ba2/cockpit/cockpit.png")
		feed.get_texture().get_image().save_png("res://test-results/ba2/cockpit/feed.png")
	get_tree().quit(0 if failed.is_empty() else 1)
