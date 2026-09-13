extends Node3D
## Local-only interior. The pilot camera cannot render the outside world directly.
const PRIVATE_LAYER=1<<19
var game
var interior: Node3D
var feed: SubViewport
var sensor: Camera3D
var screen: MeshInstance3D
var black: Environment
var saved: Dictionary={}
var credit:=1.0
var hud: Control
func setup(arena) -> void:
	game=arena
	interior=Node3D.new();interior.name="PrivateCockpit";add_child(interior);interior.hide()
	black=Environment.new();black.background_mode=Environment.BG_COLOR;black.background_color=Color.BLACK
	var layout=preload("res://deathmatch/vehicles/ba2/cockpit_room.gd").new()
	layout.build(interior,true);interior.rotation.y=PI;layout.console.position.y=.31
	# Retain the prototype console, chair, joysticks and monitor surround.
	# Complete its shell so looking or leaning away never exposes the world.
	_box(Vector3(0,3.7,-.45),Vector3(4.2,.2,4.5),Color("15202b"))
	_box(Vector3(0,1.7,1.8),Vector3(4.2,4,.2),Color("15202b"))
	for node in interior.find_children("*","GeometryInstance3D",true,false):
		node.layers=PRIVATE_LAYER
		if node is MeshInstance3D and node.material_override:
			node.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	feed=SubViewport.new();feed.name="CockpitMonitorFeed";feed.size=Vector2i(768,432);feed.world_3d=game.get_world_3d();feed.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(feed)
	sensor=Camera3D.new();sensor.name="ForwardSensor";sensor.fov=90;sensor.near=.1;sensor.cull_mask=0xfffff&~PRIVATE_LAYER;feed.add_child(sensor);sensor.make_current()
	hud=preload("res://deathmatch/vehicles/ba2/cockpit_hud.gd").new();hud.name="MonitorHUD";feed.add_child(hud);hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	screen=MeshInstance3D.new();screen.name="Monitor";screen.layers=PRIVATE_LAYER;var quad:=QuadMesh.new();quad.size=Vector2(3.2,1.8);screen.mesh=quad;screen.position=Vector3(0,1.8,-2.17)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_texture=feed.get_texture();screen.material_override=material;interior.add_child(screen)

func _box(at: Vector3,size: Vector3,color: Color) -> void:
	var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.position=at;node.layers=PRIVATE_LAYER
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED;node.material_override=material;interior.add_child(node)
func deactivate() -> void:
	for state in saved.values():
		var camera=state.ref.get_ref()
		if is_instance_valid(camera):camera.cull_mask=state.mask;camera.environment=state.environment
	saved.clear()
	if is_instance_valid(interior):interior.hide()
	if is_instance_valid(feed):feed.render_target_update_mode=SubViewport.UPDATE_DISABLED
func update_view(pose: Transform3D,active: bool,delta: float, robot: Dictionary) -> void:
	deactivate()
	if not active or game.get_viewport().get_camera_3d()!=game.camera:return
	global_transform=pose
	# Every external camera excludes the private layer, including monitor capture.
	for camera in game.find_children("*","Camera3D",true,false):
		if camera==sensor:continue
		saved[camera.get_instance_id()]={"ref":weakref(camera),"mask":camera.cull_mask,"environment":camera.environment};camera.cull_mask&=~PRIVATE_LAYER
	var camera: Camera3D=game.camera
	camera.cull_mask=PRIVATE_LAYER;camera.environment=black;interior.show()
	var facing: Basis=pose.basis*Basis(Vector3.UP,preload("res://deathmatch/vehicles/ba2/tuning.gd").body_yaw(robot))
	sensor.global_transform=Transform3D(facing,pose.origin+facing*Vector3(0,1.8,3.1));sensor.look_at(sensor.global_position+facing.z*30,Vector3.UP)
	var player: Dictionary=game.players.get(int(robot.pilot),{})
	var tb=game.match_mode.titanball
	hud.telemetry={"hp":player.get("hp",0),"armor":player.get("armor",0),"exit_lock":robot.get("exit_lock",0.),"heat":robot.heat.duplicate(),"locked":robot.overheated.duplicate(),"speed":robot.speed,"distance":robot.distance,"remaining":maxf(0.,robot.path.get_baked_length()-float(robot.distance)),"state":robot.state,"preparation":tb.preparation_left,"time":game.round_left,"checkpoints":tb.cleared}
	credit+=delta
	if credit>=1./30.:hud.queue_redraw();credit=fmod(credit,1./30.);feed.render_target_update_mode=SubViewport.UPDATE_ONCE
func _exit_tree() -> void:deactivate()
