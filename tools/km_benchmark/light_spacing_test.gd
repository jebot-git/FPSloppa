extends SceneTree
const Bake=preload("res://deathmatch/maps/baked_light.gd")
func _initialize() -> void:
	# A known 32-texel square is 2x2 at the city density, 3x3 at legacy density.
	# Distinct corner samples detect accidentally reading a neighbour's lightmap.
	for spacing in [16,32]:
		var bake:=Bake.new();bake.enabled=true;bake.default_spacing=spacing;bake.atlas_size=32
		bake.image=Image.create(32,32,false,Image.FORMAT_RGB8)
		bake.lighting=PackedByteArray([0,50,100,200] if spacing==32 else [0,25,50,75,100,125,150,175,200])
		var uvs:=bake.face_uvs(PackedVector2Array([Vector2.ZERO,Vector2(.5,0),Vector2(.5,.5),Vector2(0,.5)]),Vector2(64,64),0)
		assert(bake.invalid_faces==0 and bake.faces==1)
		for i in 4:
			var pixel:=Vector2i((uvs[i]*32).floor());var expected: float=[0,50,200,100][i] if spacing==32 else [0,50,200,150][i]
			assert(absf(bake.image.get_pixelv(pixel).r-expected/255.0)<.005)
	for night in [false,true]:
		var bake:=Bake.new();bake.enabled=true;bake.night_response=night;bake.black_missing=night;bake.atlas_size=32
		bake.image=Image.create(32,32,false,Image.FORMAT_RGB8)
		bake.texture=ImageTexture.create_from_image(bake.image)
		var material: ShaderMaterial=bake.material(StandardMaterial3D.new())
		assert(material.get_shader_parameter("night_lighting")==night)
		var uv:=bake.face_uvs(PackedVector2Array([Vector2.ZERO]),Vector2(32,32),-1)
		assert(uv[0]==Vector2(1.5 if night else .5,.5)/32)
		assert(bake.dark_faces==(1 if night else 0))
	print("CITY_LIGHT_SPACING_PASS legacy16 and city32 corner samples")
	quit()
