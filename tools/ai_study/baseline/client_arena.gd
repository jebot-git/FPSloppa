extends "res://deathmatch/arena.gd"
var test_index:=0
var observer:=false
var client_ai
var ai_epoch:=-1
var last_class_epoch:=-1
var next_ai_time:=0.0
var cached_command: Dictionary={}
var director=preload("res://tools/remote_match/director.gd")
var last_camera_shot:=-1
func _prepare_client_map(epoch: int) -> void:
	if is_instance_valid(client_ai):client_ai.free()
	client_ai=null;cached_command.clear()
	super._prepare_client_map(epoch)
func _local_command() -> Dictionary:
	var command:=super._local_command()
	if observer:return command
	var id:=multiplayer.get_unique_id()
	if not active or not players.has(id) or not fighters.has(id):return command
	menu_open=false
	if ai_epoch!=map_epoch or not is_instance_valid(client_ai):
		if is_instance_valid(client_ai):client_ai.free()
		client_ai=preload("res://tools/ai_study/baseline/client_ai.gd").new();add_child(client_ai);client_ai.setup(self);ai_epoch=map_epoch
	if match_mode.kind=="tf" and last_class_epoch!=map_epoch:
		var classes: Array=match_mode.fortress.CLASSES.keys()
		match_mode.fortress.choose(classes[test_index%classes.size()]);last_class_epoch=map_epoch
		request_suicide()
	if clock>=next_ai_time:
		client_ai.input_for(id,1.0/30);next_ai_time=clock+1.0/30
		var s: Dictionary=players[id]
		for key in ["move","yaw","pitch","fire","alt_fire","weapon","slow","crouch","prone","jump"]:cached_command[key]=s[key]
	command.merge(cached_command,true)
	command.seq=sequence;command.respawn=true;command.input_blocked=false
	command.fly=1.0 if fighters[id].in_water and command.jump else 0.0
	local_yaw=command.yaw;local_pitch=command.pitch;desired_weapon=command.weapon
	return command
func _process(delta: float) -> void:
	super._process(delta)
	if not observer or not active:return
	if is_instance_valid(viewmodel):viewmodel.visible=false
	if is_instance_valid(offhand_viewmodel):offhand_viewmodel.visible=false
	var row: Dictionary=director.frame(self,clock)
	if int(clock/12)!=last_camera_shot and not row.is_empty():
		last_camera_shot=int(clock/12);print("CAMERA ",JSON.stringify(row))
