extends RefCounted
## Stable placeholder anatomy. Cosmetic gait/VRM proportions never alter damage.
const TORSO_SIZE=Vector3(.55,.58,.32)
const TORSO_CENTER=Vector3(0,.24,0)
const HEAD_SIZE=Vector3(.35,.34,.34)
const HEAD_CENTER=Vector3(0,.70,0)
const ARM_SIZE=Vector3(.22,.36,.30)
const FOREARM_SIZE=Vector3(.16,.23,.37)
const LEG_SIZE=Vector3(.21,1,.24)
const BOOT_SIZE=Vector3(.24,.18,.37)
static var cache: Dictionary={}

static func parts(height: float) -> Array:
	# One-centimetre stance resolution; bounded shared cache, no per-shot nodes.
	var key:=clampi(roundi(height*100),65,165)
	if cache.has(key):return cache[key]
	var prone:=key<80
	var pelvis:=Vector3(0,maxf(.30,.78-(1.65-key*.01)),0)
	if prone:pelvis=Vector3(0,.32,.30)
	var upper:=Transform3D(Basis(Vector3.RIGHT,-deg_to_rad(77) if prone else 0.0),pelvis)
	var result: Array=[{"pose":upper*Transform3D(Basis.IDENTITY,TORSO_CENTER),"size":TORSO_SIZE}]
	# Include the visor's front face in the head box.
	result.append({"pose":Transform3D(Basis.IDENTITY,upper*HEAD_CENTER+Vector3(0,0,-.0125)),"size":HEAD_SIZE+Vector3(0,0,.025)})
	for side in [-1.0,1.0]:
		result.append({"pose":upper*Transform3D(Basis.IDENTITY,Vector3(side*.38,.32,0)),"size":ARM_SIZE})
		result.append({"pose":upper*Transform3D(Basis.IDENTITY,Vector3(side*.38,.12,-.16)),"size":FOREARM_SIZE})
		var hip:=pelvis+Vector3(side*.18,0,0)
		var foot:=Vector3(side*(.28 if prone else .18),.10,1.15 if prone else 0.0)
		var axis: Vector3=(foot-hip).normalized()
		var distance:=clampf(hip.distance_to(foot),.02,.719)
		foot=hip+axis*distance
		var pole:=Vector3.DOWN if prone else Vector3.FORWARD
		var bend: Vector3=(pole-axis*pole.dot(axis)).normalized()
		if bend.length_squared()<.1:bend=Vector3.FORWARD
		var knee: Vector3=(hip+foot)*.5+bend*sqrt(maxf(0,.36*.36-distance*distance*.25))
		for segment in [[hip,knee],[knee,foot]]:
			var from: Vector3=segment[0];var to: Vector3=segment[1]
			result.append({"pose":Transform3D(Basis(Quaternion(Vector3.UP,(to-from).normalized())),(from+to)*.5),"size":LEG_SIZE*Vector3(1,from.distance_to(to),1)})
		result.append({"pose":Transform3D(Basis.IDENTITY,foot+Vector3(0,-.01,-.05)),"size":BOOT_SIZE})
	cache[key]=result
	return result
