extends SceneTree
var failures: Array=[]
var capture:=false
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func settle():
	for i in 4:await process_frame
func snapshot(label: String):
	if not capture:return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/menu-navigation/"+label+".png")
func run():
	capture=DisplayServer.get_name()!="headless"
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	DirAccess.make_dir_recursive_absolute("res://test-results/menu-navigation")
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	if not g.hud:
		g.voice.panel=preload("res://deathmatch/voice/panel.gd").new();g.voice.add_child(g.voice.panel);g.voice.panel.setup(g.voice)
		g.hud=load("res://deathmatch/interface.gd").new();g.add_child(g.hud);g.hud.setup(g)
	g.set_process(false)
	var hud=g.hud;var book=hud.menu_pages;var settings=hud.settings_panel
	await settle()
	var home: ScrollContainer=book.pages.home.get_parent()
	check(home.get_v_scroll_bar().max_value<=home.size.y,"Home fits 960×640 without scrolling")
	await snapshot("home")
	book.navigate("player");await settle()
	check(book.back_button.visible,"Submenu Back remains reachable before joining a match")
	check(hud.menu_back() and book.current=="home","Menu button moves up one level")
	settings.open();await settle()
	check(settings.book.current=="home","Settings opens its category index")
	await snapshot("settings")
	for id in settings.category_pages:
		settings.book.navigate(id);await settle()
		check(settings.get_global_rect().end.y<=640 and settings.book.back_button.get_global_rect().end.y<=640,"Settings footer fits: "+id)
	settings.book.navigate("devices");hud.menu_back()
	check(settings.visible and settings.book.current=="audio","Back returns from audio devices to volumes")
	hud.menu_back();check(settings.visible and settings.book.current=="home","Back returns to settings categories")
	hud.menu_back();check(not settings.visible,"Back closes settings at its index")
	hud.open_host();await settle();await snapshot("host")
	var host_book=hud.host_panel.get_meta("menu_book");host_book.navigate("rules");await settle()
	check(host_book.back_button.get_global_rect().end.y<=640,"Host rules retain visible fixed Back")
	hud.menu_back();hud.menu_back();check(not hud.host_panel.visible,"Host Back traverses category and closes")
	hud.open_bindings();await settle()
	var bindings=hud.bindings_panel;bindings.select_device("desktop");await settle()
	var scroll=bindings.scroll
	preload("res://deathmatch/ui/drag_scroll.gd").scroll_active(root,1,.4);await settle()
	check(scroll.scroll_vertical>80,"Stick scrolls an ordinary options list")
	var before:int=scroll.scroll_vertical
	bindings.category.open_popup();preload("res://deathmatch/ui/drag_scroll.gd").scroll_active(root,1,.4)
	check(scroll.scroll_vertical==before,"Dropdown blocks scrolling the underlying page")
	hud.menu_back();check(not bindings.category.popup.visible and bindings.visible,"Back dismisses dropdown before its page")
	bindings.select_group("COMBAT & EQUIPMENT");await settle()
	check(scroll.scroll_vertical==0,"Changing category resets scroll position")
	check(not bindings.groups.desktop.MOVEMENT.visible,"Unselected binding categories are hidden")
	await snapshot("bindings")
	settings.open();await settle()
	preload("res://deathmatch/ui/drag_scroll.gd").scroll_active(root,1,.5)
	check(scroll.scroll_vertical==0,"A modal prevents scrolling the covered bindings page")
	hud.show_menu(false);await settle()
	check(not bindings.visible and not settings.visible,"Closing menu closes child dialogs")
	# A release after a hidden drag must not retain pressed/toggle states.
	hud.show_menu(true);hud.open_bindings();bindings.select_device("desktop");await settle()
	scroll.pressed=true;scroll.dragging=true;bindings.hide();await settle()
	check(not scroll.pressed and not scroll.dragging,"Hidden scroller cancels its gesture")
	g.queue_free();await settle()
	var list=preload("res://deathmatch/ui/drag_list.gd").new();root.add_child(list);list.size=Vector2(300,200);list.vr_mode_override=true
	for i in 40:list.add_item("Model %d"%i)
	list.select(0);var selected: Array=[];list.item_selected.connect(func(index):selected.append(index));await settle()
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=Vector2(50,130);root.push_input(press,true)
	var motion:=InputEventMouseMotion.new();motion.position=Vector2(50,30);motion.relative=Vector2(0,-100);root.push_input(motion,true)
	var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=Vector2(50,30);root.push_input(release,true)
	check(list.scroll_vertical>=90 and selected.is_empty(),"Dragging a selectable list does not activate an item")
	check(list.entries[0].button_pressed,"Dragging preserves the existing toggle selection")
	list.free();await settle()
	print("MENU_NAVIGATION_RESULT ",failures);quit(0 if failures.is_empty() else 1)
