extends RefCounted
## Offline-style mesh batching at factory time. One surface per finish, not per bolt.
var surfaces: Dictionary={}
var materials: Array=[]
func _init(palette: Array=[]):materials=palette
func triangle(a: Vector3,b: Vector3,c: Vector3,normal: Vector3,uv_a: Vector2,uv_b: Vector2,uv_c: Vector2,finish: int):
	if not surfaces.has(finish):
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);surfaces[finish]=tool
	var st: SurfaceTool=surfaces[finish]
	var vs: Array=[a,b,c];var uvs: Array=[uv_a,uv_b,uv_c]
	if (b-a).cross(c-a).dot(normal)>0:vs=[a,c,b];uvs=[uv_a,uv_c,uv_b]
	for i in 3:st.set_normal(normal);st.set_uv(uvs[i]);st.add_vertex(vs[i])
func quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,n: Vector3,finish: int):
	triangle(a,b,c,n,Vector2(0,0),Vector2(1,0),Vector2(1,1),finish)
	triangle(a,c,d,n,Vector2(0,0),Vector2(1,1),Vector2(0,1),finish)
func box(pos: Vector3,size: Vector3,finish: int=0,bevel: float=.008,basis: Basis=Basis.IDENTITY):
	# Octagonal cross-section with inset end rings: bevels on all twelve edges.
	var h:=size*.5;var cut:=minf(bevel,minf(h.x,minf(h.y,h.z))*.45)
	var outline: Array=[Vector2(-h.x+cut,-h.y),Vector2(h.x-cut,-h.y),Vector2(h.x,-h.y+cut),Vector2(h.x,h.y-cut),Vector2(h.x-cut,h.y),Vector2(-h.x+cut,h.y),Vector2(-h.x,h.y-cut),Vector2(-h.x,-h.y+cut)]
	for i in 8:
		var j: int=(i+1)%8;var a: Vector2=outline[i];var b: Vector2=outline[j]
		var n:=basis*Vector3(b.y-a.y,a.x-b.x,0).normalized()
		quad(pos+basis*Vector3(a.x,a.y,-h.z+cut),pos+basis*Vector3(b.x,b.y,-h.z+cut),pos+basis*Vector3(b.x,b.y,h.z-cut),pos+basis*Vector3(a.x,a.y,h.z-cut),n,finish)
		for side in [-1,1]:
			var c:=a*Vector2((h.x-cut)/h.x,(h.y-cut)/h.y);var d:=b*Vector2((h.x-cut)/h.x,(h.y-cut)/h.y)
			var va:=pos+basis*Vector3(a.x,a.y,side*(h.z-cut));var vb:=pos+basis*Vector3(b.x,b.y,side*(h.z-cut));var vc:=pos+basis*Vector3(d.x,d.y,side*h.z);var vd:=pos+basis*Vector3(c.x,c.y,side*h.z)
			quad(va,vb,vc,vd,(n+basis*Vector3(0,0,side)).normalized(),finish)
			triangle(pos+basis*Vector3(0,0,side*h.z),vd,vc,basis*Vector3(0,0,side),Vector2(.5,.5),c/Vector2(size.x,size.y)+Vector2(.5,.5),d/Vector2(size.x,size.y)+Vector2(.5,.5),finish)
func tube(pos: Vector3,radius: float,length: float,finish: int=1,bore: float=0.0,basis: Basis=Basis.IDENTITY,segments: int=12):
	for i in segments:
		var a:=Vector2.from_angle(i*TAU/segments);var b:=Vector2.from_angle((i+1)*TAU/segments)
		var front:=pos+basis*Vector3(0,0,-length*.5);var back:=pos+basis*Vector3(0,0,length*.5)
		var aa:=basis*Vector3(a.x,a.y,0);var bb:=basis*Vector3(b.x,b.y,0);var n: Vector3=(aa+bb).normalized()
		quad(front+aa*radius,front+bb*radius,back+bb*radius,back+aa*radius,n,finish)
		if bore>0:quad(front+aa*bore,front+bb*bore,back+bb*bore,back+aa*bore,-n,finish)
		quad(front+aa*radius,front+bb*radius,front+bb*bore,front+aa*bore,basis*Vector3.FORWARD,finish)
		quad(back+aa*radius,back+bb*radius,back+bb*bore,back+aa*bore,basis*Vector3.BACK,finish)
func cable(points: Array,radius: float=.008,finish: int=2):
	for i in range(points.size()-1):
		var a: Vector3=points[i];var b: Vector3=points[i+1];var delta:=b-a
		var up:=Vector3.UP if absf(delta.normalized().dot(Vector3.UP))<.95 else Vector3.RIGHT
		tube((a+b)*.5,radius,delta.length(),finish,0,Basis.looking_at(delta,up),8)
func mesh() -> ArrayMesh:
	var result:=ArrayMesh.new()
	for finish in surfaces:
		var tool: SurfaceTool=surfaces[finish];tool.set_material(materials[finish]);tool.index();tool.generate_tangents();tool.commit(result)
	return result
func node(parent: Node3D,label: String) -> MeshInstance3D:
	var result:=MeshInstance3D.new();result.name=label;result.mesh=mesh();parent.add_child(result);return result
