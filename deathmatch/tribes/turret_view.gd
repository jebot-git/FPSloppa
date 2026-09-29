extends Node
## Remote aiming stays on a panel in VR; the headset camera is never moved.
var rules
var viewport: SubViewport
var camera: Camera3D
var panel: CanvasLayer
var title: Label
var vr_panel: MeshInstance3D
var key:=-1
var yaw:=0.0
var pitch:=0.0
var next_send:=0.0
var releasing:=false
var remote_mode:=false
func setup(value):rules=value
func _exit_tree():
	if is_instance_valid(vr_panel):vr_panel.queue_free()
func create_view():
	viewport=SubViewport.new();viewport.size=Vector2i(640,360);viewport.world_3d=rules.game.get_world_3d();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
	camera=Camera3D.new();camera.fov=75;camera.far=700;viewport.add_child(camera);camera.current=true
	panel=CanvasLayer.new();panel.layer=9;add_child(panel)
	var image:=TextureRect.new();image.texture=viewport.get_texture();image.position=Vector2(24,96);image.size=Vector2(640,360);panel.add_child(image)
	title=Label.new();title.position=Vector2(24,72);panel.add_child(title)
	var reticle:=Label.new();reticle.text="+";reticle.position=Vector2(337,260);panel.add_child(reticle)
	vr_panel=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.48,.27);vr_panel.mesh=quad
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_texture=viewport.get_texture();mat.cull_mode=BaseMaterial3D.CULL_DISABLED;vr_panel.material_override=mat;rules.game.add_child(vr_panel)
func _input(event):
	if key<0:return
	if rules.game.bindings.matches("use",event) or event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		release();key=-1;get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not rules.game.is_vr():
		yaw-=event.relative.x*.0025;pitch=clampf(pitch-event.relative.y*.0025,-1.4,1.4);get_viewport().set_input_as_handled()
func update():
	var game=rules.game;var pads=rules.stations();var id: int=game.multiplayer.get_unique_id()
	var next_remote: int=rules.remote.operated(id) if rules.enabled() and game.active and not game.demos.playing else -1
	var next: int=next_remote if next_remote>=0 else pads.defences.operated(id) if pads and rules.enabled() and game.active and not game.demos.playing else -1
	if releasing:
		if next<0:releasing=false
		else:next=-1 # Wait for the authoritative release, not an older snapshot.
	if next!=key or (next_remote>=0)!=remote_mode:
		key=next;remote_mode=next_remote>=0
		if key>=0:
			var aim: Vector3=row().aim;yaw=atan2(-aim.x,-aim.z);pitch=asin(aim.y);next_send=game.clock
	if key>=0 and (game.menu_open or rules.pda_open() or not (rules.remote.active(key) if remote_mode else pads.defences.active(key))):
		release();key=-1
	if key>=0 and not is_instance_valid(viewport):create_view()
	if not is_instance_valid(viewport):return
	panel.visible=key>=0 and not game.is_vr();vr_panel.visible=key>=0 and game.is_vr()
	if key<0:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;return
	var state: Dictionary=game.local_state();var direction: Vector3=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)*Vector3.FORWARD
	var fire: bool=game.bindings.pressed("fire")
	if game.is_vr():
		var rig=game.xr_rig;var hand=rig.right if rig.left_handed else rig.left;var dominant=rig.left_aim if rig.left_handed else rig.right_aim
		direction=(-dominant.global_basis.z).normalized()
		fire=game.bindings.vr_pressed(rig,"fire") and rig.focused and not rig.wheel_open() and not rig.scores and not rig.blackout.visible and (rig.simulated or rig.head_tracked() and dominant.get_has_tracking_data())
		vr_panel.global_position=hand.global_position+Vector3.UP*.24;vr_panel.look_at(rig.head.global_position,Vector3.UP,true)
	if game.clock>=next_send:
		next_send=game.clock+.05
		if remote_mode:
			if game.multiplayer.is_server():rules.remote_command(key,game.map_epoch,state.serial,direction,fire)
			else:rules.remote_command.rpc_id(1,key,game.map_epoch,state.serial,direction,fire)
		else:
			if game.multiplayer.is_server():rules.turret_command(key,game.map_epoch,state.serial,direction,fire)
			else:rules.turret_command.rpc_id(1,key,game.map_epoch,state.serial,direction,fire)
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	var target: Dictionary=row()
	title.text=("CAMERA · aim" if remote_mode and target.kind=="camera" else "TURRET · aim / fire")+" · Use or Esc to leave"
	camera.global_position=rules.deployables.Data.eye(target) if remote_mode else pads.defences.muzzle(key)+target.aim*.2
	camera.look_at(camera.global_position+target.aim,Vector3.UP if absf(target.aim.y)<.99 else Vector3.RIGHT)

func row() -> Dictionary:return rules.deployables.rows[key] if remote_mode else rules.stations().defences.rows[key]
func release():
	if remote_mode:rules.control_remote(-1)
	else:rules.control_turret(-1)
