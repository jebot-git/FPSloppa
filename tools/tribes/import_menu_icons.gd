extends SceneTree
const DIRECTORY="res://deathmatch/tribes/menu_icons/"
func _initialize():
	for file in DirAccess.get_files_at(DIRECTORY):
		if not file.ends_with(".svg"):continue
		var image:=Image.new();assert(image.load_svg_from_string(FileAccess.get_file_as_string(DIRECTORY+file),2)==OK);image.generate_mipmaps()
		assert(ResourceSaver.save(ImageTexture.create_from_image(image),DIRECTORY+file.get_basename()+".res",ResourceSaver.FLAG_COMPRESS)==OK)
	quit()
