extends SceneTree
const Mips=preload("res://deathmatch/maps/colour_mips.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)
func _initialize() -> void:
	var checker:=Image.create(2,2,false,Image.FORMAT_RGBA8)
	checker.fill(Color.BLACK);checker.set_pixel(0,0,Color.WHITE);checker.set_pixel(1,1,Color.WHITE)
	var result:=Mips.build(checker)
	var bytes:=result.get_data();var at:=result.get_mipmap_offset(1)
	check(abs(int(bytes[at])-188)<=1,"Black/white average is sRGB 188, not 128")
	check(bytes.slice(0,16)==checker.get_data(),"Level zero preserved exactly")
	var dark:=Image.create(2,2,false,Image.FORMAT_RGBA8);dark.fill(Color8(10,20,30))
	var dark_mips:=Mips.build(dark);var dark_bytes:=dark_mips.get_data()
	check(dark_bytes.slice(16,20)==dark.get_data().slice(0,4),"Dark constant colours survive without 8-bit linear quantization")
	var rgb:=dark.duplicate() as Image;rgb.convert(Image.FORMAT_RGB8)
	check(Mips.build(rgb).get_format()==Image.FORMAT_RGB8,"RGB input retains its storage size")
	var cutout:=Image.create(8,8,false,Image.FORMAT_RGBA8);cutout.fill(Color(0,0,0,0))
	for y in 8:
		for x in 8:
			if x%2==0:cutout.set_pixel(x,y,Color(1,0,0,1))
	var padded:=Mips.build(cutout,true)
	check(padded.get_pixel(1,0).r>0.9 and padded.get_pixel(1,0).a==0,"Cutout transparent edges carry neighbouring colour without becoming opaque")
	var mask:=Image.create(32,32,false,Image.FORMAT_RGBA8);mask.fill(Color(0,0,0,0))
	var coverage:=0.0
	for y in 32:
		for x in 32:
			if (x*13+y*7)%11<4:mask.set_pixel(x,y,Color.WHITE);coverage+=1.0
	coverage/=1024.0
	var corrected:=Mips.build(mask,true);var naive:=mask.duplicate() as Image;naive.generate_mipmaps()
	var cb:=corrected.get_data();var nb:=naive.get_data()
	for mip in range(1,corrected.get_mipmap_count()+1):
		var count:=maxi(1,32>>mip)*maxi(1,32>>mip);var start:=corrected.get_mipmap_offset(mip)
		var cc:=0.0;var nc:=0.0
		for i in count:
			if cb[start+i*4+3]>=128:cc+=1.0
			if nb[start+i*4+3]>=128:nc+=1.0
		check(absf(cc/count-coverage)<=absf(nc/count-coverage)+0.00001,"Cutout coverage is no worse than naive mips at level "+str(mip))
	var npot:=Image.create(7,3,false,Image.FORMAT_RGBA8);npot.fill(Color8(45,70,90))
	var small:=Mips.build(npot)
	check(small.get_size()==Vector2i(7,3) and small.has_mipmaps(),"Non-power-of-two texture supported")
	var tex:=ImageTexture.create_from_image(checker)
	var prepared:=Mips.prepare(tex)
	check(Mips.prepare(prepared)==prepared,"Prepared textures are reused")
	var path:="res://test-results/static-rendering/mip-test.res"
	check(ResourceSaver.save(prepared,path)==OK,"Save prepared resource")
	var restored:=load(path) as Texture2D
	check(restored.get_image().get_data()==prepared.get_image().get_data() and Mips.prepare(restored)==restored,"Mip pixels and preparation version survive serialization")
	var material:=StandardMaterial3D.new();material.albedo_texture=tex
	var filter:=Filtering.new();filter.material(material)
	check(not material.albedo_texture.has_meta(Mips.TAG),"Non-map materials retain the existing preparation path")
	var map_material:=StandardMaterial3D.new();map_material.albedo_texture=tex;map_material.set_meta("bsp_texture_name","test")
	filter.material(map_material)
	check(map_material.albedo_texture.has_meta(Mips.TAG),"BSP material receives colour mips")
	print("MAP_COLOUR_MIPS_RESULT ",JSON.stringify({"failures":failures,"linear_average_srgb":bytes[at]}))
	quit(0 if failures.is_empty() else 1)
