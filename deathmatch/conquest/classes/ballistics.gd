extends RefCounted
## Shared ballistic aiming. Solves the real launch velocity, including inheritance.
static func solve(start: Vector3,target: Vector3,speed: float,gravity: float,inherited:=Vector3.ZERO,high: bool=false) -> Dictionary:
	if speed<=0 or gravity<=0 or not start.is_finite() or not target.is_finite():return {}
	var previous:=.025;var previous_error:=error_at(start,target,speed,gravity,inherited,previous)
	var solutions: Array=[]
	for i in range(1,401):
		var time:=i*.025;var error:=error_at(start,target,speed,gravity,inherited,time)
		if error*previous_error<=0:
			var low:=previous;var upper:=time
			for iteration in 18:
				var middle:=(low+upper)*.5
				if error_at(start,target,speed,gravity,inherited,low)*error_at(start,target,speed,gravity,inherited,middle)<=0:upper=middle
				else:low=middle
			var flight:=(low+upper)*.5
			var velocity:=(target-start)/flight+Vector3.UP*gravity*flight*.5
			solutions.append({"direction":(velocity-inherited).normalized(),"velocity":velocity,"time":flight})
		previous=time;previous_error=error
	if solutions.is_empty():return {}
	return solutions[-1] if high else solutions[0]
static func error_at(start: Vector3,target: Vector3,speed: float,gravity: float,inherited: Vector3,time: float) -> float:
	return ((target-start)/time+Vector3.UP*gravity*time*.5-inherited).length_squared()-speed*speed
static func clear(space,start: Vector3,solution: Dictionary,gravity: float,margin: float=.15) -> bool:
	if solution.is_empty():return false
	var previous:=start;var count:=maxi(4,ceili(solution.time/.06))
	for i in range(1,count+1):
		var t: float=solution.time*i/count;var point: Vector3=start+solution.velocity*t-Vector3.UP*gravity*t*t*.5
		var side: Vector3=(point-previous).normalized().cross(Vector3.UP)*margin
		for offset in [Vector3.ZERO,side,-side]:
			var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(previous+offset,point+offset,1))
			if not hit.is_empty() and hit.position.distance_to(start+solution.velocity*solution.time-Vector3.UP*gravity*solution.time*solution.time*.5)>1.5:return false
		previous=point
	return true
