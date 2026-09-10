extends Node3D
## Shared wall-mounted voting surface. VR uses XRTools pointers; desktop uses aim/click.
const UI_LAYER=1<<22
var game
var surface
var panel
var pressed:=false
var last_at:=Vector2.ZERO
func setup(arena: Node) -> void:
	game=arena
	surface=load("res://addons/godot-xr-tools/objects/viewport_2d_in_3d.tscn").instantiate()
	surface.screen_size=Vector2(7.2,5.4);surface.viewport_size=Vector2(960,720)
	surface.collision_layer=UI_LAYER;surface.unshaded=true;surface.input_keyboard=false
	add_child(surface)
	panel=preload("res://deathmatch/modes/lobby_panel.gd").new();panel.wall=true
	surface.get_node("Viewport").add_child(panel);panel.setup(game)
func _process(_delta: float) -> void:
	if not game or game.is_vr() or game.menu_open:return
	var at:=aim_position()
	if at.x<0:return
	var event:=InputEventMouseMotion.new();event.position=at;event.relative=at-last_at;last_at=at
	surface.get_node("Viewport").push_input(event,true)
func aim_position() -> Vector2:
	var camera: Camera3D=game.camera
	var query:=PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*30,1|UI_LAYER)
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider!=surface.get_node("StaticBody3D"):return Vector2(-1,-1)
	return surface.get_node("StaticBody3D").global_to_viewport(hit.position)
func _input(event: InputEvent) -> void:
	if game.is_vr() or game.menu_open or not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT:return
	var at:=aim_position()
	if at.x<0 and not pressed:return
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=event.pressed;click.position=last_at if at.x<0 else at
	pressed=event.pressed;surface.get_node("Viewport").push_input(click,true);get_viewport().set_input_as_handled()
