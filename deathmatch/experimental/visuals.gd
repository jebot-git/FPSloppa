extends Node3D
## Independently recreated, profile-specific FX. Cosmetic only; no collision/network state.
const Art=preload("res://deathmatch/art.gd")
const MAX_PARTICLES:=512
const MAX_SHAPES:=64
var particles: Array=[]
var shapes: Array=[]
var batches: Array=[]
var emission_budget:=64
func _ready() -> void:
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
		if item.life<=0:item.node.queue_free();shapes.remove_at(i);continue
		var fraction: float=1-item.life/item.total
		item.node.scale=Vector3.ONE*lerpf(item.start,item.end,fraction)
		item.mat.albedo_color.a=(1-fraction)*item.alpha
func material(color: Color) -> StandardMaterial3D:
	var m:=Art.material(color,0,0);m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.cull_mode=BaseMaterial3D.CULL_DISABLED
	return m
func shape(mesh: Mesh,pos: Vector3,color: Color,life: float,start: float=1,end: float=1) -> MeshInstance3D:
	if shapes.size()>=MAX_SHAPES:
		shapes[0].node.queue_free();shapes.pop_front()
	var node:=MeshInstance3D.new();node.mesh=mesh;var m:=material(color);node.material_override=m
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);node.position=pos;node.scale=Vector3.ONE*start
	shapes.append({"node":node,"mat":m,"life":life,"total":life,"start":start,"end":end,"alpha":color.a});return node
func ring(pos: Vector3,color: Color,radius: float,life: float) -> void:
	var torus:=TorusMesh.new();torus.inner_radius=.45;torus.outer_radius=.5;torus.rings=24;torus.ring_segments=6
	shape(torus,pos,color,life,.2,radius*2)
func globe(pos: Vector3,color: Color,radius: float,life: float) -> void:
	var ball:=SphereMesh.new();ball.radius=.5;ball.height=1;ball.radial_segments=12;ball.rings=6
	shape(ball,pos,color,life,.12,radius*2)
func streak(points: PackedVector3Array,color: Color,width: float,life: float) -> void:
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,points.size()):
		var a:=points[i-1];var b:=points[i];var forward:=(b-a).normalized()
		var side:=forward.cross(Vector3.UP if absf(forward.y)<.9 else Vector3.RIGHT).normalized()*width
		for axis in [side,forward.cross(side)]:
			for v in [a-axis,b-axis,b+axis,a-axis,b+axis,a+axis]:mesh.surface_add_vertex(v)
	mesh.surface_end();shape(mesh,Vector3.ZERO,color,life)
func impacts(rules: String,start: Vector3,ends: PackedVector3Array,weapon: int) -> void:
	for end in ends:
		if start.distance_to(end)<.01:continue
		if rules=="quake" and weapon==8:
			var points:=PackedVector3Array([start]);var steps:=clampi(int(start.distance_to(end)*3),3,48)
			for i in range(1,steps):points.append(start.lerp(end,float(i)/steps)+Vector3(randf_range(-.11,.11),randf_range(-.11,.11),randf_range(-.11,.11)))
			points.append(end);streak(points,Color("789bf0"),.037,.12);streak(points,Color("e3edff"),.012,.10)
		elif rules=="ut99" and weapon in [3,7]:
			var c:=Color("b75eff") if weapon==3 else Color("4bfa65")
			streak(PackedVector3Array([start,end]),c,.045,.16 if weapon==3 else .11)
			streak(PackedVector3Array([start,end]),Color("f1eaff"),.009,.10)
			globe(end,c,.20,.15)
		elif rules=="ut99" and weapon in [2,5]:
			# Brief warm bullet streaks, not a persistent rail beam.
			if randf()<.45:streak(PackedVector3Array([start,end]),Color(1,.72,.3,.65),.008,.04)
		for i in (3 if weapon in [3,8] else 2):particle(end,Vector3(randf_range(-1,1),randf_range(.2,1.5),randf_range(-1,1)),Color("ceac74") if rules=="quake" else Color("ffc675"),.035,.25)
