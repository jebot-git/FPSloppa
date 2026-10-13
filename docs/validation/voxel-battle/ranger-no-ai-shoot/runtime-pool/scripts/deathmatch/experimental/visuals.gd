extends Node3D
## Independently recreated, profile-specific FX. Cosmetic only; no collision/network state.
const TracerGeometry=preload("res://deathmatch/experimental/tracer_geometry.gd")
const Art=preload("res://deathmatch/art.gd")
const Emission=preload("res://deathmatch/lighting/weapon_emission.gd")
signal illumination(a: Vector3,b: Vector3,recipe: Dictionary,key: int)
const MAX_PARTICLES:=512
const MAX_SHAPES:=64
var particles: Array=[]
var shapes: Array=[]
var free_shapes: Array=[]
var ring_mesh: TorusMesh
var globe_mesh: SphereMesh
var straight_mesh: ImmediateMesh
var pool_stats: Dictionary={"activations":0,"straight_tracers":0,"curved_tracers":0,"evictions":0,"peak_active":0}
var batches: Array=[]
var emission_budget:=64
func _ready() -> void:
	prepare_shape_pool()
	for smoke in [false,true]:
		var draw:=MultiMeshInstance3D.new();var mm:=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
		var geometry: Mesh
		if smoke:
			var sphere:=SphereMesh.new();sphere.radius=.5;sphere.height=1;sphere.radial_segments=8;sphere.rings=4;geometry=sphere
		else:
			var cube:=BoxMesh.new();cube.size=Vector3.ONE;geometry=cube
		mm.mesh=geometry;mm.instance_count=MAX_PARTICLES;mm.visible_instance_count=0;draw.multimesh=mm
		var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.vertex_color_use_as_albedo=true;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		draw.material_override=m;draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(draw);batches.append(mm)
func particle(pos: Vector3,velocity: Vector3,color: Color,size: float,life: float,smoke: bool=false) -> void:
	if particles.size()>=MAX_PARTICLES or emission_budget<=0:return
	emission_budget-=1
	particles.append({"pos":pos,"velocity":velocity,"color":color,"size":size,"life":life,"total":life,"smoke":smoke})
func _process(delta: float) -> void:
	emission_budget=64
	var counts:=[0,0]
	for i in range(particles.size()-1,-1,-1):
		var p: Dictionary=particles[i];p.life-=delta
		if p.life<=0:particles.remove_at(i);continue
		p.pos+=p.velocity*delta;p.velocity+=Vector3.UP*(.35 if p.smoke else -4.0)*delta
		var t: float=p.life/p.total;var size: float=p.size*(1+(1-t)*2 if p.smoke else .4+t*.6)
		var slot:=1 if p.smoke else 0;var color: Color=p.color;color.a*=t
		batches[slot].set_instance_transform(counts[slot],Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),p.pos))
		batches[slot].set_instance_color(counts[slot],color);counts[slot]+=1
	for i in 2:batches[i].visible_instance_count=counts[i]
	for i in range(shapes.size()-1,-1,-1):
		var item: Dictionary=shapes[i];item.life-=delta
		if item.life<=0:
			item.node.hide();free_shapes.append(item);shapes.remove_at(i);continue
		var fraction: float=1-item.life/item.total
		item.node.basis=item.base_basis.scaled(Vector3.ONE*lerpf(item.start,item.end,fraction))
		item.mat.albedo_color.a=(1-fraction)*item.alpha

func material(color: Color) -> StandardMaterial3D:
	var m:=Art.material(color,0,0);m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.cull_mode=BaseMaterial3D.CULL_DISABLED
	return m
func prepare_shape_pool() -> void:
	if straight_mesh!=null:return
	straight_mesh=TracerGeometry.unit_mesh()
	ring_mesh=TorusMesh.new();ring_mesh.inner_radius=.45;ring_mesh.outer_radius=.5;ring_mesh.rings=24;ring_mesh.ring_segments=6
	globe_mesh=SphereMesh.new();globe_mesh.radius=.5;globe_mesh.height=1;globe_mesh.radial_segments=12;globe_mesh.rings=6
	for i in MAX_SHAPES:
		var node:=MeshInstance3D.new();var mat:=material(Color.WHITE)
		node.mesh=straight_mesh;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		node.hide();add_child(node)
		free_shapes.append({"node":node,"mat":mat,"trace":ImmediateMesh.new(),"slot":i})
