extends RefCounted
## Shared canonical sparse octrees. Instances stream with terrain tiles; empty
## octree leaves skip whole cells during ray traversal rather than fixed steps.
const WIDTH:=1024
var nodes:=PackedVector4Array()
var dense:=PackedByteArray()
var resolution:=32
var occupied:=0
static func crowns(kind: int) -> Array:
	if kind==0:return [Vector4(0,13,0,5.7),Vector4(-3,15,0,4.2),Vector4(3,15,-1,4.4),Vector4(0,18,1,3.2)]
	return [Vector4(0,17.5,0,1.4),Vector4(-3.5,17,0,3.5),Vector4(3.5,17,0,3.5),Vector4(0,17,-3.5,3.5),Vector4(0,17,3.5,3.5)]
static func sample(p: Vector3,kind: int,voxel_width: float=0.0) -> int:
	if Vector2(p.x,p.z).length()<maxf(.43 if kind==0 else .32,voxel_width*.72) and p.y<17:return 1
	for c in crowns(kind):
		var q:=p-Vector3(c.x,c.y,c.z)
		q.y/=(.65 if kind==0 else .16)
		if q.length()<c.w:return 2+int(c.x>0)
	return 0
func index(x: int,y: int,z: int) -> int:return (z*resolution+y)*resolution+x
func encode(at: int,origin: Vector3i,side: int) -> void:
	var first:=dense[index(origin.x,origin.y,origin.z)]
	var uniform:=true
	for z in range(origin.z,origin.z+side):
		for y in range(origin.y,origin.y+side):
			for x in range(origin.x,origin.x+side):
				if dense[index(x,y,z)]!=first:uniform=false;break
			if not uniform:break
		if not uniform:break
	if uniform:nodes[at]=Vector4(0,first,0,1 if first>0 else 0);return
	var base:=nodes.size();nodes.resize(base+8);nodes[at]=Vector4(base,0,0,2)
	var half:=side/2
	for child in 8:encode(base+child,origin+Vector3i(child&1,(child>>1)&1,(child>>2)&1)*half,half)
func build(kind: int,lod: int) -> Dictionary:
	resolution=[32,16,8][lod];dense.resize(resolution*resolution*resolution)
	for z in resolution:
		for y in resolution:
			for x in resolution:
				var p: Vector3=Vector3(-7,0,-7)+(Vector3(x,y,z)+Vector3.ONE*.5)*Vector3(14,20,14)/resolution
				var value:=sample(p,kind,14.0/resolution);dense[index(x,y,z)]=value
				if value>0:occupied+=1
	nodes.resize(1);encode(0,Vector3i.ZERO,resolution)
	var pixels:=PackedFloat32Array();pixels.resize(WIDTH*ceili(float(nodes.size())/WIDTH)*4)
	for i in nodes.size():
		pixels[i*4]=nodes[i].x;pixels[i*4+1]=nodes[i].y;pixels[i*4+3]=nodes[i].w
	var image:=Image.create_from_data(WIDTH,pixels.size()/(WIDTH*4),false,Image.FORMAT_RGBAF,pixels.to_byte_array())
	return {"image":image,"nodes":nodes.size(),"bytes":pixels.size()*4,"resolution":resolution,"occupied":occupied}
