extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 root.size=Vector2i(1100,650)
 var world:=Node3D.new();root.add_child(world)
 var environment:=WorldEnvironment.new();var settings:=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("182029");environment.environment=settings;world.add_child(environment)
 var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=65
 var markers=preload("res://deathmatch/conquest/classes/spotted_markers.gd").new();world.add_child(markers);markers.set_process(false)
 var targets:Dictionary={};var i:=0
 for kind in markers.TITLES:
  targets[kind]={"kind":kind,"position":Vector3(-3.3+(i%4)*2.2,1.05-(i/4)*2.2,-8)};i+=1
 markers.sync(targets)
 var layer:=CanvasLayer.new();root.add_child(layer)
 var title:=Label.new();title.position=Vector2(35,20);title.text="CQ · SPOTTED ENEMY MARKERS";title.add_theme_font_size_override("font_size",24);layer.add_child(title)
 var note:=Label.new();note.position=Vector2(35,600);note.text="Class symbols · driven vehicle silhouettes · existing spotting visibility and memory";note.add_theme_font_size_override("font_size",17);layer.add_child(note)
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute("res://docs/validation/voxel-battle/designation-markers-20261015")
 root.get_texture().get_image().save_png("res://docs/validation/voxel-battle/designation-markers-20261015/markers.png")
 world.free();layer.free();await process_frame;quit()
