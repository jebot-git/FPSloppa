extends "res://deathmatch/experimental/visuals.gd"
const Trace=preload("res://tools/vrm_to_mdl/profile/trace.gd")
func impacts(rules: String,start: Vector3,ends: PackedVector3Array,weapon: int,definition: Dictionary={}) -> void:
	var kind:=Emission.kind(rules,weapon,definition)
	if kind=="melee" or kind=="hammer":return
	if rules=="ut99" and weapon==7:kind="pulse_beam"
	var recipe:=Emission.recipe(kind)
	if recipe.is_empty():recipe=Emission.recipe("hitscan")
	for end in ends:
		var distance:=start.distance_to(end)
		if distance<.01:continue
		var direction: Vector3=(end-start)/distance
		var tail: Vector3=start+direction*minf(distance,recipe.length)
		if kind in ["beam","pulse_beam"]:
			var points:=PackedVector3Array([start]);var steps:=clampi(int(distance*3),3,48)
			for i in range(1,steps):points.append(start.lerp(end,float(i)/steps)+Vector3(randf_range(-.045,.045),randf_range(-.045,.045),randf_range(-.045,.045)))
			points.append(end);streak(points,recipe.color,recipe.width,recipe.life)
		else:streak(PackedVector3Array([start,tail]),recipe.color,recipe.width,recipe.life)
		if kind in ["rail","shock_beam","beam","pulse_beam"]:
			streak(PackedVector3Array([start,end]),Color("e7f1ff"),.007,minf(recipe.life,.10))
			var light_stamp:=Trace.begin()
			illumination.emit(start,end,recipe,0)
			Trace.end("impact_illumination",light_stamp)
		else:
			# Bullet pellets do not become room-length area lights. One shared
			# muzzle key coalesces shotgun pellets and rapid-fire bursts.
			var light_stamp:=Trace.begin()
			illumination.emit(start,start,Emission.recipe("muzzle"),hash(start))
			Trace.end("impact_illumination",light_stamp)
		for i in 2:particle(end-direction*.02,Vector3(randf_range(-1,1),randf_range(.2,1.5),randf_range(-1,1)),recipe.color,.025,.18)
func streak(points: PackedVector3Array,color: Color,width: float,life: float) -> void:
	var mesh_stamp:=Trace.begin()
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,points.size()):
		var a:=points[i-1];var b:=points[i];var forward:=(b-a).normalized()
		var side:=forward.cross(Vector3.UP if absf(forward.y)<.9 else Vector3.RIGHT).normalized()*width
		for axis in [side,forward.cross(side)]:
			for v in [a-axis,b-axis,b+axis,a-axis,b+axis,a+axis]:mesh.surface_add_vertex(v)
	mesh.surface_end()
	Trace.end("tracer_mesh_build",mesh_stamp)
	shape(mesh,Vector3.ZERO,color,life)
func shape(mesh: Mesh,pos: Vector3,color: Color,life: float,start: float=1,end: float=1) -> MeshInstance3D:
	var shape_stamp:=Trace.begin()
	if shapes.size()>=MAX_SHAPES:
		shapes[0].node.queue_free();shapes.pop_front()
	var node:=MeshInstance3D.new();node.mesh=mesh;var m:=material(color);node.material_override=m
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);node.position=pos;node.scale=Vector3.ONE*start
	shapes.append({"node":node,"mat":m,"life":life,"total":life,"start":start,"end":end,"alpha":color.a})
	Trace.end("tracer_shape_setup",shape_stamp)
	return node
func material(color: Color) -> StandardMaterial3D:
	var stamp:=Trace.begin()
	var result:=super.material(color)
	Trace.end("tracer_material_create",stamp)
	return result
func particle(pos: Vector3,velocity: Vector3,color: Color,size: float,life: float,smoke: bool=false) -> void:
	var stamp:=Trace.begin()
	super.particle(pos,velocity,color,size,life,smoke)
	Trace.end("fx_particle_enqueue",stamp)
func _process(delta: float) -> void:
	var stamp:=Trace.begin()
	super._process(delta)
	Trace.end("fx_render_update",stamp)
