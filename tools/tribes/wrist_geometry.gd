extends RefCounted
## Authoring source for the Blender-finished wrist tablet. Godot metres, +Z screen front.
var _vertices:=PackedVector3Array()
var _normals:=PackedVector3Array()
var _colors:=PackedColorArray()

func build_housing(size: Vector2) -> ArrayMesh:
	var shell:=Color("353e43");var rubber:=Color("151e22");var bronze:=Color("867453");var back:=Color("283136")
	prism(size+Vector2(.028,.028),-.026,-.006,.009,shell)
	prism(size-Vector2(.034,.026),-.030,-.025,.008,back)
	ring(size+Vector2(.040,.040),size+Vector2(.014,.014),-.022,.003,.013,rubber)
	ring(size+Vector2(.029,.029),size+Vector2(.010,.010),-.003,.004,.010,bronze)
	ring(size+Vector2(.011,.011),size, -.002,.002,.003,rubber)
	# Recessed back vents, fasteners and small moulded edge grips.
	for i in 7:box(Vector3((i-3)*.011,0,-.0308),Vector3(.005,size.y*.37,.002),rubber)
	for side in [-1,1]:
		for row in [-1,1]:
			var at:=Vector3(side*(size.x*.5+.010),row*(size.y*.5+.010),.0046)
			prism(Vector2(.004,.004),at.z,at.z+.001,.0015,back,Vector2(at.x,at.y))
		for i in 3:box(Vector3(side*(size.x*.5+.020),(i-1)*.018,-.01),Vector3(.003,.011,.010),shell)
	# Two closed straps surround the forearm; brackets touch both cuff and case.
	for at in [-.040,.040]:
		cuff(at,rubber)
		for side in [-1,1]:box(Vector3(side*.032,at,-.033),Vector3(.012,.018,.025),shell)
		box(Vector3(.048,at,-.068),Vector3(.006,.023,.026),bronze)
	# Inlaid power indicator, aligned with the existing equipment's teal accents.
	box(Vector3(-size.x*.5+.014,-size.y*.5-.008,.004),Vector3(.017,.002,.001),Color("69b9b1"))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=_vertices;arrays[Mesh.ARRAY_NORMAL]=_normals;arrays[Mesh.ARRAY_COLOR]=_colors
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.metallic=.25;material.roughness=.67
	mesh.surface_set_material(0,material);_vertices.clear();_normals.clear();_colors.clear();return mesh

func triangle(a: Vector3,b: Vector3,c: Vector3,normal: Vector3,color: Color):
	# Godot front faces wind clockwise when viewed from their outward normal.
	var points: Array=[a,c,b] if (b-a).cross(c-a).dot(normal)>0 else [a,b,c]
	for point in points:_vertices.append(point);_normals.append(normal);_colors.append(color)
func quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,normal: Vector3,color: Color):
	triangle(a,b,c,normal,color);triangle(a,c,d,normal,color)
func outline(size: Vector2,corner: float,at:=Vector2.ZERO) -> Array[Vector2]:
	var x:=size.x*.5;var y:=size.y*.5;var r:=minf(corner,minf(x,y));var result: Array[Vector2]=[]
	if corner<=0:
		for p in [Vector2(-x,-y),Vector2(x,-y),Vector2(x,y),Vector2(-x,y)]:result.append(p+at)
		return result
	for p in [Vector2(-x,-y+r),Vector2(-x+r,-y),Vector2(x-r,-y),Vector2(x,-y+r),Vector2(x,y-r),Vector2(x-r,y),Vector2(-x+r,y),Vector2(-x,y-r)]:result.append(p+at)
	return result
func point(p: Vector2,z: float) -> Vector3:return Vector3(p.x,p.y,z)
func prism(size: Vector2,rear: float,front: float,corner: float,color: Color,at:=Vector2.ZERO):
	var loop:=outline(size,corner,at)
	for i in loop.size():
		var a:=loop[i];var b:=loop[(i+1)%loop.size()];var normal:=Vector3(b.y-a.y,a.x-b.x,0).normalized()
		triangle(point(at,front),point(a,front),point(b,front),Vector3.BACK,color)
		triangle(point(at,rear),point(a,rear),point(b,rear),Vector3.FORWARD,color)
		quad(point(a,rear),point(b,rear),point(b,front),point(a,front),normal,color)
func ring(outer: Vector2,inner: Vector2,rear: float,front: float,corner: float,color: Color):
	var outside:=outline(outer,corner);var inside:=outline(inner,.001)
	for i in 8:
		var j: int=(i+1)%8;var a:=outside[i];var b:=outside[j];var c:=inside[j];var d:=inside[i]
		quad(point(a,front),point(b,front),point(c,front),point(d,front),Vector3.BACK,color)
		quad(point(a,rear),point(b,rear),point(c,rear),point(d,rear),Vector3.FORWARD,color)
		quad(point(a,rear),point(b,rear),point(b,front),point(a,front),Vector3(b.y-a.y,a.x-b.x,0).normalized(),color)
		quad(point(d,rear),point(c,rear),point(c,front),point(d,front),Vector3(d.y-c.y,c.x-d.x,0).normalized(),color)
func box(at: Vector3,size: Vector3,color: Color):
	prism(Vector2(size.x,size.y),at.z-size.z*.5,at.z+size.z*.5,0,color,Vector2(at.x,at.y))
func cuff(at: float,color: Color):
	var n:=24
	for i in n:
		var a:=Vector2(cos(i*TAU/n),sin(i*TAU/n));var b:=Vector2(cos((i+1)*TAU/n),sin((i+1)*TAU/n))
		var outside: Array[Vector3]=[];var inside: Array[Vector3]=[]
		for p in [a,b]:
			for y in [-.009,.009]:
				outside.append(Vector3(p.x*.050,at+y,p.y*.042-.068));inside.append(Vector3(p.x*.046,at+y,p.y*.038-.068))
		var normal:=Vector3((a.x+b.x)/.050,0,(a.y+b.y)/.042).normalized()
		quad(outside[0],outside[2],outside[3],outside[1],normal,color)
		quad(inside[0],inside[2],inside[3],inside[1],-normal,color)
		quad(outside[0],outside[2],inside[2],inside[0],Vector3.DOWN,color)
		quad(outside[1],outside[3],inside[3],inside[1],Vector3.UP,color)
