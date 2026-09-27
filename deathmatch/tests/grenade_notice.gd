extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Selection notice",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	await physics_frame;await physics_frame
	var de=g.match_mode.defusal;de.tick(0);de.phase="live";de.carrier=1;g.menu_open=false
	g.players[1].vr_device=true;g.players[1].physical=true
	var u=de.utility;u.state(1).counts=[1,2,1]
	var panel=load("res://deathmatch/vr/status_hud.gd").new();root.add_child(panel);panel.size=Vector2(panel.VIEW_SIZE)
	var notice=panel.grenade_notice
	notice.update_selection(g,1);check(not notice.visible,"Default shoulder inventory does not repeatedly announce itself")
	for kind in 3:
		check(u.select_shoulder(1,kind),"Select grenade "+str(kind));notice.update_selection(g,1)
		check(notice.visible and notice.selected==kind and notice.icon==load("res://deathmatch/ui/weapon_icons.gd").texture(u.NAMES[kind]),"Accepted selection displays its matching icon")
		var status: Dictionary=load("res://deathmatch/ui/player_status.gd").read(g,1)
		check(status.ability.contains("SHOULDER: "+u.NAMES[kind]) and status.carrier.contains("BOMB"),"Grenade status coexists with bomb-carrier status")
		check(u.selected(1)==-1 and not de.gun_holstered(1),"Announcement leaves the gun equipped")
		var expiry: float=notice.until
		u.receive(u.snapshot());g.clock+=.1;notice.update_selection(g,1)
		check(notice.until==expiry,"Repeated authoritative snapshots do not restart popup")
		panel.update_player_status(status)
		panel.update_status(g.players[1],60,20,0,false,false,"DE · TEST",false,g.armory.data(g.players[1].weapon),g.armory.max_ammo())
		if DisplayServer.get_name()!="headless":
			for layer in g.find_children("*","CanvasLayer",true,false):layer.hide()
			root.size=panel.VIEW_SIZE;root.content_scale_size=root.size
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/cs16/mag-pull/grenade-"+str(kind)+".png")
		g.clock=expiry+.01;notice.update_selection(g,1)
		check(not notice.visible,"Selection icon expires after a short popup")
	u.state(1).counts[0]=0
	check(not u.select_shoulder(1,0),"Empty type cannot be selected");notice.update_selection(g,1)
	check(not notice.visible and notice.selected==2,"Rejected selection does not announce a different grenade")
	g.players[1].dead=true;notice.update_selection(g,1);check(not notice.visible,"Death clears popup")
	print("GRENADE_NOTICE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));g.disconnect_game();g.free();panel.free();quit(0 if failures.is_empty() else 1)
