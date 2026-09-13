extends SceneTree
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func run() -> void:
 if DisplayServer.get_name()=="headless":quit(1);return
 root.size=Vector2i(960,600);root.content_scale_size=root.size
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var panel=game.hud.settings_panel
 panel.config_path="/tmp/fpsloppa-presentation-ui.cfg";panel.section="graphics";panel.open()
 check(not panel.controls.has("map_atmosphere") and not panel.values.has("map_atmosphere"),"Retired sky/fog option absent")
 for i in 5:await process_frame
 check(panel.get_global_rect().end.y<=root.size.y+.1,"Graphics panel fits 600-pixel window")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/map-presentation/settings.png")
 var scroll: ScrollContainer=panel.graphics_page.get_child(0)
 scroll.scroll_vertical=10000
 for i in 3:await process_frame
 check(scroll.scroll_vertical>0,"Remaining graphics controls scroll into view")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/map-presentation/settings-bottom.png")
 FileAccess.open("res://test-results/map-presentation/ui.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"window":[960,600],"scroll":scroll.scroll_vertical},"  "))
 DirAccess.remove_absolute(panel.config_path);game.queue_free();for i in 3:await process_frame
 print("PRESENTATION_UI_RESULT ",failures);quit(0 if failures.is_empty() else 1)
