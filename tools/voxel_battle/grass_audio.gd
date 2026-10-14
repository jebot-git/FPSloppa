extends Node3D
## Cosmetic client-side foot/leaf brush audio, independent of grass render LOD.
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const RADIUS:=12.0
const VOICES:=8
var game
var voices:Array=[]
var streams:Array=[]
var previous:Dictionary={}
var distance:Dictionary={}
var next_at:Dictionary={}
var cells:Dictionary={}
var tick:=0.0
var emissions:=0
func setup(arena) -> void:
	game=arena
	if game.headless:return
	for i in 3:streams.append(load("res://deathmatch/audio/jungle/rustle_%d.wav"%i))
	for i in VOICES:
		var player:=AudioStreamPlayer3D.new();player.max_distance=RADIUS;player.unit_size=2
		player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE;player.volume_db=-12;player.max_db=-6
		player.bus="ArenaEffects" if AudioServer.get_bus_index("ArenaEffects")>=0 else "Master"
		add_child(player);voices.append(player)
func contains(point:Vector3) -> bool:
	if not is_instance_valid(game.battle_map) or not is_instance_valid(game.battle_map.grass):return false
	var tiles:Dictionary=game.battle_map.grass.tiles
	var coordinate:=Landscape.bin_key(Vector2(point.x,point.z))
	for offset in [Vector2i.ZERO,Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1),Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
		var key:Vector2i=coordinate+offset
		if not tiles.has(key):continue
		if not cells.has(key):
			var bins:Dictionary={}
			for row:Vector4 in tiles[key].rows:
				var cell:=Vector2i(floori(row.x/2),floori(row.z/2))
				if not bins.has(cell):bins[cell]=PackedVector3Array()
				bins[cell].append(Vector3(row.x,row.y,row.z))
			cells[key]=bins
		var center:=Vector2i(floori(point.x/2),floori(point.z/2))
		for z in range(center.y-1,center.y+2):
			for x in range(center.x-1,center.x+2):
				for row:Vector3 in cells[key].get(Vector2i(x,z),PackedVector3Array()):
					if absf(point.y-row.y)<1.5 and Vector2(point.x-row.x,point.z-row.z).length_squared()<1.21:return true
	return false
func _process(delta:float) -> void:
	if game==null or game.headless or not game.active or not is_instance_valid(game.battle_map) or not is_instance_valid(game.battle_map.grass):return
	tick+=delta
	if tick<.1:return
	tick=0
	var listener:Vector3=game.xr_rig.head.global_position if game.is_vr() else game.camera.global_position
	for key in cells.keys():
		if not game.battle_map.grass.tiles.has(key):cells.erase(key)
	for id in previous.keys():
		if not game.fighters.has(id):previous.erase(id);distance.erase(id);next_at.erase(id)
	for id in game.fighters:
		var actor=game.fighters[id];var point:Vector3=actor.position
		var old:Vector3=previous.get(id,point);previous[id]=point
		var travel:float=Vector2(point.x-old.x,point.z-old.z).length()
		var grounded:bool=actor.is_supported() if game.multiplayer.is_server() or actor.local_player else actor.visual_grounded
		if point.distance_squared_to(listener)>RADIUS*RADIUS or game.players[id].dead or game.players[id].spectator or not grounded or travel<.005 or travel>3:distance[id]=0.0;continue
		if not contains(point):distance[id]=0.0;continue
		distance[id]=float(distance.get(id,0.0))+travel
		if distance[id]<(.18 if actor.stance=="prone" else .35) or game.clock<float(next_at.get(id,0.0)):continue
		distance[id]=0.0;next_at[id]=game.clock+.32
		emit_rustle(point,actor.stance=="prone")
func emit_rustle(point:Vector3,prone:bool=false) -> void:
	if voices.is_empty():return
	var voice:AudioStreamPlayer3D=voices[emissions%VOICES]
	voice.stop();voice.stream=streams[emissions%3];voice.global_position=point+Vector3.UP*.3
	voice.volume_db=-19 if prone else -12;voice.pitch_scale=.93+float(emissions%7)*.025
	voice.play();emissions+=1
