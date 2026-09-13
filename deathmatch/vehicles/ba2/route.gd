extends RefCounted
## Shared, authored route geometry. No pathfinding or client movement authority.
static func curve(points: Array,loop: bool=false) -> Curve3D:
	var result:=Curve3D.new();result.bake_interval=.25
	if points.size()<2:return result
	for i in points.size():
		var p: Vector3=points[i]
		var before: Vector3=points[posmod(i-1,points.size())] if loop or i>0 else p
		var after: Vector3=points[(i+1)%points.size()] if loop or i<points.size()-1 else p
		var tangent: Vector3=(after-before).normalized()*minf(p.distance_to(before),p.distance_to(after))*.3
		result.add_point(p,-tangent,tangent)
	if loop:result.add_point(points[0],result.get_point_in(0),result.get_point_out(0))
	return result
static func sample(path: Curve3D,distance: float,loop: bool=false) -> Transform3D:
	var length:=path.get_baked_length()
	var at:=fposmod(distance,length) if loop and length>0 else clampf(distance,0,length)
	var pos:=path.sample_baked(at,true)
	var before:=path.sample_baked(maxf(0,at-.1),true)
	var after:=path.sample_baked(minf(length,at+.1),true)
	var forward: Vector3=(after-before).normalized()
	var yaw:=atan2(forward.x,forward.z)
	return Transform3D(Basis(Vector3.UP,yaw),pos)
