extends SceneTree
const Route=preload("res://deathmatch/vehicles/ba2/route.gd")
func points(radius: float) -> Array:
	var out: Array=[Vector3(0,0,-24),Vector3(0,0,-12)]
	for i in 49:
		var angle: float=float(i)/48*PI*1.5
		out.append(Vector3(radius*(1-cos(angle)),14.0*i/48,radius*sin(angle)))
	out.append(Vector3(radius-6,14,-radius));out.append(Vector3(radius-12,14,-radius))
	return out
func _initialize():
	var radius:=66.5
	for attempt in 8:
		var length: float=Route.curve(points(radius)).get_baked_length()
		radius+=(350-length)/(PI*1.5)
	var route:=Route.curve(points(radius));var nodes: Array=[];var samples: Array=[]
	for p in points(radius):nodes.append([p.x,p.y,p.z])
	for step in 1401:
		var d: float=step*.25;var pose:=Route.sample(route,d)
		samples.append({"distance":d,"position":[pose.origin.x,pose.origin.y,pose.origin.z],"right":[pose.basis.x.x,pose.basis.x.y,pose.basis.x.z],"forward":[pose.basis.z.x,pose.basis.z.y,pose.basis.z.z]})
	var data:={"radius":radius,"length":route.get_baked_length(),"rise":14,"points":nodes,"samples":samples}
	FileAccess.open("res://maps/Cindercoil/route.json",FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
	print("CINDERCOIL_ROUTE ",route.get_baked_length()," radius=",radius);quit()
