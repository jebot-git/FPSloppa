extends RefCounted
## Enemy observers see only a faded portion inside their three-metre sphere.
static func clipped(start:Vector3,end:Vector3,eye:Vector3,radius:float=3.0) -> PackedVector3Array:
	var d:=end-start;var a:=d.length_squared()
	if a<.000001:return PackedVector3Array()
	var offset:=start-eye;var b:=2*offset.dot(d);var c:=offset.length_squared()-radius*radius
	var disc:=b*b-4*a*c
	if disc<0:return PackedVector3Array()
	var root:=sqrt(disc);var lo:=maxf(0,(-b-root)/(2*a));var hi:=minf(1,(-b+root)/(2*a))
	return PackedVector3Array([start+d*lo,start+d*hi]) if hi>lo else PackedVector3Array()
