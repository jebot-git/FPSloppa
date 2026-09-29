extends Node
## Local preview / sensor display. Remote video is a panel, never an XR head move.
var rules
var ghost: Node3D
var ghost_kind:=""
var markers: Dictionary={}
var camera_key:=-1
var viewport: SubViewport
var camera: Camera3D
var panel: CanvasLayer
var vr_panel: MeshInstance3D
var next_frame:=0.0
func setup(value):rules=value
func _exit_tree():
	if is_instance_valid(vr_panel):vr_panel.queue_free()
	if is_instance_valid(ghost):ghost.queue_free()
	for marker in markers.values():
		if is_instance_valid(marker):marker.queue_free()
func watch(key: int):
	camera_key=key
	if key<0:return
	if not is_instance_valid(viewport):
		viewport=SubViewport.new();viewport.size=Vector2i(512,288);viewport.world_3d=rules.game.get_world_3d();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
		camera=Camera3D.new();camera.fov=90;camera.far=400;viewport.add_child(camera);camera.current=true
		panel=CanvasLayer.new();panel.layer=8;add_child(panel)
		var image:=TextureRect.new();image.texture=viewport.get_texture();image.position=Vector2(24,96);image.size=Vector2(512,288);panel.add_child(image)
		var label:=Label.new();label.text="REMOTE CAMERA · use button / Esc to close";label.position=Vector2(24,72);panel.add_child(label)
		vr_panel=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.38,.214);vr_panel.mesh=quad
		var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_texture=viewport.get_texture();mat.cull_mode=BaseMaterial3D.CULL_DISABLED;vr_panel.material_override=mat;rules.game.add_child(vr_panel)
func _input(event):
	if camera_key>=0 and (rules.game.bindings.matches("use",event) or event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE):
		camera_key=-1;get_viewport().set_input_as_handled()
func update():
	rules.deployables.update_visuals()
	var game=rules.game;var deploy=rules.deployables;var id: int=game.multiplayer.get_unique_id();var state: Dictionary=game.local_state()
	# A wheel can still have blocked the last input packet when the view opens.
	var allowed: bool=deploy.accessible(id) and not game.menu_open and not game.demos.playing
	var kind: String=state.get("tribes_pack","");var show: bool=allowed and deploy.enabled(id) and deploy.Data.is_pack(kind)
	if game.is_vr():show=show and game.xr_rig.physical_actions.equipment.item=="pack"
	if show and ghost_kind!=kind:
		if is_instance_valid(ghost):ghost.queue_free()
		ghost=deploy.Model.make(kind,state.team);game.add_child(ghost);ghost_kind=kind
		var mat:=StandardMaterial3D.new();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color(.2,1,.65,.35)
		for part in ghost.find_children("*","MeshInstance3D",true,false):part.material_override=mat
	if is_instance_valid(ghost):
		ghost.visible=false
		if show:
			var hand: Transform3D=game._weapon_transform(id)
			if game.is_vr():
				var pose: Dictionary=game.xr_rig.sample_pose()
				if pose.is_empty():show=false
				else:hand=game.xr_rig.global_transform*preload("res://deathmatch/tribes/equipment.gd").hand_frame(pose)
			var placement: Dictionary=deploy.placement(id,hand.origin,-hand.basis.z) if show else {}
			if not placement.is_empty():
				ghost.global_transform=deploy.Data.frame(placement);ghost.visible=true
				if kind=="camera":
					var head=ghost.get_node("Head");head.look_at(head.global_position+placement.aim,Vector3.UP if absf(placement.aim.y)<.99 else Vector3.RIGHT)
	for peer in markers:
		if is_instance_valid(markers[peer]):markers[peer].hide()
	if allowed and state.team in [0,1]:
		for peer in deploy.contacts[state.team]:
			if not game.fighters.has(peer) or not game.players.has(peer) or game.players[peer].dead:continue
			if not markers.has(peer):
				var label:=Label3D.new();label.text="◇";label.font_size=40;label.pixel_size=.008;label.modulate=Color("f09472");label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
				# World-occluded marker: sensors do not turn the main view into X-ray.
				label.no_depth_test=false;game.add_child(label);markers[peer]=label
			markers[peer].global_position=game.fighters[peer].position+Vector3.UP*2.1;markers[peer].show()
	if camera_key>=0 and (not allowed or not deploy.rows.has(camera_key) or deploy.rows[camera_key].kind!="camera" or deploy.rows[camera_key].team!=state.team):camera_key=-1
	if not is_instance_valid(viewport):return
	panel.visible=camera_key>=0 and not game.is_vr();vr_panel.visible=camera_key>=0 and game.is_vr()
	if camera_key<0:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;return
	var row: Dictionary=deploy.rows[camera_key];camera.global_position=deploy.Data.eye(row)
	camera.look_at(camera.global_position+row.aim,Vector3.UP if absf(row.aim.y)<.99 else Vector3.RIGHT)
	if game.clock>=next_frame:next_frame=game.clock+.1;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	if game.is_vr():
		var rig=game.xr_rig;var hand=rig.right if rig.left_handed else rig.left
		vr_panel.global_position=hand.global_position+Vector3.UP*.22
		vr_panel.look_at(rig.head.global_position,Vector3.UP,true)
