extends RefCounted
## Point contents from the world BSP tree; independent of optional brush extensions.
var planes: Array[Plane]=[]
var nodes: Array[Vector3i]=[]
var leaves:=PackedInt32Array()
var head:=0
func open(path: String) -> bool:
	planes.clear();nodes.clear();leaves.clear()
	var data:=FileAccess.get_file_as_bytes(path)
	if data.size()<124 or data.size()>25_000_000:return false
	var version:=data.decode_u32(0)
	if not version in [29,0x32505342,0x42535032]:return false
	var lumps: Array[Vector2i]=[]
	for i in 15:
		var offset:=data.decode_u32(4+i*8);var length:=data.decode_u32(8+i*8)
		if offset+length>data.size():return false
		lumps.append(Vector2i(offset,length))
	var node_size:=24 if version==29 else 44 if version==0x32505342 else 32
	var leaf_size:=28 if version==29 else 44 if version==0x32505342 else 32
	if lumps[1].y%20 or lumps[5].y%node_size or lumps[10].y%leaf_size or lumps[14].y<64:return false
	for at in range(lumps[1].x,lumps[1].x+lumps[1].y,20):
		var normal:=Vector3(-data.decode_float(at+4),data.decode_float(at+8),-data.decode_float(at))
		var distance:=data.decode_float(at+12)/32.0
		if not normal.is_finite() or not is_finite(distance):return false
		planes.append(Plane(normal,distance))
	for at in range(lumps[5].x,lumps[5].x+lumps[5].y,node_size):
		var a:=data.decode_s16(at+4) if version==29 else data.decode_s32(at+4)
		var b:=data.decode_s16(at+6) if version==29 else data.decode_s32(at+8)
		nodes.append(Vector3i(data.decode_s32(at),a,b))
	for at in range(lumps[10].x,lumps[10].x+lumps[10].y,leaf_size):leaves.append(data.decode_s32(at))
	head=data.decode_s32(lumps[14].x+36)
	for n in nodes:
		if n.x<0 or n.x>=planes.size():return false
		for child in [n.y,n.z]:
			if child>=nodes.size() or child<0 and -child-1>=leaves.size():return false
	return not nodes.is_empty() and head>=0 and head<nodes.size()
func at(point: Vector3) -> int:
	if nodes.is_empty() or not point.is_finite():return -1
	var index:=head
	# Bound corrupt/cyclic input even when a custom map has passed basic validation.
	for depth in 512:
		if index<0:return leaves[-index-1] if -index-1<leaves.size() else -1
		if index>=nodes.size():return -1
		var n:=nodes[index]
		index=n.y if planes[n.x].distance_to(point)>=0 else n.z
	return -1
static func liquid(value: int) -> bool:return value in [-3,-4,-5] or value<=-9 and value>=-14
