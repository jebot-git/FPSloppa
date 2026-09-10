extends SceneTree
const Hits=preload("res://deathmatch/hit_detection.gd")
const Reference=preload("res://deathmatch/tests/capsule_reference.gd")
func _initialize():
	var rng:=RandomNumberGenerator.new();rng.seed=740103
	var failures:=0;var hits:=0
	for i in 40000:
		var radius:float=[.4,.45,.56,.65,.75][i%5]
		var start:=Vector3(rng.randf_range(-20,20),rng.randf_range(-8,8),rng.randf_range(-20,20))
		var end:=Vector3(rng.randf_range(-20,20),rng.randf_range(-8,8),rng.randf_range(-20,20))
		if i%3==0:end=Vector3(rng.randf_range(-.3,.3),rng.randf_range(.4,1.4),rng.randf_range(-.3,.3))
		if i%7==0:start=Vector3(radius+float(i%3-1)*.00001,.9,10);end=Vector3(start.x,.9,-10)
		if i%11==0:end=start
		var expected:float=Reference.capsule_fraction(start,end,radius)
		var actual:float=Hits.capsule_fraction(start,end,radius)
		if is_finite(expected):hits+=1
		if is_finite(actual)!=is_finite(expected) or (is_finite(expected) and absf(actual-expected)>.000001):
			failures+=1
			if failures<5:print("MISMATCH ",start," ",end," ",radius," ",expected," ",actual)
	print("CAPSULE_EQUIVALENCE_RESULT ",JSON.stringify({"cases":40000,"hits":hits,"failures":failures}))
	quit(0 if failures==0 else 1)
