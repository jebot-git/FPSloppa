extends Node3D
## A monocular optic. The headset keeps its runtime projection; only the lens magnifies.
const SCOPE_LAYER:=1<<19
const FOV:=6.0 # Twice the previous angular magnification; never zoom the XR headset.
var viewport: SubViewport
var camera: Camera3D
var lens: MeshInstance3D
var surface: ShaderMaterial
var weapon: Node3D
var active:=false
var rig
func setup(owner_rig) -> void:rig=owner_rig
func attach(model: Node3D) -> void:
	if is_instance_valid(weapon) and weapon==model:return
	if is_instance_valid(lens):lens.queue_free()
	weapon=model
	if not is_instance_valid(model) or not model.has_meta("scope_rear"):return
	if not viewport:
		viewport=SubViewport.new();viewport.name="SniperOptic";viewport.size=Vector2i(384,384) if OS.has_feature("android") else Vector2i(512,512)
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.msaa_3d=Viewport.MSAA_DISABLED;viewport.audio_listener_enable_3d=false
		add_child(viewport);viewport.world_3d=get_world_3d()
		camera=Camera3D.new();camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;camera.fov=FOV;camera.near=.025;camera.far=220;camera.cull_mask=((1<<20)-1)&~SCOPE_LAYER
		viewport.add_child(camera);camera.make_current()
	var mesh:=QuadMesh.new();mesh.size=Vector2.ONE*float(model.get_meta("scope_radius")) *2
	lens=MeshInstance3D.new();lens.name="ScopeLens";lens.mesh=mesh;lens.layers=SCOPE_LAYER
	lens.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(lens);lens.position=model.get_meta("scope_rear")
	surface=ShaderMaterial.new();surface.shader=preload("res://deathmatch/vr/sniper_scope.gdshader");surface.set_shader_parameter("optic",viewport.get_texture());lens.material_override=surface
	mask_weapon(model)
static func mask_weapon(node: Node) -> void:
	if node is VisualInstance3D:node.layers=SCOPE_LAYER
	for child in node.get_children():mask_weapon(child)
static func eye_quality(optic: Transform3D,eye: Transform3D) -> float:
	var p:=optic.affine_inverse()*eye.origin
	if p.z<.025 or p.z>.34:return 0
	if (-eye.basis.z).dot(-optic.basis.z.normalized())<.90:return 0
	return 1.0-smoothstep(.015,.040,Vector2(p.x,p.y).length())
func disable() -> void:
	active=false
	if viewport:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if surface:surface.set_shader_parameter("enabled",false)
func update_view(model: Node3D,eye_poses: Array,shot: Transform3D,allowed: bool) -> void:
	attach(model);disable()
	if not allowed or not is_instance_valid(lens) or not is_instance_valid(weapon):return
	var optic:=Transform3D(weapon.global_basis.orthonormalized(),lens.global_position)
	var quality:=0.0;var nearest:=Vector3.ZERO
	for eye in eye_poses:
		var score:=eye_quality(optic,eye)
		if score>quality:quality=score;nearest=eye.origin
	if quality<=0:return
	var front: Vector3=weapon.to_global(weapon.get_meta("scope_front"))
	var space:=get_world_3d().direct_space_state
	# Neither the lens nor its camera may grant sight through nearby world geometry.
	for segment in [[nearest,front],[nearest,shot.origin],[front,shot.origin]]:
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(segment[0],segment[1],1)).is_empty():return
	active=true;camera.global_transform=Transform3D(shot.basis.orthonormalized(),shot.origin)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	surface.set_shader_parameter("enabled",true)
	surface.set_shader_parameter("world_to_optic",optic.affine_inverse())
func update_rig() -> void:
	if not rig or not is_instance_valid(rig.gun) or not rig.gun.has_meta("scope_rear"):disable();return
	var poses: Array=[];var xr:=XRServer.find_interface("OpenXR")
	if not rig.simulated and xr and xr.is_initialized():
		for eye in mini(2,xr.get_view_count()):poses.append(xr.get_transform_for_view(eye,rig.origin.global_transform))
	else:
		for side in [-1,1]:poses.append(rig.head.global_transform*Transform3D(Basis.IDENTITY,Vector3(side*.032,0,0)))
	var game=rig.game;var id: int=game.multiplayer.get_unique_id()
	if not game.players.has(id):disable();return
	var solution: Dictionary=game._shot_solution(id)
	# Current local controller orientation, same direction as the authoritative shot.
	var shot:=Transform3D(rig.gun.global_basis.orthonormalized(),solution.origin)
	update_view(rig.gun,poses,shot,rig.gun.visible and rig.focused and not solution.blocked and not rig.blackout.visible)
