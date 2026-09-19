extends SceneTree
const Route=preload("res://deathmatch/vehicles/ba2/route.gd")
const LENGTH=350.0
func v(p: Vector3) -> Array:return [p.x,p.y,p.z]
func _initialize():
	# Two stronger S-bends centre on the checkpoints. Only the middle leg is
	# lengthened: 80 m approach, 150 m between checkpoints, 120 m final approach.
	var authored: Array=[Vector3.ZERO];var position:=Vector3.ZERO
	for step in 3500:
		var distance: float=(step+.5)*.1
		var yaw:=deg_to_rad(72)*(exp(-pow((distance-80)/22.,2))-exp(-pow((distance-230)/22.,2)))
		yaw+=deg_to_rad(30)*exp(-pow((distance-310)/28.,2))
		if distance<25:yaw=0.0 # Keep the original hangar and straight gate approach.
		position+=Vector3(sin(yaw),0,cos(yaw))*.1
		if (step+1)%100==0:authored.append(position)
	var path=Route.curve(authored)
	for i in authored.size():authored[i]*=LENGTH/path.get_baked_length()
	path=Route.curve(authored);var samples: Array=[]
	for i in int(LENGTH)+1:
		var pose=Route.sample(path,float(i));samples.append({"distance":i,"position":v(pose.origin),"right":v(pose.basis.x),"forward":v(pose.basis.z)})
	var points: Array=[]
	for p in authored:points.append(v(p))
	FileAccess.open("res://maps/Ashfall/route.json",FileAccess.WRITE).store_string(JSON.stringify({"points":points,"length":path.get_baked_length(),"checkpoints":[80,230],"samples":samples},"  "));quit()
