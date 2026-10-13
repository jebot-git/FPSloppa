extends RefCounted
## A two-point crossed ribbon uses one immutable mesh, transformed per shot.
static func unit_mesh() -> ImmediateMesh:
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in [Vector3.RIGHT,Vector3.UP]:
		for v in [-axis,Vector3(0,0,1)-axis,Vector3(0,0,1)+axis,-axis,Vector3(0,0,1)+axis,axis]:mesh.surface_add_vertex(v)
	mesh.surface_end()
	return mesh
static func transform(a: Vector3,b: Vector3,width: float) -> Transform3D:
	var forward:=(b-a).normalized()
	var side:=forward.cross(Vector3.UP if absf(forward.y)<.9 else Vector3.RIGHT).normalized()
	return Transform3D(Basis(side*width,forward.cross(side)*width,forward*a.distance_to(b)),a)
