extends SceneTree
const Route=preload("res://deathmatch/vehicles/ba2/route.gd")
func _initialize():
	var checks: Array=[]
	# Uphill and downhill paths both meet level bases without vertical overshoot.
	for direction in [-1.,1.]:
		var points: Array=[Vector3.ZERO,Vector3(0,0,12),Vector3(0,direction,36),Vector3(0,direction*2,60),Vector3(0,direction*2,72)]
		var path:=Route.curve(points);var valid:=true;var last:=0.0
		for i in 1441:
			var y: float=Route.sample(path,path.get_baked_length()*i/1440).origin.y*direction
			valid=valid and y>=last-.001 and y>=-.001 and y<=2.001;last=y
		checks.append({"name":"Monotone grade with flat bases, direction "+str(direction),"passed":valid})
	# The existing flat Ashfall route keeps exactly the previous curve geometry.
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://maps/Ashfall/route.json"))
	var points: Array=[]
	for row in data.points:points.append(Vector3(row[0],row[1],row[2]))
	var current:=Route.curve(points);var legacy:=Curve3D.new();legacy.bake_interval=.25
	for i in points.size():
		var p: Vector3=points[i];var before: Vector3=points[maxi(0,i-1)];var after: Vector3=points[mini(points.size()-1,i+1)]
		var tangent: Vector3=(after-before).normalized()*minf(p.distance_to(before),p.distance_to(after))*.3
		legacy.add_point(p,-tangent,tangent)
	var unchanged:=current.get_baked_length()==legacy.get_baked_length()
	for i in 701:unchanged=unchanged and Route.sample(current,i*.5)==Route.sample(legacy,i*.5)
	checks.append({"name":"Existing Ashfall route samples and length are unchanged","passed":unchanged})
	FileAccess.open("res://test-results/cindercoil/route-tests.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	for result in checks:print("PASS " if result.passed else "FAIL ",result.name)
	quit(0 if checks.all(func(c):return c.passed) else 1)
