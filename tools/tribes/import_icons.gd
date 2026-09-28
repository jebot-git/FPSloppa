extends SceneTree
func _initialize():
	for file in DirAccess.get_files_at("res://deathmatch/ui/weapon_icons"):
		if not file.begins_with("tribes_") or not file.ends_with(".svg"):continue
		if not OS.get_cmdline_user_args().is_empty() and file.get_basename() not in OS.get_cmdline_user_args():continue
		var image:=Image.new();assert(image.load_svg_from_string(FileAccess.get_file_as_string("res://deathmatch/ui/weapon_icons/"+file),2)==OK);image.generate_mipmaps()
		assert(ResourceSaver.save(ImageTexture.create_from_image(image),"res://deathmatch/weapons/tribes/"+file.get_basename()+".res",ResourceSaver.FLAG_COMPRESS)==OK)
	quit()
