extends RefCounted
## Original synthetic terrain/architecture. No NovaLogic game assets or BSP input.
const SIZE:=513
const EXTENT:=250.0
const BASE:=2.4
var heights:=PackedFloat32Array()
var colors:=PackedColorArray()
var solid_heights:=PackedFloat32Array()
var solid_colors:=PackedInt32Array()
var terrain_colors:=PackedInt32Array()
var height_texture: ImageTexture
var color_texture: ImageTexture
var boxes: Array=[]
var factory_mesh: ArrayMesh
var metadata: Dictionary={}
func generate(output: String) -> void:
	var started:=Time.get_ticks_usec()
	heights.resize(SIZE*SIZE);colors.resize(SIZE*SIZE);solid_heights.resize(SIZE*SIZE)
	solid_colors.resize(SIZE*SIZE);terrain_colors.resize(SIZE*SIZE)
	var noise:=FastNoiseLite.new();noise.seed=1977;noise.frequency=.028;noise.fractal_octaves=4
	var height_image:=Image.create(SIZE,SIZE,false,Image.FORMAT_RF)
	var color_image:=Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	for z in SIZE:
		for x in SIZE:
			var wx:=float(x)/(SIZE-1)*EXTENT-EXTENT*.5
			var wz:=float(z)/(SIZE-1)*EXTENT-EXTENT*.5
			var flatten:=clampf(maxf(absf(wx)-70,absf(wz)-52)/24,0,1)
			var height:=lerpf(BASE,8+noise.get_noise_2d(wx,wz)*16,flatten)
			var color:=Color(.25,.32,.16).lerp(Color(.45,.39,.26),(noise.get_noise_2d(wx*4,wz*4)+1)*.4)
			if flatten<.01:
				color=Color(.32,.33,.31) if absf(wx)<64 and absf(wz)<48 else Color(.43,.38,.28)
				if absf(wx)<9 or wz>27 and wz<41:color=Color(.19,.20,.20)
				if wz>28 and wz<40 and absf(wx)<.18:color=Color(.82,.65,.23)
				if wz>23 and wz<27 and fmod(absf(wx),7)<.22:color=Color(.76,.70,.47)
			if wx>-20 and wx<48 and wz>18 and wz<43:color=color.darkened(.24)
			var i:=z*SIZE+x
			heights[i]=height;colors[i]=color;height_image.set_pixel(x,z,Color(height,0,0));color_image.set_pixel(x,z,color)
			terrain_colors[i]=packed_color(color,0)
			var roof:=height;var material:=0
			if wx>=-32 and wx<=28 and wz>=-30 and wz<=18:roof=BASE+16;material=1
			if wx>=28 and wx<=48 and wz>=-20 and wz<=18:roof=BASE+8;material=1
			if wx>=-52 and wx<=-32 and wz>=-14 and wz<=16:roof=BASE+8;material=1
			if wx>=-7 and wx<=9 and wz>=-8 and wz<=6:roof=BASE+21;material=2
			for sx in [-46.0,-37.0]:
				if Vector2(wx-sx,wz+24).length()<2.6:roof=BASE+30;material=2
			solid_heights[i]=roof;solid_colors[i]=packed_color(color,material)
	height_texture=preload("res://deathmatch/textures.gd").create(height_image);color_texture=preload("res://deathmatch/textures.gd").create(color_image)
	build_factory()
	metadata={"seed":1977,"extent_m":EXTENT,"height_samples":[SIZE,SIZE],"height_range_m":[Array(heights).min(),Array(heights).max()],"factory_storeys":4,"floor_y_m":[BASE,BASE+4,BASE+8,BASE+12],"roof_y_m":BASE+16,"factory_boxes":boxes.size(),"factory_triangles":factory_mesh.surface_get_array_index_len(0)/3,"generation_ms":(Time.get_ticks_usec()-started)/1000.0}
	DirAccess.make_dir_recursive_absolute(output)
	height_image.save_exr(output+"/factory-height.exr",true);color_image.save_png(output+"/factory-colormap.png")
	FileAccess.open(output+"/factory-map.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"  "))
static func packed_color(color: Color,kind: int) -> int:
	return color.r8|(color.g8<<8)|(color.b8<<16)|(kind<<24)
func box(center: Vector3,size: Vector3,color: Color) -> void:boxes.append([center,size,color])
func hall(x0: float,x1: float,z0: float,z1: float,floors: int) -> void:
	var brick:=Color(.56,.37,.25);var slab:=Color(.49,.51,.49)
	for floor_index in floors+1:
		var y:=BASE+floor_index*4
		# The main hall has a real stairwell, not a solid heightfield extrusion.
		if floors==4 and floor_index<4:
			box(Vector3((x0+x1-8)/2,y,(z0+z1)/2),Vector3(x1-x0-8,.26,z1-z0),slab)
			box(Vector3(x1-4,y,(z0+12+z1)/2),Vector3(8,.26,z1-z0-12),slab)
		else:box(Vector3((x0+x1)/2,y,(z0+z1)/2),Vector3(x1-x0,.26,z1-z0),slab)
	for level in floors:
		var y:=BASE+level*4
		for z in [z0,z1]:
			box(Vector3((x0+x1)/2,y+.5,z),Vector3(x1-x0,1,.4),brick)
			box(Vector3((x0+x1)/2,y+3.4,z),Vector3(x1-x0,1.2,.4),brick)
			for x in range(int(x0),int(x1)+1,5):box(Vector3(x,y+1.9,z),Vector3(.75,1.8,.45),brick.lightened(.08))
		for x in [x0,x1]:
			box(Vector3(x,y+.5,(z0+z1)/2),Vector3(.4,1,z1-z0),brick)
			box(Vector3(x,y+3.4,(z0+z1)/2),Vector3(.4,1.2,z1-z0),brick)
			for z in range(int(z0),int(z1)+1,5):box(Vector3(x,y+1.9,z),Vector3(.45,1.8,.75),brick.lightened(.08))
		if floors==4 and level<3:
			for step in 16:box(Vector3(x1-4,y+(step+1)*.25,z0+1+step*.65),Vector3(3,.25,.68),slab)
	for x in range(int(x0)+8,int(x1),12):
		for z in range(int(z0)+8,int(z1),12):box(Vector3(x,BASE+floors*2,z),Vector3(.55,floors*4,.55),Color(.24,.27,.25))
func build_factory() -> void:
	hall(-32,28,-30,18,4);hall(28,48,-20,18,2);hall(-52,-32,-14,16,2)
	box(Vector3(1,BASE+18.5,-1),Vector3(16,5,14),Color(.31,.36,.34))
	for x in [-46.0,-37.0]:
		box(Vector3(x,BASE+15,-24),Vector3(4.8,30,4.8),Color(.52,.34,.26))
		box(Vector3(x,BASE+30,-24),Vector3(5.4,.7,5.4),Color(.22,.24,.23))
	for x in [-24.0,-12.0,0.0,12.0]:box(Vector3(x,BASE+.65,21),Vector3(8,1.3,5),Color(.44,.46,.44))
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var shades:=PackedColorArray();var indices:=PackedInt32Array()
	var faces: Array=[[[0,1,1],[0,1,0],[0,0,0],[0,0,1],Vector3.LEFT],[[1,1,0],[1,1,1],[1,0,1],[1,0,0],Vector3.RIGHT],[[0,1,0],[0,1,1],[1,1,1],[1,1,0],Vector3.UP],[[0,0,1],[0,0,0],[1,0,0],[1,0,1],Vector3.DOWN],[[0,1,0],[1,1,0],[1,0,0],[0,0,0],Vector3.FORWARD],[[1,1,1],[0,1,1],[0,0,1],[1,0,1],Vector3.BACK]]
	for item in boxes:
		for face in faces:
			var start:=vertices.size();var normal: Vector3=face[4]
			var color: Color=item[2]*(.68+maxf(0,normal.dot(Vector3(-.4,.8,.3).normalized()))*.32);color.a=1
			for i in 4:vertices.append(item[0]+(Vector3(face[i][0],face[i][1],face[i][2])-Vector3.ONE*.5)*item[1]);normals.append(normal);shades.append(color)
			indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=shades;arrays[Mesh.ARRAY_INDEX]=indices
	factory_mesh=ArrayMesh.new();factory_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED;factory_mesh.surface_set_material(0,material)
func factory_node() -> MeshInstance3D:
	var result:=MeshInstance3D.new();result.mesh=factory_mesh;result.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;return result
func raster_terrain() -> MeshInstance3D:
	var vertices:=PackedVector3Array();var indices:=PackedInt32Array();vertices.resize(SIZE*SIZE)
	for z in SIZE:
		for x in SIZE:vertices[z*SIZE+x]=Vector3(float(x)/(SIZE-1)*EXTENT-EXTENT/2,heights[z*SIZE+x],float(z)/(SIZE-1)*EXTENT-EXTENT/2)
	for z in SIZE-1:
		for x in SIZE-1:
			var i:=z*SIZE+x;indices.append_array(PackedInt32Array([i,i+SIZE,i+1,i+1,i+SIZE,i+SIZE+1]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.vertex_color_use_as_albedo=true;material.vertex_color_is_srgb=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED;mesh.surface_set_material(0,material)
	var result:=MeshInstance3D.new();result.mesh=mesh;result.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;return result
