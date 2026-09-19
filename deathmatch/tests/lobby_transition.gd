extends SceneTree
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1200,720);root.content_scale_size=root.size
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
	game.votes.allowed_modes=["dm","ctf"];game.mode_maplists={"dm":["qsrc_dm1","qsrc_dm6"],"ctf":["qsrc_dm6"]};game.lobby.prepare()
	var panel=load("res://deathmatch/modes/lobby_panel.gd").new();panel.wall=true;root.add_child(panel);panel.setup(game)
	check(panel.grid.columns==3 and panel.cards.size()==9,"Voting wall presents nine complete combinations in a 3x3 grid")
	check(not game.lobby.cast(1,"ctf","qsrc_dm1"),"Ballot rejects a map outside the mode maplist")
	panel.cards[0].button.pressed.emit();panel.refresh()
	check(game.lobby.selections.get(1)==0 and panel.cards[0].count.text.contains("YOUR VOTE"),"A single card click records and displays the local vote")
	panel.cards[1].button.pressed.emit();game.lobby.cast_option(2,game.lobby.ballot_id,1);panel.refresh()
	check(game.lobby.tally()[0]==0 and game.lobby.tally()[1]==2 and game.lobby.result()==game.lobby.spec(game.lobby.offered[1]),"Changing a card updates the tally and winner without a proposal")
	await process_frame;await process_frame
	check(panel.get_combined_minimum_size().y<=720 and panel.cards[8].button.get_global_rect().end.y<720,"Nine cards fit the voting wall without scrolling")
	game.players[1].spectator=true;panel.refresh()
	check(panel.cards.all(func(card):return card.button.disabled) and panel.response.text.contains("Spectators"),"Spectators see the ballot with voting disabled")
	game.votes.ballot.clear();game.active=false;panel.free();game.free();await process_frame
	print("LOBBY_TRANSITION_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
