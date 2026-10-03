extends Node3D
## A head-centred digital visor. One bounded mono world render shared by both
## eyes; the runtime still owns stereo projection, tracking and reprojection.
const Enhancer=preload("res://deathmatch/tribes/image_enhancer.gd")
const Overlay=preload("res://deathmatch/tribes/zoom_overlay.gd")
const Optic=preload("res://deathmatch/vr/sniper_scope.gd")
const BASE_FOV:=120.0
var viewport: SubViewport
var camera: Camera3D
var overlay: Control
var screen: MeshInstance3D
var material: ShaderMaterial
var rig
var masked_weapon_id:=0
var masked_avatar_id:=0
var saved_layers: Dictionary={}
var was_active:=false
func setup(value) -> void:rig=value;prepare()
func prepare() -> void:
	if viewport:return
	viewport=SubViewport.new();viewport.name="TribesImageEnhancer"
	viewport.size=Vector2i(768,768) if OS.has_feature("android") else Vector2i(1536,1536)
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	viewport.msaa_3d=Viewport.MSAA_DISABLED;viewport.audio_listener_enable_3d=false
	add_child(viewport);viewport.world_3d=get_world_3d()
	camera=Camera3D.new();camera.near=.025;camera.far=4000
	camera.cull_mask=((1<<20)-1)&~Optic.SCOPE_LAYER&~preload("res://deathmatch/vr/ik_guide.gd").LAYER
	camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	viewport.add_child(camera);camera.make_current()
	var canvas:=CanvasLayer.new();viewport.add_child(canvas)
	overlay=Overlay.new();overlay.label_anchor=Vector2(.5,.68);overlay.label_offset=Vector2(-20,0);overlay.label_size=32;canvas.add_child(overlay)
	screen=MeshInstance3D.new();screen.name="TribesVisor"
	var quad:=QuadMesh.new();quad.size=Vector2(2,2);screen.mesh=quad
	screen.layers=Optic.SCOPE_LAYER;screen.position.z=-.1;screen.extra_cull_margin=2
	screen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=ShaderMaterial.new();material.shader=preload("res://deathmatch/vr/tribes_visor.gdshader")
	material.render_priority=100;material.set_shader_parameter("image",viewport.get_texture())
	screen.material_override=material;rig.head.add_child(screen);screen.hide()
func disable() -> void:
	was_active=false
	if viewport:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if is_instance_valid(screen):screen.hide()
	for entry in saved_layers.values():
		var node=entry[0].get_ref()
		if is_instance_valid(node):node.layers=entry[1]
	saved_layers.clear()
func mask_local(node: Node) -> void:
	if node is VisualInstance3D:
		var id:=node.get_instance_id()
		if not saved_layers.has(id):saved_layers[id]=[weakref(node),node.layers]
		node.layers=Optic.SCOPE_LAYER
	for child in node.get_children():mask_local(child)
func update_rig() -> void:
	var game=rig.game;var enhancer=game.match_mode.tribes.enhancer
	var weapon_hand: XRController3D=rig.left if rig.left_handed else rig.right
	var weapon_aim: XRController3D=rig.left_aim if rig.left_handed else rig.right_aim
	var support_hand: XRController3D=rig.right if rig.left_handed else rig.left
	var tracked: bool=rig.simulated or weapon_hand.get_has_tracking_data() and weapon_aim.get_has_tracking_data() and support_hand.get_has_tracking_data()
	var allowed: bool=enhancer.allowed() and rig.context_controls_available() and rig.head_tracked() and tracked and not rig.shoulder_radio.held and not rig.physical_actions.busy() and not game.bindings.vr_pressed(rig,"support")
	var held: bool=game.bindings.vr_pressed(rig,"alt_fire")
	enhancer.update(held,allowed)
	if not enhancer.active:disable();return
	prepare()
	var actor=game.fighters.get(game.multiplayer.get_unique_id())
	var avatar: Node3D=actor.avatar if actor else null
	var weapon_id: int=rig.gun.get_instance_id() if is_instance_valid(rig.gun) else 0
	var avatar_id: int=avatar.get_instance_id() if is_instance_valid(avatar) else 0
	if not was_active or masked_weapon_id!=weapon_id or masked_avatar_id!=avatar_id:
		# Keep hands, HUDs, weapon models and the visor itself out of its camera.
		mask_local(rig);masked_weapon_id=weapon_id;masked_avatar_id=avatar_id
		if is_instance_valid(avatar):mask_local(avatar)
	was_active=true
	camera.global_transform=rig.head.global_transform.orthonormalized()
	camera.fov=Enhancer.zoom_fov(BASE_FOV,enhancer.magnification())
	material.set_shader_parameter("head_view",camera.global_transform.affine_inverse())
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;screen.show()
	var id: int=game.multiplayer.get_unique_id()
	var solution: Dictionary=game._shot_solution(id)
	var direction: Vector3=-game._weapon_transform(id).basis.z.normalized()
	var end: Vector3=solution.origin+direction*camera.far
	var query:=PhysicsRayQueryParameters3D.create(solution.origin,end,3,[game.fighters[id].get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():end=hit.position
	var valid: bool=not solution.blocked and not camera.is_position_behind(end)
	var point:=camera.unproject_position(end)/Vector2(viewport.size) if valid else Vector2(-1,-1)
	overlay.display(enhancer.magnification(),point,valid and Rect2(Vector2.ZERO,Vector2.ONE).has_point(point))
func _exit_tree() -> void:
	disable()
	if is_instance_valid(screen):screen.queue_free()
