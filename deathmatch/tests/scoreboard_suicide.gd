extends SceneTree
var failures: Array=[]
class TestBindings extends RefCounted:
	var held:=false
	var two_handed:=true
	func pressed(action: String) -> bool:return held and action=="scores"
	func vr_pressed(_rig,action: String) -> bool:return held and action=="scores"
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1024,640);root.content_scale_size=Vector2i(1024,640)
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_process(false);g.set_physics_process(false)
	g._add_player(1,"Long player name 1234567890123456789");g.active=true;g.intermission=0;g.menu_open=false
	var s: Dictionary=g.players[1];s.armor=200;s.hp=200;s.invulnerable=g.clock+999
	check(g._suicide_for(1),"Suicide bypasses armour and spawn protection")
	check(s.dead and s.kills==-1 and s.deaths==1 and s.want_respawn,"Suicide costs exactly one frag/death and requests respawn")
	check(not g._suicide_for(1) and s.kills==-1,"Repeated requests while dead do not penalize twice")
	g._spawn(1);check(not s.dead and s.owned==[2],"Normal respawn restores pistol-only loadout")
	s.spectator=true;check(not g._suicide_for(1),"Spectators cannot suicide");s.spectator=false
	g.intermission=10;check(not g._suicide_for(1),"Intermission rejects suicide");g.intermission=0
	g.match_mode.special.frozen[1]=0.0;check(not g._suicide_for(1),"Suicide cannot bypass a freezetag freeze");g.match_mode.special.frozen.clear()
	check(not g._suicide_for(98765),"Unknown peer cannot suicide another player")
	g.match_mode.kind="tf";g.match_mode.reset();s.team=0
	g.match_mode.flags[1].carrier=1
	check(g._suicide_for(1) and g.match_mode.flags[1].carrier==0,"Suicide drops a carried TF flag through normal death handling")
	g._spawn(1);g.match_mode.kind="dm"
	g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
	g.hud.show_menu(false)
	for id in range(2,17):g._add_player(id,"Marine_%02d_very_long_name"%id)
	var roles: Array=g.match_mode.fortress.CLASSES.keys()
	for id in g.players:
		g.players[id].team=id%2;g.players[id].tf_class=roles[(id-1)%roles.size()];g.players[id].kills=16-id;g.players[id].ping=20+id*5
	g.match_mode.kind="tf"
	g.hud.score_table.refresh(g);g.hud.scoreboard.show()
	root.size=Vector2i(1024,640)
	await process_frame;await process_frame
	var board=g.hud.score_table
	check(board.rows.filter(func(row):return row.panel.visible).size()==16,"All 16 players have visible rows")
	check(board.size.x<=1024 and board.size.y<=640 and board.get_global_rect().position.y>=0 and board.get_global_rect().end.y<=640,"Full scoreboard fits VR's 1024x640 surface")
	check(board.rows[15].panel.get_global_rect().end.y<=640,"Sixteenth row is not clipped")
	check(board.rows[0].cells[2].visible and not board.rows[0].cells[2].text.is_empty(),"TF rows show active class")
	check(board.rows[0].cells[1].get_theme_color("font_color")==board.RED and board.rows[8].cells[1].get_theme_color("font_color")==board.BLUE,"Team roster uses matching red/blue text")
	g.match_mode.kind="dm";board.refresh(g);check(not board.rows[0].cells[2].visible,"Class column is hidden outside TF")
	# UI consumes the binding's level state; releasing it must hide immediately.
	var desktop_bindings=TestBindings.new();var saved_bindings=g.bindings;g.bindings=desktop_bindings
	desktop_bindings.held=true;g.hud._process(.016);check(g.hud.scoreboard.visible,"Desktop scoreboard appears on hold")
	desktop_bindings.held=false;g.hud._process(.016);check(not g.hud.scoreboard.visible,"Desktop scoreboard disappears on release")
	g.bindings=saved_bindings
	g.intermission=10;g.hud._process(.016);check(not g.hud.scoreboard.visible,"Round end does not force scoreboard")
	# Polling VR button state is level-triggered, including focus loss.
	var rig=load("res://deathmatch/vr/rig.gd").new();g.add_child(rig);rig.game=g
	var bindings=TestBindings.new();var original=g.bindings;g.bindings=bindings;rig.focused=true
	bindings.held=true;rig.poll_controls();check(rig.scores,"VR hold opens scoreboard")
	rig.poll_controls();check(rig.scores,"Continued hold does not toggle scoreboard off")
	bindings.held=false;rig.poll_controls();check(not rig.scores,"VR release closes scoreboard")
	bindings.held=true;rig.focused=false;rig.poll_controls();check(not rig.scores,"Lost focus clears held scoreboard")
	g.bindings=original;rig.free()
	if "--preview" in OS.get_cmdline_user_args():
		g.intermission=0;g.hurt_flash=0;g.feed.clear();g.match_mode.kind="tf";g.hud.score_table.refresh(g);g.hud.scoreboard.show();g.hud.set_process(false)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/scoreboard-16-tf.png")
	print("SCOREBOARD_SUICIDE_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
