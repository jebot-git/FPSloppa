extends Node3D
## Adapted from main's ST turret_view FeedHUD/SubViewport and BA2 private camera isolation.
const PRIVATE_LAYER:=1<<19
class FeedHUD extends Control:
	var view
	func _draw() -> void:
		var row:Dictionary=view.service.rows.get(view.key,{})
		if row.is_empty():return
		draw_rect(Rect2(0,0,640,36),Color(.025,.06,.075,.87));draw_rect(Rect2(0,330,640,30),Color(.025,.06,.075,.87))
		draw_line(Vector2(0,36),Vector2(640,36),Color("69b9b1"),2)
		var config:Dictionary=view.service.profile(row)
		var text:String="%s · %d/%d HP · "%[config.name,row.hp,config.hp]+("SALVO %d/8"%(8-row.left) if row.left>0 else "RELOAD %.1fs"%maxf(0,row.reload_at-view.game.clock) if row.reload_at>view.game.clock else "READY · %d %s"%[config.capacity if row.kind=="rocket" or row.rounds==0 else row.rounds,"VOLLEYS" if row.kind=="heavy" else "ROUNDS"])
		draw_string(preload("res://deathmatch/ui/cq/theme.gd").FONT,Vector2(14,24),text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("dcebe8"))
		draw_string(preload("res://deathmatch/ui/cq/theme.gd").FONT,Vector2(14,350),"WEAPON HAND AIM · MOTION STICK DRIVE" if view.game.is_vr() else "MOUSE AIM · WASD TANK DRIVE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c7d8d8"))
		draw_string(preload("res://deathmatch/ui/cq/theme.gd").FONT,Vector2(475,350),"USE · DISMOUNT",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c7d8d8"))
		for axis in [Vector2.RIGHT,Vector2.DOWN]:
			for sign in [-1,1]:
				var a:Vector2=Vector2(320,180)+axis*sign*5;var b:Vector2=Vector2(320,180)+axis*sign*13
				draw_line(a,b,Color(.01,.02,.025,.85),4);draw_line(a,b,Color("dcebe8"),1.5)
var game
var service
var key:=-1
var viewport:SubViewport
var sensor:Camera3D
var overlay:CanvasLayer
var screen:MeshInstance3D
var hud:FeedHUD
var black:Environment
var saved:Dictionary={}
var reticle:MeshInstance3D
var hidden_hull:Node3D
func setup(arena,tanks) -> void:game=arena;service=tanks
func create_view() -> void:
	viewport=SubViewport.new();viewport.name="STBatteryScopeFeed";viewport.size=Vector2i(640,360);viewport.world_3d=game.get_world_3d();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.audio_listener_enable_3d=false;add_child(viewport)
	sensor=Camera3D.new();sensor.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;sensor.fov=75;sensor.near=.08;sensor.far=1600;sensor.cull_mask&=~PRIVATE_LAYER;viewport.add_child(sensor);sensor.make_current()
	var layer:=CanvasLayer.new();viewport.add_child(layer);hud=FeedHUD.new();hud.view=self;hud.size=Vector2(640,360);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(hud)
	overlay=CanvasLayer.new();overlay.layer=9;add_child(overlay)
	var frame:=Control.new();frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(frame)
	var image:=TextureRect.new();image.texture=viewport.get_texture();image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.add_child(image)
	screen=MeshInstance3D.new();screen.name="SeatedStereoScopeScreen";screen.layers=PRIVATE_LAYER;screen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;var quad:=QuadMesh.new();quad.size=Vector2(1.6,.9);screen.mesh=quad
	var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_texture=viewport.get_texture();screen.material_override=m;add_child(screen)
	black=Environment.new();black.background_mode=Environment.BG_COLOR;black.background_color=Color.BLACK
func deactivate() -> void:
	if reticle:reticle.hide()
	if is_instance_valid(hidden_hull):hidden_hull.show()
	hidden_hull=null
	for state in saved.values():
		var camera=state.ref.get_ref()
		if is_instance_valid(camera):camera.cull_mask=state.mask;camera.environment=state.environment
	saved.clear()
	if overlay:overlay.hide()
	if screen:screen.hide()
	if viewport:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	key=-1
func update() -> void:
	deactivate()
	var id:int=game.multiplayer.get_unique_id();key=service.key_for(id)
	if key<0 or not game.active or game.menu_open:return
	var row:Dictionary=service.view_row(key)
	if is_instance_valid(game.viewmodel):game.viewmodel.hide()
	if is_instance_valid(game.offhand_viewmodel):game.offhand_viewmodel.hide()
	if row.kind=="transport":
		if game.is_vr() and is_instance_valid(game.xr_rig.gun):game.xr_rig.gun.hide()
		if not game.is_vr() and game.camera:
			game.camera.global_position=service.render_passenger_position(id,key)+Vector3.UP*game.camera_eye_height
		key=-1;return # Normal stereo/world camera shares the rendered cabin pose.
	if game.is_vr():
		if not reticle:
			reticle=MeshInstance3D.new();reticle.name="StereoBoreReticle";reticle.mesh=ImmediateMesh.new();reticle.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(reticle)
			var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("dcebe8");reticle.material_override=material
		var start:Vector3=service.muzzle(row);var end:Vector3=start+row.direction*5000.
		var query:=PhysicsRayQueryParameters3D.create(start,end,1,[service.bodies[key].get_rid()])
		var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
		var target:Vector3=hit.position if not hit.is_empty() else end
		var distance:float=clampf(game.xr_rig.head.global_position.distance_to(target),2.,100.)
		var offset:Vector3=(target-game.xr_rig.head.global_position).normalized()
		reticle.global_position=game.xr_rig.head.global_position+offset*distance;reticle.global_basis=game.xr_rig.head.global_basis
		var mesh:ImmediateMesh=reticle.mesh;mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for axis in [Vector3.RIGHT,Vector3.UP]:
			for sign in [-1.,1.]:mesh.surface_add_vertex(axis*sign*distance*.002);mesh.surface_add_vertex(axis*sign*distance*.006)
		mesh.surface_end();reticle.show()
		hidden_hull=service.models.get(key)
		if is_instance_valid(hidden_hull):hidden_hull.hide()
		if is_instance_valid(game.xr_rig.gun):game.xr_rig.gun.hide()
		return
	if not viewport:create_view()
	if game.is_vr():
		var rig=game.xr_rig
		if is_instance_valid(rig.gun):rig.gun.hide()
		for hand in rig.hand_models:
			if is_instance_valid(hand):hand.hide()
	for camera in game.find_children("*","Camera3D",true,false):
		if camera==sensor:continue
		saved[camera.get_instance_id()]={"ref":weakref(camera),"mask":camera.cull_mask,"environment":camera.environment};camera.cull_mask&=~PRIVATE_LAYER
	if game.camera:
		game.camera.cull_mask=PRIVATE_LAYER;game.camera.environment=black
		if game.is_vr():screen.global_transform=game.camera.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,-.8))
	overlay.visible=not game.is_vr();screen.visible=game.is_vr()
	sensor.global_position=service.muzzle(row)+row.direction*.1;sensor.look_at(sensor.global_position+row.direction,row.get("normal",Vector3.UP) if absf(row.direction.dot(row.get("normal",Vector3.UP)))<.99 else Vector3.RIGHT);sensor.make_current()
	# The arena streams terrain/structures once per frame using world_view_camera().
	hud.queue_redraw();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
func _exit_tree() -> void:deactivate()
