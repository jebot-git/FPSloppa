extends SceneTree
var checks:=0
var failures:Array=[]
var game
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func settle():
	for i in 5:await process_frame
func capture(label:String):
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/cq-menu/"+label+".png")
func buttons(node:Node)->Array:
	var result:Array=[]
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree():result.append(child.text)
		result.append_array(buttons(child))
	return result
func fits(book,label:String):
	check(book.back_button.get_global_rect().end.y<=root.size.y+1,label+" retains reachable Back")
	var page:Control=book.pages[book.current]
	check(page.get_combined_minimum_size().x<=page.get_parent().size.x+1,label+" fits menu width")
func run():
	DirAccess.make_dir_recursive_absolute("/tmp/cq-menu")
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	var hud=game.hud;var book=hud.menu_pages
	hud.show_menu(true);await capture("home");fits(book,"Home")
	var visible:=buttons(hud.menu)
	check(not visible.any(func(s):return "HELP" in s or "GUIDE" in s or "LIBRARY" in s),"CQ exposes no manual or library route")
	check(visible.has("DEPLOYMENT  ›") and visible.has("IDENTITY  ›") and visible.has("SETTINGS"),"CQ category index is available")
	check(book.pages.home.get_parent().get_v_scroll_bar().max_value<=book.pages.home.get_parent().size.y,"Home fits without scrolling")
	check(hud.get_child(0).theme.default_font.get_font_name()=="Unitblock","CQ root uses requested Unitblock font")
	book.navigate("play");await capture("play");fits(book,"Play")
	book.navigate("cq_connect");await capture("connect");fits(book,"Direct connection")
	hud.menu_back();check(book.current=="play","Back from direct connection returns to Play")
	book.navigate("player");await capture("identity");fits(book,"Identity")
	book.navigate("cq_prepare");await capture("deployment");fits(book,"Deployment")
	game.loadout_menu.choose_class("scout");await capture("loadout");fits(book,"Loadout")
	book.navigate("cq_primary");await capture("primary");fits(book,"Primary equipment")
	hud.menu_back();check(book.current=="cq_loadout","Equipment Back returns to loadout")
	hud.open_host();await capture("host");var host=hud.host_panel.get_meta("menu_book");fits(host,"Host")
	check(not hud.map_choice.is_visible_in_tree() and not hud.host_mode.is_visible_in_tree() and not hud.weapon_choice.is_visible_in_tree(),"Fixed CQ map, mode and weapon selectors are absent")
	check(not hud.frags.is_visible_in_tree() and not hud.minutes.is_visible_in_tree(),"Unused frag and time limits are absent")
	hud.host_panel.hide()
	var settings=hud.settings_panel;settings.open();await capture("settings");fits(settings.book,"Settings")
	for id in settings.category_pages:
		settings.book.navigate(id);await capture("settings-"+id);fits(settings.book,"Settings "+id)
	settings.book.navigate("audio")
	check(not settings.controls.music.get_parent().is_visible_in_tree(),"CQ audio has no unused music control")
	check(not settings.controls.announcer.get_parent().is_visible_in_tree(),"CQ audio has no announcer control")
	game.announcer.policy(true);game.announcer.enqueue("first_blood");game.announcer.receive("first_blood")
	check(not game.announcer.allowed and game.announcer.player==null and game.announcer.streams.is_empty() and game.announcer.pending.is_empty(),"CQ announcer stays disabled without loaded clips or queued calls")
	settings.book.navigate("tracking");await settle()
	check(settings.tracking_page.get_children().any(func(c):return c is VBoxContainer and c.has_method("setup")),"Calibration preview remains accessible")
	var ambient_row:HBoxContainer=settings.controls.ambience.get_parent()
	var ambient_buttons:Array=ambient_row.get_children().filter(func(c):return c is Button)
	check(ambient_buttons.size()==2 and ambient_buttons[0].text=="−" and ambient_buttons[1].text=="+","Ambience matches volume minus/plus controls")
	var previous_config:String=settings.config_path;settings.config_path="user://cq-ambient-stepper-test.cfg"
	var previous_ambient:float=settings.values.ambience
	settings.values.ambience=.5;settings.refresh();ambient_buttons[1].pressed.emit()
	check(is_equal_approx(settings.values.ambience,.55) and settings.controls.ambience.text=="55%","Ambient plus button applies and displays five percent step")
	ambient_buttons[0].pressed.emit()
	check(is_equal_approx(settings.values.ambience,.5),"Ambient minus button restores five percent step")
	settings.values.ambience=previous_ambient;settings.config_path=previous_config;settings.refresh()
	preload("res://deathmatch/settings/preferences.gd").apply(game,settings.values)
	DirAccess.remove_absolute("user://cq-ambient-stepper-test.cfg")
	settings.hide();hud.open_bindings();var bindings=hud.bindings_panel;bindings.select_device("desktop");bindings.select_group("COMBAT & EQUIPMENT");await capture("bindings")
	check(not bindings.buttons.has("next_weapon") and not bindings.buttons.has("previous_weapon") and not bindings.vr_choices.has("offhand_fire"),"CQ bindings omit disabled cycling and duplicate offhand fire")
	check(bindings.get_theme_default_font().get_font_name()=="Unitblock","Dynamically opened dialogs use Unitblock")
	bindings.category.open_popup();await capture("dropdown")
	check(bindings.category.popup.theme.get_meta("cq",false),"Dropdown uses CQ artwork and font")
	hud.show_menu(false);check(not bindings.visible and not settings.visible,"Closing menu closes dialogs")

	var tag=preload("res://deathmatch/ui/cq/nametag.gd").new();root.add_child(tag)
	tag.set_player_name("^1Red ^2Green",0,Color.RED)
	check(tag.text=="◆ Red Green" and tag.get_child_count()==0,"CQ names strip colour codes without creating coloured runs")
	var original:Color=tag.modulate;tag.set_player_name("^4Blue",1,Color.BLUE)
	check(tag.modulate==original,"CQ name colour is uniform across teams and user codes")
	tag.free()
	hud.name_field.text="^1Pilot";hud.clan_field.text="^2CQ"
	check(hud.display_name()=="[CQ] Pilot","CQ identity submits plain names without colour codes")

	# Render desktop and head-relative HUDs from replicated-style state.
	hud.set_process(false);hud.hud.show();hud.menu.hide()
	var state:Dictionary={"weapon":2,"hp":100,"armor":50,"ammo":[21,0,0,0],"dead":false}
	game.players[1]=state
	game.variant_combat.magazines.states[1]={"clips":{2:5},"reloading":2}
	var skin=preload("res://deathmatch/ui/cq/hud.gd")
	skin.refresh(hud,1)
	hud.match_status.text="CQ · RED 125 / BLUE 110 · FIRST TO 200\nAIRFIELD · CONTESTED"
	hud.team_badge.text="RED TEAM";hud.ability_notice.text="JETPACK READY";hud.carrier_notice.text="";hud.kill_feed.text="Pilot eliminated Scout"
	await capture("hud-desktop")
	check(hud.ammo.text=="05 LOADED\n016 RESERVE" and "RELOADING" in hud.weapon.text,"Desktop HUD reads replicated clip, reserve and reload state")
	for label in [hud.vitals,hud.weapon,hud.ammo]:
		check(label.size.y>=60 and label.get_global_rect().end.x<=960 and label.get_global_rect().end.y<=640,"Desktop HUD card fits viewport")
	state.hp=15;skin.refresh(hud,1);await capture("hud-low-health")
	check(hud.vitals.get_theme_color("font_color")==Color("ff827a"),"Low health retains warning contrast")
	hud.score_table.refresh_data({"team_game":true,"tf":false,"title":"CQ · JUNGLE FRONTIER","summary":"RED 125 / BLUE 110 · FIRST TO 200","ranked":[{"name":"^1Pilot","team":0,"kills":5,"deaths":2,"ping":28,"class_name":"SCOUT"},{"name":"^4Ranger","team":1,"kills":3,"deaths":4,"ping":35,"class_name":"MEDIC"}],"spectators":[]})
	hud.scoreboard.show();await capture("hud-scoreboard")
	check(hud.score_table.rows[0].cells[1].text=="Pilot","CQ scoreboard strips user colour codes")
	hud.hud.hide()
	var vr=preload("res://deathmatch/vr/status_hud.gd").new();vr.configure_cq();root.add_child(vr);vr.position=Vector2(0,80);vr.size=Vector2(vr.VIEW_SIZE)
	vr.update_chat([{"text":"TEAM · Hold the airfield. Transport approaching.","until":100.}],0.)
	vr.update_player_status({"team":0,"team_text":"RED TEAM","ability":"JETPACK · READY","carrier":"","flag_team":-1})
	vr.update_status(state,0.,200,125,false,false,"CQ · RED 125 BLUE 110 / 200",false,game.armory.data(2),game.armory.max_ammo(),skin.ammo_readout(game,1))
	vr.update_network({"visible":false,"fraction":0.},28,false)
	await capture("hud-vr")
	check(vr.values.ammo==5 and vr.values.reserve==16 and vr.cq_font.get_font_name()=="Unitblock","VR HUD uses matching clip/reserve data and Unitblock")
	vr.free();game.players.clear()
	game.queue_free();await settle()
	print("CQ_MENU_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
