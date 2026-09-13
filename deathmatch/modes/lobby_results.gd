extends Node3D
var game
var board
var previous: Dictionary={}
func setup(arena: Node) -> void:
	game=arena
	var surface=load("res://addons/godot-xr-tools/objects/viewport_2d_in_3d.tscn").instantiate()
	surface.screen_size=Vector2(7.0,4.8);surface.viewport_size=Vector2(880,604)
	surface.collision_layer=0;surface.unshaded=true;surface.input_keyboard=false;add_child(surface)
	var canvas:=Control.new();surface.get_node("Viewport").add_child(canvas);canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board=preload("res://deathmatch/ui/scoreboard.gd").new();canvas.add_child(board);board.setup()
func _process(_delta: float) -> void:
	var data: Dictionary=game.lobby.last_results if multiplayer.is_server() else game.lobby.view.get("results",{})
	if data.is_empty():board.hide();return
	if data!=previous:previous=data.duplicate(true);board.refresh_data(data,true)
	board.show()
