extends SceneTree
const Fixture=preload("res://deathmatch/tests/cq_battery_tank.gd")
var game
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func wait_for(test:Callable,seconds:float=20)->bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		if test.call():return true
		await create_timer(.02).timeout
	return false
func run()->void:
	var role:String=OS.get_cmdline_user_args()[0]
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(Fixture.TestArena);root.add_child(game)
	if role=="server":
		game.dedicated=true;game.start_host("Snapshot authority",28820,100,15,false);game._add_player(1,"Fixture")
		check(await wait_for(func():return game.players.size()==2),"Real client admitted to dedicated authority")
		if game.players.size()!=2:game.free();quit(1);return
		game.set_process(false);game.set_physics_process(false)
		var peer:int=game.players.keys().filter(func(id):return id!=1)[0]
		game.classes.states[peer].xp.scout=7500
		game.variant_combat.magazines.state(peer).clips[0]=3
		for i in 24:
			game.clock+=.05;game._send_snapshot();await create_timer(.03).timeout
			for packets in game.replication.poll_packets():game._send_snapshot_packets(packets)
		check(game.replication.stats.get("async_completed",0)>0,"Deferred snapshots complete on encoder thread")
		var demo_path:="user://snapshot-network-%d-%d.fpsdemo"%[OS.get_process_id(),Time.get_ticks_usec()]
		check(game.demos.start_record(demo_path),"Dedicated demo capture starts")
		game._send_snapshot();game.demos.stop_record()
		game.demos.input=FileAccess.open(demo_path,FileAccess.READ);game.demos.input.seek(8)
		# Inspect the captured bytes: legacy demo playback validation predates CQ.
		var size:int=game.demos.input.get_32()
		var frame:Dictionary=bytes_to_var(game.demos.input.get_buffer(size))
		check(not frame.is_empty() and frame.snapshot[10].has("cp:"+str(peer)) and not frame.snapshot[10].has("_native_class_source"),"Recording keeps complete public class state")
		game.demos.input.close();game.demos.input=null
		DirAccess.remove_absolute(demo_path)
		await create_timer(.5).timeout
	else:
		game.start_join("Snapshot client","127.0.0.1",28820)
		check(await wait_for(func():return game.active and game.players.has(game.multiplayer.get_unique_id())),"Client receives initial authoritative state")
		var id:int=game.multiplayer.get_unique_id()
		check(await wait_for(func():return game.classes.states.get(id,{}).get("xp",{}).get("scout",0)==7500),"Deferred CQ class state reaches gameplay receiver")
		check(game.variant_combat.magazines.states.get(id,{}).get("clips",{}).get(0,-1)==3,"Reload state reaches gameplay receiver")
		check(not game.replication.state[10].has("_native_class_source"),"Internal capture metadata never reaches wire state")
		await create_timer(2.0).timeout
	print("SNAPSHOT_NETWORK_RESULT ",role," ",JSON.stringify(failures))
	game.disconnect_game();game.free();await process_frame;quit(0 if failures.is_empty() else 1)
