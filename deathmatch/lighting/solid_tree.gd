extends RefCounted
## Bounded BSP solid-space serialization for cosmetic weapon illumination.
const Contents=preload("res://deathmatch/maps/contents.gd")
var planes: Array[Plane]=[]
var children: Array[Vector2i]=[]
var head: int=-1
var texture: ImageTexture
var bytes:=0
var visits:=0
func prune_into(target,source_head: int,bounds: AABB,depth: int=0) -> int:
	if depth==0:visits=0
	visits+=1
	if source_head<0:return source_head
	if depth>=192 or visits>4096 or source_head>=planes.size():return -2
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
	material.set_shader_parameter("weapon_occlusion_tree",texture)
	material.set_shader_parameter("weapon_occlusion_nodes",planes.size())
	material.set_shader_parameter("weapon_occlusion_head",head)
	material.set_shader_parameter("weapon_occlusion_enabled",enabled)
	material.set_shader_parameter("weapon_occlusion_brush_count",brush_heads.size())
	var roots:=PackedInt32Array();roots.resize(4)
	var inverses: Array[Transform3D]=[Transform3D.IDENTITY,Transform3D.IDENTITY,Transform3D.IDENTITY,Transform3D.IDENTITY]
	for i in brush_heads.size():roots[i]=brush_heads[i];inverses[i]=transforms[i].affine_inverse()
	material.set_shader_parameter("weapon_occlusion_brush_heads",roots)
	material.set_shader_parameter("weapon_occlusion_brush_inverse",inverses)
