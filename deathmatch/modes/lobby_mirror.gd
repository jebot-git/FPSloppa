extends Node3D
## Local tracking mirror: isolated camera preview of the same avatar and IK inputs.
## No additional work or nodes on dedicated servers, no extra network pose stream.
var game
var viewport: SubViewport
var preview_root: Node3D
var avatar
var avatar_hash:=""
var accumulator:=0.0
var screen: MeshInstance3D
func setup(arena: Node) -> void:
	game=arena
	viewport=SubViewport.new();viewport.size=Vector2i(512,768);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.msaa_3d=Viewport.MSAA_2X;add_child(viewport)
	preview_root=Node3D.new();viewport.add_child(preview_root)
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("282723")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("e5d5ad");env.ambient_light_energy=.8
	environment.environment=env;viewport.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-20,0);light.light_energy=1.3;viewport.add_child(light)
	var camera:=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(0,1.05,-3.2);camera.look_at(Vector3(0,1.0,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.6;camera.current=true
	var floor_body:=StaticBody3D.new();viewport.add_child(floor_body)
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(8,.1,8);collision.shape=box;collision.position.y=-.05;floor_body.add_child(collision)
	var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(8,8);floor_mesh.mesh=plane;floor_body.add_child(floor_mesh)
	var floor_material:=StandardMaterial3D.new();floor_material.albedo_color=Color("594e3c");floor_mesh.material_override=floor_material
	screen=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(1.0,1.5);screen.mesh=quad;add_child(screen)
	var shader:=Shader.new();shader.code="shader_type spatial; render_mode unshaded; uniform sampler2D reflection : source_color; void fragment(){ ALBEDO=texture(reflection,vec2(1.0-UV.x,UV.y)).rgb; }"
	var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("reflection",viewport.get_texture());screen.material_override=material
	var label:=Label3D.new();label.text="TRACKING MIRROR\nYOUR AVATAR";label.font_size=32;label.pixel_size=.0025;label.position=Vector3(0,.9,.02);label.modulate=Color("e5d5ad");add_child(label)
func _process(delta: float) -> void:
	if not game or not game.active:return
	accumulator+=delta
	if accumulator<1.0/30.0:return
	accumulator=0
	var actor=game.fighters.get(game.multiplayer.get_unique_id())
	if not actor or actor.spectator:return
	var viewing: bool=game.camera.global_position.distance_to(global_position)<24 and game.camera.is_position_in_frustum(global_position)
	if is_instance_valid(avatar):avatar.process_mode=Node.PROCESS_MODE_INHERIT if viewing else Node.PROCESS_MODE_DISABLED
	if not viewing:return
	if avatar_hash!=actor.avatar_hash:
		if is_instance_valid(avatar):avatar.free()
		avatar_hash=actor.avatar_hash;avatar=game.avatars.library.create_avatar(avatar_hash)
		if not avatar:return
		preview_root.add_child(avatar);avatar.unarmed=true
	if not is_instance_valid(avatar):return
	preview_root.rotation.y=actor.rotation.y-global_rotation.y
	avatar.target_xr_pose=actor.xr_pose.duplicate(true);avatar.speed=actor.visual_velocity.length();avatar.movement=actor.basis.inverse()*actor.visual_velocity;avatar.aim_pitch=actor.visual_pitch
	avatar.set_first_person(false);avatar.unarmed=true
	if avatar.mouth:avatar.mouth.speak(game.voice.mouth_pose(game.multiplayer.get_unique_id()))
	if avatar.gun:avatar.gun.hide()
	if avatar.offhand_gun:avatar.offhand_gun.hide()
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
