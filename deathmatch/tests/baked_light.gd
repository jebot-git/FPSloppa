extends SceneTree
func _initialize():
	var bake=preload("res://deathmatch/maps/baked_light.gd").new()
	bake.enabled=true;bake.image=Image.create(1024,1024,false,Image.FORMAT_RGB8)
	bake.lighting=PackedByteArray([32,64,128,255]);bake.rgb=PackedByteArray([255,0,0,0,255,0,0,0,255,255,255,255])
	var uv=bake.face_uvs(PackedVector2Array([Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]),Vector2(16,16),0)
	# Fractional UV extents span three luxels here, so malformed data must safely fallback.
	assert(uv[0]==Vector2(.5,.5)/1024)
	assert(bake.invalid_faces==1 and bake.overflow_faces==0)
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
	var fine=preload("res://deathmatch/maps/baked_light.gd").new()
	fine.enabled=true;fine.image=Image.create(1024,1024,false,Image.FORMAT_RGB8)
	fine.scales=PackedByteArray([3]);fine.lighting=PackedByteArray([0,16,32,48,64,80,96,112,128])
	var points:=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
	var fine_uv: PackedVector2Array=fine.face_uvs(points,Vector2(16,16),0,0)
	assert(fine_uv[0]==Vector2(3.5,1.5)/1024 and fine_uv[2]==Vector2(5.5,3.5)/1024)
	assert(fine.image.get_pixel(4,2)==Color8(64,64,64) and fine.faces==1)
	# Missing per-face metadata uses the ordinary 16-unit layout safely.
	var fallback=preload("res://deathmatch/maps/baked_light.gd").new()
	fallback.enabled=true;fallback.image=Image.create(1024,1024,false,Image.FORMAT_RGB8);fallback.lighting=fine.lighting
	assert(fallback.face_uvs(points,Vector2(16,16),0,99)[2]==Vector2(4.5,2.5)/1024)
	print("BAKED_LIGHT_TEST PASS");quit()
