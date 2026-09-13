extends SceneTree
func _initialize():call_deferred("run")
func run() -> void:
	root.size=Vector2i(960,480)
	var background:=ColorRect.new();background.color=Color("1b2429");background.size=Vector2(960,480);root.add_child(background)
	var hud=preload("res://deathmatch/vr/status_hud.gd").new();root.add_child(hud);hud.size=Vector2(960,480)
	hud.update_chat([{"text":"TEAM: Take the upper route; the sentry is watching the bridge.","until":100.0}],0)
	hud.update_player_status({"team":0,"team_text":"RED TEAM","ability":"GRENADE · READY IN 2.5s","carrier":"YOU HAVE THE BLUE FLAG · RETURN TO YOUR CAPTURE POINT","flag_team":1})
	hud.update_vote({"title":"Change map to Frigate?","yes":2,"needed":3,"no":1,"seconds":15})
	hud.update_status({"weapon":6,"hp":115,"armor":80,"ammo":[20,10,7,50],"dead":false},8,20,10,false,true,"TF R1 B0 / 5")
	hud.update_network({"visible":false,"fraction":0},29,false)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/live-0.10v/hud-notifications.png")
	print("HUD_NOTIFICATION_RENDERED");quit()
