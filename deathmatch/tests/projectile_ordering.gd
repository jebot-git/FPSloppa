extends SceneTree
var game
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func spawn(id: int):game._projectile_spawn(id,2,7,Vector3(0,10,0),Vector3.FORWARD,0.0,0.0)
func snapshot(ids: Array,watermark: int):
	var rows: Array=[]
	for id in ids:rows.append([id,Vector3(0,10,-1),2,7,Vector3.FORWARD,0.0,0.0])
	game._snapshot([],PackedByteArray(),30.0,0.0,"",20,600.0,rows,[],game.map_epoch,{}, {},10.0,watermark)
func run():
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false)
	var peer:=ENetMultiplayerPeer.new();check(peer.create_client("127.0.0.1",29997)==OK,"Create isolated client transport")
	game.multiplayer.multiplayer_peer=peer;game.active=true;game.map_loading=false
	spawn(1);game.projectiles[1].position.z=-2;spawn(1)
	check(game.projectiles[1].position.z==-2,"Duplicate spawn cannot reset a moving projectile")
	game._projectile_end(1,Vector3.ZERO,7);spawn(1)
	check(not game.projectiles.has(1),"Delayed spawn cannot resurrect an ended projectile")
	spawn(3);snapshot([],2)
	check(game.projectiles.has(3),"Older snapshot cannot remove a newer reliable spawn")
	snapshot([3],3);snapshot([],3);spawn(3)
	check(not game.projectiles.has(3),"Snapshot retirement prevents delayed reliable resurrection")
	game._projectile_end(4,Vector3.ZERO,7);snapshot([4],4)
	check(not game.projectiles.has(4),"Late snapshot cannot resurrect an ended projectile")
	spawn(5);game.headless=true;game._update_projectile_visuals(.2)
	check(game.projectiles[5].visual_age==.2 and game.projectiles[5].position.z>=-3.941,"Client extrapolation stops after 100 ms without snapshots")
	game._update_projectile_visuals(.2)
	check(game.projectiles[5].position.z>=-3.941,"Packet gap does not make visual projectiles fly indefinitely")
	game.disconnect_game();game.free();await process_frame
	print("PROJECTILE_ORDERING_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
