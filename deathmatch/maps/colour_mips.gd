extends RefCounted
## Map colour data only. Never apply this transfer function to lightmaps/normals.
const VERSION := 1
const TAG := "fpsloppa_colour_mips"

static func build(source: Image, cutout: bool = false) -> Image:
	var base := source.duplicate() as Image
	if base.is_compressed() and base.decompress() != OK:return source
	var original_format := base.get_format()
	base.clear_mipmaps()
	base.convert(Image.FORMAT_RGBA8)
	if cutout:base.fix_alpha_edges()
	var width := base.get_width();var height := base.get_height()
	var linear := Image.create(width,height,false,Image.FORMAT_RGBAF)
	var coverage := 0.0
	for y in height:
		for x in width:
			var c := base.get_pixel(x,y)
			linear.set_pixel(x,y,c.srgb_to_linear())
			if c.a >= 0.5:coverage += 1.0
	coverage /= float(width*height)
	if linear.generate_mipmaps() != OK:return source
	# Keep level zero byte-exact (apart from invisible cutout edge padding).
	var bytes := base.get_data()
	var floats := linear.get_data().to_float32_array()
	for level in range(1,linear.get_mipmap_count()+1):
		var w := maxi(1,width >> level);var h := maxi(1,height >> level)
		var offset := linear.get_mipmap_offset(level)/4
		var scale := 1.0
		if cutout and coverage > 0.0 and coverage < 1.0:
			# Closest representable coverage at this resolution, without moving
			# the threshold. Ties prefer the unscaled mip to avoid overgrowth.
			var best_error := INF;var lo := 0.0;var hi := 8.0
			for step in 14:
				var trial := 1.0 if step == 0 else (lo+hi)*0.5
				var passed := 0
				for i in w*h:
					if roundi(clampf(floats[offset+i*4+3]*trial,0,1)*255) >= 128:passed += 1
				var actual := float(passed)/float(w*h)
				if absf(actual-coverage) < best_error:
					best_error=absf(actual-coverage);scale=trial
				if actual < coverage:lo=trial
				else:hi=trial
		for i in w*h:
			var at := offset+i*4
			var c := Color(floats[at],floats[at+1],floats[at+2],floats[at+3]).linear_to_srgb()
			bytes.append(roundi(clampf(c.r,0,1)*255));bytes.append(roundi(clampf(c.g,0,1)*255));bytes.append(roundi(clampf(c.b,0,1)*255))
			bytes.append(roundi(clampf(c.a*scale,0,1)*255))
	var result := Image.create_from_data(width,height,linear.has_mipmaps(),Image.FORMAT_RGBA8,bytes)
	if original_format == Image.FORMAT_RGB8:result.convert(Image.FORMAT_RGB8)
	return result

static func prepare(source: Texture2D, cutout: bool = false) -> Texture2D:
	if not source or source is ViewportTexture:return source
	var version := VERSION*2+int(cutout)
	if source.get_meta(TAG,-1) == version:return source
	var image := source.get_image()
	if not image:return source
	var result := ImageTexture.create_from_image(build(image,cutout))
	result.set_meta(TAG,version)
	return result
