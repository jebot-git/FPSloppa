extends RefCounted
## Diagnostic serialization of validated BSP planes and solid leaves to RGBA32F.
const Contents=preload("res://deathmatch/maps/contents.gd")
var planes: Array[Plane]=[]
var children: Array[Vector2i]=[]
var head: int=-1
var texture: ImageTexture
var bytes:=0
var cell_heads:=PackedInt32Array()
var cell_counts: Array=[]
func solid_cells(node: int,path: Array,result: Array) -> void:
	if node==-1:return
	if node==-2:result.append(path);return
	if path.size()>=32:result.append([]);return # Fail dark for excessive complexity.
	var plane:=planes[node];var pair:=children[node]
	var front:=path.duplicate();front.append(Plane(-plane.normal,-plane.d))
	var back:=path.duplicate();back.append(plane)
	solid_cells(pair.x,front,result);solid_cells(pair.y,back,result)
func pack_cells(roots: PackedInt32Array,count: int) -> void:
	var texels: Array[Color]=[];cell_heads.resize(8);cell_counts.clear()
	for i in count:
		var cells: Array=[];solid_cells(roots[i],[],cells)
		cell_heads[i]=texels.size();cell_counts.append(cells.size())
		texels.append(Color(cells.size(),0,0,0))
		for cell in cells:
			texels.append(Color(cell.size(),0,0,0))
			for plane in cell:texels.append(Color(plane.normal.x,plane.normal.y,plane.normal.z,plane.d))
	var width:=256;var height:=maxi(1,ceili(texels.size()/float(width)))
	var pixels:=Image.create(width,height,false,Image.FORMAT_RGBAF)
	for i in texels.size():pixels.set_pixel(i%width,i/width,texels[i])
	if texture and texture.get_width()==width and texture.get_height()==height:texture.update(pixels)
	else:texture=ImageTexture.create_from_image(pixels)
	bytes=width*height*16
func prune_into(target,source_head: int,bounds: AABB,depth: int=0) -> int:
	if source_head<0:return source_head
	if depth>=192:return -2
	var plane:=planes[source_head]
	var center:=bounds.get_center();var extent:=bounds.size*.5
	var distance:=plane.distance_to(center)
	var radius:=plane.normal.abs().dot(extent)
	var pair:=children[source_head]
	if distance-radius>0.0001:return prune_into(target,pair.x,bounds,depth+1)
	if distance+radius< -0.0001:return prune_into(target,pair.y,bounds,depth+1)
	var front:=prune_into(target,pair.x,bounds,depth+1)
	var back:=prune_into(target,pair.y,bounds,depth+1)
	if front==back:return front
	var index: int=target.planes.size();target.planes.append(plane);target.children.append(Vector2i(front,back));return index
func open(path: String) -> bool:
	var bsp:=Contents.new()
	if not bsp.open(path):return false
	planes.clear()
	children.clear();head=bsp.head
	for node in bsp.nodes:
		planes.append(bsp.planes[node.x])
		var pair:=Vector2i(node.y,node.z)
		for side in 2:
			if pair[side]<0:pair[side]=-2 if bsp.leaves[-pair[side]-1] in [-2,-6] else -1
		children.append(pair)
	pack();return true
func box(bounds: AABB,outside: int=-1) -> int:
	var start:=planes.size()
	for axis in 3:
		var normal:=Vector3.ZERO;normal[axis]=1
		planes.append(Plane(normal,bounds.end[axis]));planes.append(Plane(-normal,-bounds.position[axis]))
	for i in 6:children.append(Vector2i(outside,start+i+1 if i<5 else -2))
	return start
func pack() -> void:
	var width:=256;var height:=maxi(1,ceili(planes.size()*2.0/width))
	var pixels:=Image.create(width,height,false,Image.FORMAT_RGBAF)
	for i in planes.size():
		var plane:=planes[i]
		pixels.set_pixel((i*2)%width,(i*2)/width,Color(plane.normal.x,plane.normal.y,plane.normal.z,plane.d))
		pixels.set_pixel((i*2+1)%width,(i*2+1)/width,Color(children[i].x,children[i].y,0,0))
	if texture and texture.get_width()==width and texture.get_height()==height:texture.update(pixels)
	else:texture=ImageTexture.create_from_image(pixels)
	bytes=width*height*16
func apply(material: ShaderMaterial,enabled: bool=true,brush_heads: PackedInt32Array=PackedInt32Array(),transforms: Array[Transform3D]=[]) -> void:
	material.set_shader_parameter("occlusion_tree",texture)
	material.set_shader_parameter("occlusion_nodes",planes.size())
	material.set_shader_parameter("occlusion_head",head)
	material.set_shader_parameter("occlusion_enabled",enabled)
	material.set_shader_parameter("occlusion_brush_count",brush_heads.size())
	var roots:=PackedInt32Array();roots.resize(4)
	var inverses: Array[Transform3D]=[Transform3D.IDENTITY,Transform3D.IDENTITY,Transform3D.IDENTITY,Transform3D.IDENTITY]
	for i in brush_heads.size():roots[i]=brush_heads[i];inverses[i]=transforms[i].affine_inverse()
	material.set_shader_parameter("occlusion_brush_heads",roots)
	material.set_shader_parameter("occlusion_brush_inverse",inverses)
