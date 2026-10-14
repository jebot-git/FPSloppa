extends RefCounted
## Generate mipmaps at allocation/upload time, never during a sampling-mode switch.
static func image(source:Image,normal:bool=false) -> Image:
	if source.has_mipmaps() or maxi(source.get_width(),source.get_height())<=1:return source
	if source.is_compressed():
		source=source.duplicate() as Image
		if source.decompress()!=OK:return source
	var error:=source.generate_mipmaps(normal)
	if error!=OK:push_error("Cannot generate texture mipmaps: "+error_string(error))
	return source
static func create(source:Image,normal:bool=false) -> ImageTexture:
	source=image(source,normal)
	var texture:=ImageTexture.create_from_image(source)
	if source.has_mipmaps():texture.set_meta("fpsloppa_mipmaps_ready",true)
	return texture
