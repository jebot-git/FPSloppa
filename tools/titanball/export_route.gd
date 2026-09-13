extends SceneTree
const F=preload("res://tools/ba2/gameplay/fixture.gd")
func v(p: Vector3) -> Array:return [p.x,p.y,p.z]
func _initialize():
	var path=F.Route.curve(F.points());var samples: Array=[]
	for i in 301:
		var pose=F.Route.sample(path,float(i));samples.append({"distance":i,"position":v(pose.origin),"right":v(pose.basis.x),"forward":v(pose.basis.z)})
	var points: Array=[]
	for p in F.points():points.append(v(p))
	FileAccess.open("res://maps/Ashfall/route.json",FileAccess.WRITE).store_string(JSON.stringify({"points":points,"length":path.get_baked_length(),"samples":samples},"  "));quit()