func shape(mesh: Mesh,pos: Vector3,color: Color,life: float,start: float=1,end: float=1) -> MeshInstance3D:
	return _activate_shape(_acquire_shape(),mesh,pos,color,life,start,end)
func _acquire_shape() -> Dictionary:
	prepare_shape_pool()
	if not free_shapes.is_empty():return free_shapes.pop_back()
	pool_stats.evictions+=1
	return shapes.pop_front() # One FIFO capacity shared by every shape type.
func _activate_shape(item: Dictionary,mesh: Mesh,pos: Vector3,color: Color,life: float,start: float,end: float,base_basis: Basis=Basis.IDENTITY) -> MeshInstance3D:
	var node: MeshInstance3D=item.node
	if node.mesh!=mesh:node.mesh=mesh
	node.transform=Transform3D(base_basis.scaled(Vector3.ONE*start),pos)
	item.mat.albedo_color=color
	item.merge({"life":maxf(life,.0001),"total":maxf(life,.0001),"start":start,"end":end,"alpha":color.a,"base_basis":base_basis},true)
	node.show();shapes.append(item)
	pool_stats.activations+=1;pool_stats.peak_active=maxi(pool_stats.peak_active,shapes.size())
	return node
func clear() -> void:
	for item in shapes:item.node.hide();free_shapes.append(item)
	shapes.clear();particles.clear();emission_budget=64
	for batch in batches:batch.visible_instance_count=0
func reset_pool_stats() -> void:
	pool_stats={"activations":0,"straight_tracers":0,"curved_tracers":0,"evictions":0,"peak_active":shapes.size()}
func shape_pool_report() -> Dictionary:
	var slots: Dictionary={}
	for item in shapes+free_shapes:slots[item.slot]=true
	var report:=pool_stats.duplicate()
	report.merge({"capacity":MAX_SHAPES,"active":shapes.size(),"free":free_shapes.size(),"allocated_nodes":shapes.size()+free_shapes.size(),"invariants_ok":slots.size()==MAX_SHAPES and shapes.size()+free_shapes.size()==MAX_SHAPES},true)
	return report
func ring(pos: Vector3,color: Color,radius: float,life: float) -> void:
	prepare_shape_pool();shape(ring_mesh,pos,color,life,.2,radius*2)
func globe(pos: Vector3,color: Color,radius: float,life: float) -> void:
	prepare_shape_pool();shape(globe_mesh,pos,color,life,.12,radius*2)
func streak(points: PackedVector3Array,color: Color,width: float,life: float) -> void:
	if points.size()<2 or width<=0:return
	if points.size()==2:
		if points[0].distance_squared_to(points[1])<.000000000001:return
		var transform:=TracerGeometry.transform(points[0],points[1],width)
		var item:=_acquire_shape()
		_activate_shape(item,straight_mesh,transform.origin,color,life,1,1,transform.basis)
		pool_stats.straight_tracers+=1
		return
	# Curved beams retain their geometry, using a reusable per-slot mesh.
	var item:=_acquire_shape();var mesh: ImmediateMesh=item.trace
	mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,points.size()):
		var a:=points[i-1];var b:=points[i];var forward:=(b-a).normalized()
		var side:=forward.cross(Vector3.UP if absf(forward.y)<.9 else Vector3.RIGHT).normalized()*width
		for axis in [side,forward.cross(side)]:
			for v in [a-axis,b-axis,b+axis,a-axis,b+axis,a+axis]:mesh.surface_add_vertex(v)
	mesh.surface_end();_activate_shape(item,mesh,Vector3.ZERO,color,life,1,1)
	pool_stats.curved_tracers+=1

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
			illumination.emit(start,end,recipe,0)
		else:
			# Bullet pellets do not become room-length area lights. One shared
			# muzzle key coalesces shotgun pellets and rapid-fire bursts.
			illumination.emit(start,start,Emission.recipe("muzzle"),hash(start))
		for i in 2:particle(end-direction*.02,Vector3(randf_range(-1,1),randf_range(.2,1.5),randf_range(-1,1)),recipe.color,.025,.18)
