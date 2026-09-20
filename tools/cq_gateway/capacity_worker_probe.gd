extends "res://tools/district_sim/server_probe.gd"
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.cq_profile=true;check(game.match_mode.conquest.install().is_empty(),"CQ assets installed")
	game.match_mode.configure({"sv_gametype":"cq"});game.dedicated=true;game.selected_map=game.match_mode.conquest.MAP_ID
	game.start_host("Capacity fixture",0,100,30,true)
	for id in game.players.keys():State.remove(game,id)
	game._add_player(42,"Capacity actor");game.fighters[42].position=Rules.center(0)
	var fixture:=State.actor(game,42)
	var port:=29472;check(server.listen(port,"127.0.0.1")==OK,"Private capacity coordinator bound")
	var args:=OS.get_cmdline_user_args();var binary:=ProjectSettings.globalize_path("res://Builds/CQCapacity/FPSloppaServer.x86_64")
	if args.size()>0:binary=args[0]
	for zone in 2:
		tokens[zone]=Crypto.new().generate_random_bytes(32).hex_encode()
		pids[zone]=OS.create_process(binary,PackedStringArray(["--log-file",ProjectSettings.globalize_path("res://test-results/cq-gateway/capacity-worker-%d.log"%zone),"--","--experimental-cq","--cq-worker",str(zone),"--worker-port",str(port),"--worker-token",tokens[zone]]))
		check(pids[zone]>0,"Console worker launched")
	if not await wait_for(func():return workers.size()==2,60):finish();return
	for zone in 2:send(zone,{"kind":"start"});heartbeat(zone)
	for i in 16:
		var row:=fixture.duplicate(true);row.id=100+i;row.position=Rules.center(0)+Vector3((i%4)*3,0,(i/4)*3)
		send(0,{"kind":"admit","actor":row,"generation":1})
	await wait_for(func():return snapshots.get(0,{}).get("actors",[]).size()==16)
	check((await snap(0)).actors.size()==16,"Exactly sixteen residents admitted")
	var arriving:=fixture.duplicate(true);arriving.id=900
	send(0,{"kind":"prepare","tx":"full","actor":arriving,"generation":1});await receive("rejected",0)
	check((await snap(0)).actors.size()==16,"Seventeenth arrival rejected without killing worker")
	send(0,{"kind":"retire","id":100});await snap(0)
	send(0,{"kind":"prepare","tx":"last","actor":arriving,"generation":1});await receive("prepared",0)
	var other:=arriving.duplicate(true);other.id=901
	send(0,{"kind":"prepare","tx":"race","actor":other,"generation":1});await receive("rejected",0)
	send(0,{"kind":"commit","tx":"last"});await receive("committed",0);send(0,{"kind":"forget","tx":"last"})
	check((await snap(0)).actors.size()==16,"Prepared incoming actor reserves the last worker slot")
	var counts: Array=[];counts.resize(16);counts.fill(0);counts[0]=16;counts[1]=16
	send(0,{"kind":"capacity","counts":counts})
	send(0,{"kind":"retire","id":101});await snap(0)
	var walker:=fixture.duplicate(true);walker.id=101;walker.position=Vector3(-250.8,.1,-375)
	send(0,{"kind":"admit","actor":walker,"generation":1});await snap(0);input(0,walker,1,1);heartbeat(0,true)
	var end:=Time.get_ticks_msec()+500
	while Time.get_ticks_msec()<end:await process_frame;poll()
	heartbeat(0)
	var blocked:=actor(await snap(0),101)
	check(not blocked.is_empty() and blocked.position.x < -250.3,"Authoritative worker collision blocks the full destination")
	counts[1]=15;send(0,{"kind":"capacity","counts":counts});input(0,walker,1,2);heartbeat(0,true)
	var crossing:=await receive("offer",0);heartbeat(0)
	if crossing.is_empty():finish();return
	check(crossing.actor.id==101 and crossing.target==1,"Cleared slot reopens physical transit")
	send(0,{"kind":"prepare","tx":"escrow-race","actor":other,"generation":1});await receive("rejected",0)
	send(0,{"kind":"rollback","tx":crossing.tx});await receive("rolled_back",0)
	check((await snap(0)).actors.size()==16,"Escrow reserves source capacity for safe rollback")
	# Same-district respawn must work at 16/16 without taking a seventeenth slot.
	await dead_actor(fixture,102)
	send(0,{"kind":"respawn_grant","id":102,"generation":1,"target":0})
	var local:=await receive("respawn_done",0);heartbeat(0)
	check(not local.get("actor",{}).get("state",{}).get("dead",true) and (await snap(0)).actors.size()==16,"Full district resident respawns using its existing slot")
	await dead_actor(fixture,103)
	send(0,{"kind":"respawn_grant","id":103,"generation":1,"target":1})
	var transfer:=await receive("offer",0);heartbeat(0)
	if transfer.is_empty():finish();return
	check(transfer.respawn and transfer.target==1 and not transfer.actor.state.dead,"Remote respawn uses ordinary transfer with a live destination state")
	send(1,{"kind":"prepare","tx":transfer.tx,"actor":transfer.actor,"generation":2});await receive("prepared",1)
	send(1,{"kind":"commit","tx":transfer.tx});await receive("committed",1)
	send(0,{"kind":"release","tx":transfer.tx});send(1,{"kind":"forget","tx":transfer.tx})
	check((await snap(0)).actors.size()==15 and (await snap(1)).actors.size()==1,"Remote respawn leaves exactly one authority and frees source slot")
	finish()
func dead_actor(fixture: Dictionary,id: int) -> void:
	send(0,{"kind":"retire","id":id});await snap(0)
	var row:=fixture.duplicate(true);row.id=id;row.state.dead=true;row.state.hp=0;row.state.respawn_at=-10;row.state.want_respawn=true
	send(0,{"kind":"admit","actor":row,"generation":1});await snap(0);input(0,row,1,1);heartbeat(0,true)
	var request:=await receive("respawn_request",0)
	check(request.get("id",0)==id,"Dead actor requests master-authorized respawn")
func finish() -> void:
	if finished:return
	finished=true
	for wire in connections:wire.peer.disconnect_from_host()
	server.stop()
	for pid in pids.values():
		if OS.is_process_running(pid):OS.kill(pid)
	if is_instance_valid(game):game.disconnect_game();game.queue_free()
	var report:={"checks":checks,"failures":failures,"workers":2}
	FileAccess.open("res://test-results/cq-gateway/capacity-worker-result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CQ_CAPACITY_WORKERS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
