extends SceneTree
const Bindings=preload("res://deathmatch/settings/bindings.gd")
const Profile=preload("res://deathmatch/profile.gd")
class Arena extends Node:
	var bindings=Bindings.new()
	var vr:=false
	func is_vr() -> bool:return vr
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(value: bool,label: String):
	checks+=1;print("PASS " if value else "FAIL ",label)
	if not value:failures.append(label)
func run():
	# Use a dedicated config; never replace the player's real preferences.
	if not "--client-config" in OS.get_cmdline_user_args():push_error("Pass --client-config with a disposable path");quit(2);return
	var path:=Profile.config_path();var c:=ConfigFile.new();var b:=Bindings.new()
	for revision in [null,1,2,"invalid"]:
		c.clear()
		if revision!=null:c.set_value("bindings_meta","revision",revision)
		c.set_value("bindings","forward",KEY_P);c.set_value("vr_bindings","jump","support:trigger");c.set_value("vr_axes","move","right")
		c.set_value("control_options","physical_crouch",false);c.set_value("player","name","Keep me");c.set_value("audio","volume",.42);c.save(path)
		b.load_settings()
		check(b.keys==Bindings.KEYS and b.vr==Bindings.VR and b.axes=={"move":"move","turn":"turn"},"Major revision resets every mapping: "+str(revision))
		c.load(path)
		check(c.get_value("bindings_meta","revision")==Bindings.CONTROLS_REVISION and c.get_value("bindings","forward")==KEY_W,"Reset and revision persist immediately")
		check(not b.physical_crouch and c.get_value("player","name")=="Keep me" and is_equal_approx(c.get_value("audio","volume"),.42),"Reset preserves tracking and unrelated preferences")
	b.keys.forward=KEY_O;b.vr.jump="left:by_button";b.axes.move="right";b.save();b=Bindings.new();b.load_settings()
	check(b.keys.forward==KEY_O and b.vr.jump=="left:by_button" and b.axes.move=="right","Same revision preserves custom controls on next launch")
	b.reset_bindings("desktop");check(b.keys==Bindings.KEYS and b.vr.jump=="left:by_button" and b.axes.move=="right","Desktop reset leaves VR bindings alone")
	b.keys.forward=KEY_O;b.reset_bindings("vr");check(b.keys.forward==KEY_O and b.vr==Bindings.VR and b.axes.move=="move","VR reset leaves desktop bindings alone")
	c.load(path);c.set_value("bindings","forward",0);c.set_value("vr_bindings","jump","bogus:trigger");c.set_value("vr_axes","move","bogus");c.save(path);b.load_settings()
	check(b.keys.forward==KEY_W and b.vr.jump==Bindings.VR.jump and b.axes.move=="move","Invalid stored mappings fall back to defaults on repeated load")
	DirAccess.remove_absolute(path);b.load_settings();c.load(path)
	check(c.get_value("bindings_meta","revision")==Bindings.CONTROLS_REVISION,"Fresh configuration records current revision")
	var game:=Arena.new();root.add_child(game);game.bindings.load_settings()
	var panel=preload("res://deathmatch/settings/bindings_panel.gd").new();root.add_child(panel);panel.setup(game);panel.open()
	await process_frame;await process_frame
	check(panel.pages.desktop.is_visible_in_tree() and not panel.pages.vr.is_visible_in_tree() and panel.buttons.size()==Bindings.KEYS.size(),"Desktop tab exposes all keyboard mappings without VR controls")
	check(panel.notice.text.is_empty(),"No help text block on opening")
	panel.buttons.forward.pressed.emit();var key:=InputEventKey.new();key.physical_keycode=KEY_I;key.pressed=true;panel._input(key)
	check(game.bindings.keys.forward==KEY_I and panel.capture.is_empty() and panel.buttons.forward.text=="I","Desktop key capture saves and refreshes label")
	panel.buttons.forward.pressed.emit();key.physical_keycode=KEY_ESCAPE;panel._input(key)
	check(game.bindings.keys.forward==KEY_I and panel.capture.is_empty(),"Escape cancels without rebinding")
	panel.buttons.fire.pressed.emit();var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_XBUTTON1;mouse.pressed=true;panel._input(mouse)
	check(game.bindings.keys.fire==-MOUSE_BUTTON_XBUTTON1 and panel.buttons.fire.text=="Mouse back","Mouse binding displays a readable label")
	panel.begin_capture("jump");panel.tabs.vr.pressed.emit()
	check(panel.capture.is_empty() and panel.pages.vr.is_visible_in_tree() and not panel.pages.desktop.is_visible_in_tree(),"Switching tabs cancels capture and isolates VR controls")
	panel.vr_choices.jump[0].choose("left");panel.vr_choices.jump[1].choose("by_button");panel.axis_choices.move.choose("right")
	check(game.bindings.vr.jump=="left:by_button" and game.bindings.axes.move=="right","Separate hand and input selectors preserve the other binding component")
	b.load_settings();check(b.vr.jump=="left:by_button" and b.axes.move=="right" and b.keys.forward==KEY_I,"UI edits survive reload")
	panel.vr_choices.jump[1].choose("none");check(game.bindings.vr.jump=="left:none","VR action can be unbound")
	panel.checks.physical_jump.button_pressed=true;check(game.bindings.physical_jump,"Physical controls remain editable on VR tab")
	panel.vr_choices.jump[0].open_popup();panel.tabs.desktop.pressed.emit()
	check(not panel.vr_choices.jump[0].popup.visible,"Switching tabs immediately closes selectors")
	panel.reset.pressed.emit();check(game.bindings.keys==Bindings.KEYS and game.bindings.vr.jump=="left:none","Desktop reset button preserves VR customization")
	game.vr=true;panel.open();check(panel.device=="vr","Opening in VR selects the VR tab")
	panel.reset.pressed.emit();check(game.bindings.vr==Bindings.VR and game.bindings.axes.move=="move","VR reset refreshes its mappings")
	if "--render" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://test-results/bindings")
		root.content_scale_size=Vector2i.ZERO
		for device in ["desktop","vr"]:
			root.size=Vector2i(1000,720);panel.select_device(device)
			for i in 5:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/bindings/"+device+".png")
		root.size=Vector2i(853,640)
		for i in 5:await process_frame
		check(panel.size.x<=853 and panel.reset.get_global_rect().end.y<=640,"VR menu fits its compact viewport with reset visible")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/bindings/vr-compact.png")
	panel.hide();panel.free();game.free()
	print("BINDINGS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
