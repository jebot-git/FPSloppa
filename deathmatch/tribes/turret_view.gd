extends Node
## Remote aiming stays on the offhand wrist in VR; the headset camera never moves.
const Wrist=preload("res://deathmatch/tribes/wrist_display.gd")
class FeedHUD extends Control:
	var view
	func _draw():
		if view.key<0:return
		draw_rect(Rect2(0,0,640,36),Color(.025,.06,.075,.87))
		draw_rect(Rect2(0,330,640,30),Color(.025,.06,.075,.87))
		draw_line(Vector2(0,36),Vector2(640,36),Color("69b9b1"),2)
		draw_string(ThemeDB.fallback_font,Vector2(14,24),view.title.text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("dcebe8"))
		draw_circle(Vector2(562,18),4,Color("69d9a5"))
		draw_string(ThemeDB.fallback_font,Vector2(574,23),"LIVE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("69d9a5"))
		draw_string(ThemeDB.fallback_font,Vector2(14,350),"CONTROLLER AIM" if view.rules.game.is_vr() else "MOUSE AIM",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c7d8d8"))
		draw_string(ThemeDB.fallback_font,Vector2(444,350),"USE · DISCONNECT",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c7d8d8"))
		for axis in [Vector2.RIGHT,Vector2.DOWN]:
			for sign in [-1,1]:
				var a: Vector2=Vector2(320,180)+axis*sign*5;var b: Vector2=Vector2(320,180)+axis*sign*13
				draw_line(a,b,Color(.01,.02,.025,.85),4);draw_line(a,b,Color("dcebe8"),1.5)
var rules
var viewport: SubViewport
var camera: Camera3D
var panel: CanvasLayer
var title: Label
var vr_panel: MeshInstance3D
var wrist
var hud: FeedHUD
var key:=-1
var yaw:=0.0
var pitch:=0.0
var next_send:=0.0
var releasing:=false
var remote_mode:=false
func setup(value):rules=value
func _exit_tree():
	if is_instance_valid(wrist):wrist.queue_free()
func create_view():
	viewport=SubViewport.new();viewport.size=Vector2i(640,360);viewport.world_3d=rules.game.get_world_3d();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
	camera=Camera3D.new();camera.fov=75;camera.far=700;camera.cull_mask&=~Wrist.LOCAL_LAYER;viewport.add_child(camera);camera.current=true
	var overlay:=CanvasLayer.new();viewport.add_child(overlay)
	hud=FeedHUD.new();hud.view=self;hud.size=Vector2(640,360);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(hud)
	panel=CanvasLayer.new();panel.layer=9;add_child(panel)
	var image:=TextureRect.new();image.texture=viewport.get_texture();image.position=Vector2(24,96);image.size=Vector2(640,360);panel.add_child(image)
	title=Label.new();title.position=Vector2(24,72);panel.add_child(title)
	wrist=Wrist.new();rules.game.add_child(wrist);wrist.setup(viewport.get_texture(),"camera");vr_panel=wrist.screen
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
	panel.visible=key>=0 and not game.is_vr();vr_panel.visible=key>=0 and game.is_vr();wrist.visible=vr_panel.visible
	if key<0:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;return
	var state: Dictionary=game.local_state();var direction: Vector3=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)*Vector3.FORWARD
	var fire: bool=game.bindings.pressed("fire")
	if game.is_vr():
		var rig=game.xr_rig;var dominant=rig.left_aim if rig.left_handed else rig.right_aim
		vr_panel.visible=wrist.mount(rig)
		direction=(-dominant.global_basis.z).normalized()
		fire=game.bindings.vr_pressed(rig,"fire") and wrist.visible and not rig.wheel_open() and (rig.simulated or dominant.get_has_tracking_data())
	if game.clock>=next_send:
		next_send=game.clock+.05
		if remote_mode:
			if game.multiplayer.is_server():rules.remote_command(key,game.map_epoch,state.serial,direction,fire)
			else:rules.remote_command.rpc_id(1,key,game.map_epoch,state.serial,direction,fire)
		else:
			if game.multiplayer.is_server():rules.turret_command(key,game.map_epoch,state.serial,direction,fire)
			else:rules.turret_command.rpc_id(1,key,game.map_epoch,state.serial,direction,fire)
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE if panel.visible or wrist.visible else SubViewport.UPDATE_DISABLED
	var target: Dictionary=row()
	title.text=("REMOTE CAMERA" if remote_mode and target.kind=="camera" else "REMOTE TURRET")+"  /  %02d"%key
	hud.queue_redraw()
	camera.global_position=rules.deployables.Data.eye(target) if remote_mode else pads.defences.muzzle(key)+target.aim*.2
	camera.look_at(camera.global_position+target.aim,Vector3.UP if absf(target.aim.y)<.99 else Vector3.RIGHT)

func row() -> Dictionary:return rules.deployables.rows[key] if remote_mode else rules.stations().defences.rows[key]
func release():
	if remote_mode:rules.control_remote(-1)
	else:rules.control_turret(-1)