func projectile(rules: String,definition: Dictionary) -> Node3D:
	var root:=Node3D.new();var kind: String=definition.kind;var visual_kind:=Emission.kind(rules,-1,definition)
	root.set_meta("kind",kind);root.set_meta("emission",Emission.projectile_recipe(visual_kind,definition));root.set_meta("visual_kind",visual_kind);root.set_meta("trail_time",0.0)
	var color:=Color("776f58") if rules=="quake" else Color("b7a077")
	match kind:
		"nail":
			Art.barrel(root,Vector3.ZERO,.020,.26,material(Emission.recipe(visual_kind).color))
		"rocket","warhead":
			Art.barrel(root,Vector3.ZERO,.075 if kind=="rocket" else .18,.36 if kind=="rocket" else .7,Art.material(color,.7))
			Art.barrel(root,Vector3(0,0,.20),.046,.07,material(Color("ffb64b")))
		"grenade","flak_shell":
			Art.barrel(root,Vector3.ZERO,.10,.19,Art.material(color,.7))
			Art.barrel(root,Vector3(0,0,-.1),.065,.04,material(Color("b69539")))
		"razor","razor_blast","translocator":
			var blade:=Art.barrel(root,Vector3.ZERO,.19,.024,Art.material(Color("a5b9bf"),.85));blade.rotation.x=0;blade.name="Spin"
			if kind=="translocator":Art.box(root,Vector3(0,.025,0),Vector3(.10,.02,.10),material(Color("85aaff")))
			for i in 8:
				var angle:=i*TAU/8;var tooth:=Art.box(blade,Vector3(cos(angle)*.17,0,sin(angle)*.17),Vector3(.06,.018,.05),material(Color("718e97")));tooth.rotation.y=-angle
		"flak":Art.box(root,Vector3.ZERO,Vector3(.055,.035,.11),material(Color("ffe08a")))
		_:
			var ball:=SphereMesh.new();ball.radius=float(definition.get("radius",.22 if kind=="shock_orb" else .14 if kind=="bio" else .09));ball.height=ball.radius*2;ball.radial_segments=12;ball.rings=6
			var node:=MeshInstance3D.new();node.mesh=ball
			node.material_override=material(Emission.recipe(visual_kind).get("color",Color("5eff64")));root.add_child(node)
			if kind=="pulse":node.scale=Vector3(.7,.7,2.2)
			if kind=="shock_orb":
				var halo:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.22;torus.outer_radius=.28;torus.rings=16;torus.ring_segments=6;halo.mesh=torus;halo.material_override=material(Color("dab4ff"));root.add_child(halo)
	return root
