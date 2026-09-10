extends SceneTree
func _initialize():
	var bake=preload("res://deathmatch/maps/baked_light.gd").new()
	bake.enabled=true;bake.image=Image.create(1024,1024,false,Image.FORMAT_RGB8)
	bake.lighting=PackedByteArray([32,64,128,255]);bake.rgb=PackedByteArray([255,0,0,0,255,0,0,0,255,255,255,255])
	var uv=bake.face_uvs(PackedVector2Array([Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]),Vector2(16,16),0)
	# Fractional UV extents span three luxels here, so malformed data must safely fallback.
	assert(uv[0]==Vector2(.5,.5)/1024)
	uv=bake.face_uvs(PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]),Vector2(16,16),0)
	assert(bake.faces==1)
	assert(bake.image.get_pixel(3,1)==Color.RED)
	assert(bake.image.get_pixel(4,1)==Color.GREEN)
	assert(bake.image.get_pixel(3,2)==Color.BLUE)
	assert(bake.image.get_pixel(2,0)==Color.RED) # gutter replication
	assert(uv[0]==Vector2(3.5,1.5)/1024)
	assert(uv[2]==Vector2(4.5,2.5)/1024)
	bake.enabled=false
	assert(bake.face_uvs(PackedVector2Array([Vector2.ZERO]),Vector2.ONE,0).is_empty())
	bake.enabled=true
	var fence:=StandardMaterial3D.new();fence.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	assert(bake.material(fence).get_shader_parameter("alpha_cutout")==true)
	var opaque:=StandardMaterial3D.new()
	assert(bake.material(opaque).get_shader_parameter("alpha_cutout")==false)
	print("BAKED_LIGHT_TEST PASS");quit()
