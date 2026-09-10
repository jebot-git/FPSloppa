extends SceneTree
## Repeated real scene/session teardown. Memory plateaus are evaluated after warmup.
var game
var samples: Array=[]
var failures: Array=[]
var kind:="sessions"
var cycles:=20
var folder:="res://test-results/performance-audit"
func _initialize():call_deferred("run")
func settle(frames: int=12):
	for i in frames:await process_frame
func measure(phase: String,index: int):
	var row:={"phase":phase,"cycle":index,"usec":Time.get_ticks_usec(),"static_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"video_bytes":int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))}
	if is_instance_valid(game):row["players"]=game.players.size();row["projectiles"]=game.projectiles.size();row["audio_sources"]=game.spatial.active.size()
	samples.append(row);print("LIFECYCLE_SAMPLE ",JSON.stringify(row))
	var file:=FileAccess.open(folder+"/soak-"+kind+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"kind":kind,"cycles":cycles,"samples":samples,"failures":failures},"  "));file.close()
func create_game():
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
func begin_session():
	game.start_host("Lifecycle audit",0,100,60,true)
	if is_instance_valid(game.bots):game.bots.free();game.bots=null
	game.set_physics_process(false)
	for id in range(-4,-9,-1):
		if not game.players.has(id):game._add_player(id,"Audit bot")
func run():
	var args:=OS.get_cmdline_user_args();var i:=args.find("--audit-kind")
	if i>=0:kind=args[i+1]
	i=args.find("--audit-cycles")
	if i>=0:cycles=int(args[i+1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(960,600)
	await settle();measure("baseline",-1)
	if kind!="arenas":create_game();await settle()
	for cycle in cycles:
		if kind=="arenas":create_game()
		begin_session()
		await settle(40)
		if kind=="demos":
			var path:=ProjectSettings.globalize_path(folder+"/soak-demo-%d.fpsdemo"%cycle)
			if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
			if not game.demos.start_record(path):failures.append("recording failed")
			for frame in 120:game.clock+=.05;game._send_snapshot()
			game.demos.stop_record()
			if not game.demos.open_demo(path):failures.append("playback failed")
			else:
				game.demos.paused=true
				for step in 12:game.demos.seek(step*.4);await settle(2)
				game.demos.stop_playback()
			DirAccess.remove_absolute(path)
		elif kind=="maps":
			for map in ["lqdm2","lqdm3","lqdm1"]:
				if not game._load_map(map):failures.append("map load failed: "+map)
				await settle(12)
		elif kind=="combat":
			for shot in 80:
				game.clock+=.025
				if not game.headless:game.effects.play("weapon_7",game.fighters[1].position,-40)
				game._projectile_spawn(game.projectile_id+1,1,7,game.fighters[1].position+Vector3.UP,Vector3.UP,0,0)
				game.projectile_id+=1
				game._projectile_end(game.projectile_id,game.fighters[1].position,7)
				await process_frame
			await create_timer(.5).timeout
		measure("loaded",cycle)
		game.disconnect_game("Lifecycle cycle %d"%cycle)
		if kind=="arenas":game.free();game=null
		await settle(30);measure("unloaded",cycle)
	if is_instance_valid(game):game.free();game=null
	await settle(60);measure("final",cycles)
	print("LIFECYCLE_RESULT ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
