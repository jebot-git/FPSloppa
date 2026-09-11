extends SceneTree
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1200,720)
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	if game.hud:game.hud.hide()
	game.match_mode.kind="as";game.active=true;game.lobby.build();game.match_mode.reset()
	check(game.match_mode.spawns(0).size()==32 and game.match_mode.spawns(1).size()==32,"Both AS teams use the 32 indoor lobby spawns")
	for id in range(1,9):game._add_player(id,"Lobby player "+str(id))
	var positions: Array=[]
	for actor in game.fighters.values():positions.append(actor.position)
	check(positions.all(func(pos):return pos.y<.1 and absf(pos.x)<11 and absf(pos.z)<5),"All eight players initially spawn inside lobby")
	var unique: Dictionary={}
	for pos in positions:unique[pos]=true
	check(unique.size()==8,"AS transition assigns separate lobby positions instead of stacking capsules")
	game.lobby.until=game.clock+45
	await physics_frame;await physics_frame
	game.fighters[1].position=Vector3(0,9.5,0);game.lobby.tick(.016)
	check(game.fighters[1].position.y<.1,"Existing roof spawn recovers inside without suicide")
	game.votes.allowed_modes=["dm","ctf"];game.mode_maplists={"dm":["lqdm1"],"ctf":["lqdm2"]};game.lobby.offered=game.lobby.choices();game.lobby.fallback={"mode":"dm","map":"lqdm1"}
	var panel=load("res://deathmatch/modes/lobby_panel.gd").new();panel.wall=true;root.add_child(panel);panel.setup(game)
	check(not game.lobby.cast(1,"ctf","lqdm1"),"Lobby proposal rejects map outside selected mode list")
	check(game.lobby.cast(2,"ctf","lqdm2"),"Another player starts visible next-match proposal")
	panel.refresh();await process_frame;await process_frame
	check(panel.active_vote.text.contains("ctf / lqdm2") and panel.active_vote.text.contains("YES 1 / 5"),"Wall shows proposal and majority counts independently of local selection")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/motion-spy/lobby-board.png")
	check(not panel.yes.disabled and not panel.no.disabled,"Eligible local player can respond Yes or No")
	panel.no.pressed.emit();panel.refresh()
	check(game.votes.ballot.votes.get(1,true)==false and panel.response.text=="You voted NO." and panel.yes.disabled and panel.no.disabled,"Wall No button submits vote and shows recorded response")
	game.votes.cast(3,false);game.votes.cast(4,false);game.votes.cast(5,false);panel.refresh()
	check(game.votes.ballot.is_empty() and panel.next_match.text.contains("VOTE FAILED") and game.lobby.result().mode=="dm","Rejected proposal leaves next-match fallback unchanged and displays outcome")
	game.clock+=6;game.lobby.cast(2,"ctf","lqdm2");panel.refresh();panel.yes.pressed.emit()
	for id in [3,4,5]:game.votes.cast(id,true)
	panel.refresh()
	check(game.lobby.confirmed and game.lobby.result()=={"mode":"ctf","map":"lqdm2"} and game.lobby.active(),"Majority approves next match without ending lobby immediately")
	check(panel.next_match.text.contains("VOTE APPROVED") and panel.next_match.text.contains("ctf".to_upper()),"Board displays confirmed next mode and map")
	await process_frame;await process_frame
	check(panel.get_combined_minimum_size().y<=720 and panel.no.get_global_rect().end.y<720,"Expanded wall fits proposal and response controls without scrolling")
	game.clock+=6;game.lobby.cast(2,"dm","lqdm1");game.players[1].spectator=true;panel.refresh()
	check(panel.yes.disabled and panel.no.disabled and panel.response.text.contains("Spectators"),"Spectator response controls are disabled with explanation")
	game.votes.ballot.clear();game.active=false;panel.free();game.free();await process_frame
	print("LOBBY_TRANSITION_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