func projectile(rules: String,definition: Dictionary) -> Node3D:
	var root:=Node3D.new();var kind: String=definition.kind;root.set_meta("kind",kind);root.set_meta("trail_time",0.0)
	var color:=Color("776f58") if rules=="quake" else Color("b7a077")
	match kind:
		"nail":Art.barrel(root,Vector3.ZERO,.016,.24,Art.material(Color("a29a81"),.8))
		"rocket","warhead":
			Art.barrel(root,Vector3.ZERO,.075 if kind=="rocket" else .18,.36 if kind=="rocket" else .7,Art.material(color,.7))
			Art.barrel(root,Vector3(0,0,.20),.046,.07,material(Color("ffb64b")))
		"grenade","flak_shell":
			Art.barrel(root,Vector3.ZERO,.10,.19,Art.material(color,.7))
			Art.barrel(root,Vector3(0,0,-.1),.065,.04,Art.material(Color("b69539"),.6))
		"razor","razor_blast","translocator":
			var blade:=Art.barrel(root,Vector3.ZERO,.19,.024,Art.material(Color("a5b9bf"),.85));blade.rotation.x=0;blade.name="Spin"
			for i in 8:
				var angle:=i*TAU/8;var tooth:=Art.box(blade,Vector3(cos(angle)*.17,0,sin(angle)*.17),Vector3(.06,.018,.05),Art.material(Color("c4d1d4"),.8));tooth.rotation.y=-angle
		"flak":Art.box(root,Vector3.ZERO,Vector3(.055,.035,.11),material(Color("ffe08a")))
		_:
			var ball:=SphereMesh.new();ball.radius=.22 if kind=="shock_orb" else .14 if kind=="bio" else .09;ball.height=ball.radius*2;ball.radial_segments=12;ball.rings=6
			var node:=MeshInstance3D.new();node.mesh=ball
			node.material_override=material(Color("ac61ef") if kind=="shock_orb" else Color("7ce63b") if kind=="bio" else Color("5eff64"));root.add_child(node)
			if kind=="pulse":node.scale=Vector3(.7,.7,2.2)
			if kind=="bio":node.scale*=pow(maxf(1,definition.get("splash",20)/20.0),.33)
			if kind=="shock_orb":
				var halo:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.22;torus.outer_radius=.28;torus.rings=16;torus.ring_segments=6;halo.mesh=torus;halo.material_override=material(Color("dab4ff"));root.add_child(halo)
	return root
func travel(node: Node3D,velocity: Vector3,delta: float,stuck: bool) -> void:
	var kind: String=node.get_meta("kind","")
	if velocity.length_squared()>.01 and not stuck:node.basis=Basis.looking_at(velocity.normalized(),Vector3.RIGHT if absf(velocity.normalized().y)>.99 else Vector3.UP)
	var spin:=node.get_node_or_null("Spin")
	if spin:spin.rotate_y(delta*24)
	if stuck:
		if kind=="bio":node.scale=Vector3(1.6,.4,1.6)
		return
	var age: float=node.get_meta("trail_time",0.0)+delta;node.set_meta("trail_time",age)
	if age<.035:return
	node.set_meta("trail_time",0.0)
	if kind in ["rocket","warhead","grenade","flak_shell"]:
		for i in mini(4,maxi(1,int(velocity.length()*minf(age,.1)/.25))):
			var pos:=node.global_position-velocity*minf(age,.1)*(i/4.0)
			particle(pos,Vector3.UP*.15,Color(.25,.23,.20,.6),.16 if kind=="rocket" else .12,.65,true)
			if kind in ["rocket","warhead"]:particle(pos,Vector3.ZERO,Color("ff9c38"),.075,.14)
	elif kind=="flak":particle(node.global_position,Vector3.ZERO,Color("ffb234"),.045,.17)
	elif kind in ["shock_orb","pulse"]:particle(node.global_position,Vector3.ZERO,Color("a767df") if kind=="shock_orb" else Color("59de54"),.07,.15)
func burst(rules: String,pos: Vector3,weapon: int,kind: String="") -> void:
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
	globe(pos,Color(.86,.65,1,.85),2.7,.32)
	for i in 3:
		ring(pos+Vector3.UP*(i-1)*.2,Color(.63,.22,1,.8),4.5-i*.4,.45+i*.07)
	for i in 28:particle(pos,Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1)).normalized()*7,Color("b772fa"),.07,.6)
