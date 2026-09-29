extends SceneTree
func _initialize():
	var doc:=GLTFDocument.new();var state:=GLTFState.new()
	assert(doc.append_from_file("res://deathmatch/vehicles/tribes/scout.glb",state)==OK)
	var scene:=doc.generate_scene(state)
	preload("res://deathmatch/maps/filtering.gd").new().apply(scene,2,true)
	var packed:=PackedScene.new();assert(packed.pack(scene)==OK)
	assert(ResourceSaver.save(packed,"res://deathmatch/vehicles/tribes/scout.scn",ResourceSaver.FLAG_COMPRESS)==OK)
	scene.free()
	var icon:=Image.new();assert(icon.load_svg_from_string(FileAccess.get_file_as_string("res://deathmatch/ui/weapon_icons/st_scout.svg"))==OK);icon.generate_mipmaps()
	assert(ResourceSaver.save(ImageTexture.create_from_image(icon),"res://deathmatch/vehicles/tribes/scout-icon.res",ResourceSaver.FLAG_COMPRESS)==OK)
	var sound:=AudioStreamWAV.load_from_file("res://deathmatch/vehicles/tribes/turbine.wav");assert(sound!=null)
	sound.loop_mode=AudioStreamWAV.LOOP_FORWARD;sound.loop_begin=0;sound.loop_end=sound.data.size()/2
	assert(ResourceSaver.save(sound,"res://deathmatch/vehicles/tribes/turbine.res",ResourceSaver.FLAG_COMPRESS)==OK)
	print("SCOUT_IMPORT_PASS");quit()