func travel(node: Node3D,velocity: Vector3,delta: float,stuck: bool) -> void:
	var kind: String=node.get_meta("kind","")
	var recipe: Dictionary=node.get_meta("emission",{})
	var pos:=node.global_position
	var previous: Vector3=node.get_meta("trail_position",pos)
	node.set_meta("trail_position",pos)
	if velocity.length_squared()>.01 and not stuck:node.basis=Basis.looking_at(velocity.normalized(),Vector3.RIGHT if absf(velocity.normalized().y)>.99 else Vector3.UP)
	var spin:=node.get_node_or_null("Spin")
	if spin:spin.rotate_y(delta*24)
	if stuck:
		if kind=="bio":node.scale=Vector3(1.6,.4,1.6)
		return # No persistent illumination from resting goo/discs.
	if recipe.is_empty():return
	var distance:=pos.distance_to(previous)
	# Never draw a long bridge across a correction, teleport, or first frame.
	var tail:=pos
	if delta<=.1 and distance>.001 and distance<=maxf(.5,velocity.length()*.15):
		tail=pos.move_toward(previous,minf(distance,recipe.length))
		var wall:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos,tail,1))
		if not wall.is_empty():tail=wall.position
	illumination.emit(tail,pos,recipe,node.get_instance_id())
	var age: float=node.get_meta("trail_time",0.0)+delta
	node.set_meta("trail_time",age)
	if age<.025:return
	node.set_meta("trail_time",0.0)
	if pos.distance_squared_to(tail)>.00001 and recipe.width>0:streak(PackedVector3Array([tail,pos]),recipe.color,recipe.width,recipe.life)
	if kind in ["rocket","warhead","grenade","flak_shell"]:
		particle(pos,Vector3.UP*.15,Color(.25,.23,.20,.45),.14 if kind=="rocket" else .10,.5,true)
		if kind in ["rocket","warhead"]:particle(pos,Vector3.ZERO,recipe.color,.065,.10)
	elif kind in ["shock_orb","pulse","plasma","bfg"]:particle(pos,Vector3.ZERO,recipe.color,.055,.12)
func burst(rules: String,pos: Vector3,weapon: int,kind: String="",definition: Dictionary={}) -> void:
	if rules=="doom" and kind.is_empty():kind=Emission.kind(rules,weapon)
	var light_kind: String="explosion" if kind in ["rocket","grenade","flak_shell","warhead","razor_blast"] else kind
	var light:=Emission.projectile_recipe(light_kind,definition)
	if kind=="bfg":light=light.duplicate();light.life=.32;light.radius=4.5
	illumination.emit(pos,pos,light,0)
	if rules=="doom" and kind in ["plasma","bfg"]:
		globe(pos,light.color,.4 if kind=="plasma" else 2.5,.18 if kind=="plasma" else .32)
		return
	var explosive: bool=weapon in [4,6] if rules=="quake" else kind in ["rocket","grenade","flak_shell","warhead","razor_blast"]
	if rules=="ut99" and kind.is_empty():explosive=weapon in [6,8]
	if rules=="ut99" and weapon==3:
		globe(pos,Color(.7,.32,1,.7),1.3,.24);ring(pos,Color(.8,.45,1,.8),1.6,.3)
	elif rules=="ut99" and weapon==1:
		for i in 16:particle(pos,Vector3(randf_range(-2,2),randf_range(.2,3),randf_range(-2,2)),Color("76cc23"),.09,.5)
	elif rules=="ut99" and weapon==7:
		globe(pos,Color(.3,1,.22,.75),.27,.18)
	elif explosive:
		var power:=4.0 if kind=="warhead" or (rules=="ut99" and weapon==8) else 1.0
		globe(pos,Color(1,.55,.12,.7),.85*power,.25)
		if rules=="ut99":ring(pos,Color(1,.78,.36,.7),3*power,.45)
		for i in 36:
			var v:=Vector3(randf_range(-1,1),randf_range(-.3,1.2),randf_range(-1,1)).normalized()*randf_range(1,6)*power
			particle(pos,v,[Color("ffdc72"),Color("f9922b"),Color("cf6022")][i%3],.07*power,randf_range(.3,.7))
		for i in 8:particle(pos,Vector3(randf_range(-1,1),randf_range(.5,2),randf_range(-1,1))*power,Color(.24,.22,.2,.6),.4*power,.85,true)
	else:
		for i in 5:particle(pos,Vector3(randf_range(-1,1),randf_range(.2,2),randf_range(-1,1)),Color("ffc774"),.035,.25)
func combo(pos: Vector3) -> void:
	illumination.emit(pos,pos,Emission.recipe("combo"),0)
	globe(pos,Color(.86,.65,1,.85),2.7,.32)
	for i in 3:
		ring(pos+Vector3.UP*(i-1)*.2,Color(.63,.22,1,.8),4.5-i*.4,.45+i*.07)
	for i in 28:particle(pos,Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1)).normalized()*7,Color("b772fa"),.07,.6)
