extends RefCounted
const Route=preload("res://deathmatch/vehicles/ba2/route.gd")
const Timing=preload("res://deathmatch/modes/titanball.gd")
static func points() -> Array:
	var result: Array=[Vector3(0,0,0),Vector3(0,0,36),Vector3(24,0,67),Vector3(24,0,101),Vector3(-24,0,140),Vector3(-24,0,181),Vector3(0,0,211)]
	# Re-bake after scaling because Curve3D uses a fixed world-space bake interval.
	for iteration in 3:
		var scale: float=Timing.ROUTE_METRES/Route.curve(result).get_baked_length()
		for i in result.size():result[i]*=scale
	return result
static func build(game: Node3D) -> void:
	game.match_mode.fortress.walkers.configure([])
	for child in game.get_node("Map").get_children():child.free()
	game.pickups.clear();game.gates.clear();game.lifts.clear();game.map_objectives.clear();game.map_assault.clear();game.tf_resupply=[[],[]];game.tf_capture.clear()
	var curve:=Route.curve(points());var length:=curve.get_baked_length();var sections: Array=[]
	var start:=Route.sample(curve,0);start.origin-=start.basis.z*8;sections.append(start)
	for i in range(ceili(length/3.)+1):sections.append(Route.sample(curve,minf(length,i*3.)))
	var end:=Route.sample(curve,length);end.origin+=end.basis.z*8;sections.append(end)
	var floor_tool:=SurfaceTool.new();floor_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for i in sections.size()-1:
		var a: Transform3D=sections[i];var b: Transform3D=sections[i+1]
		var al: Vector3=a.origin-a.basis.x*23;var ar: Vector3=a.origin+a.basis.x*23
		var bl: Vector3=b.origin-b.basis.x*23;var br: Vector3=b.origin+b.basis.x*23
		_quad(floor_tool,al,bl,br,ar)

	floor_tool.generate_normals()
	var mesh:=floor_tool.commit()
	var floor_material:=ShaderMaterial.new();var shader:=Shader.new()
	shader.code="shader_type spatial; varying vec3 p; void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){float grain=fract(sin(dot(floor(p.xz*18.0),vec2(12.98,78.23)))*43758.54);ALBEDO=vec3(0.18,0.19,0.19)*(0.92+grain*0.12);ROUGHNESS=0.95;}";floor_material.shader=shader
	var wall_material:=StandardMaterial3D.new();wall_material.albedo_color=Color("455761");wall_material.roughness=.9
	mesh.surface_set_material(0,floor_material)
	var body:=StaticBody3D.new();body.name="WindingCorridor";body.position.y=.02;var shape:=CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();body.add_child(shape)
	if not game.headless:
		var visual:=MeshInstance3D.new();visual.mesh=mesh;body.add_child(visual)
	game.get_node("Map").add_child(body)
	game.spawn_points=[];game.spawn_yaws=[]
	var forward: Array=[]
	for i in 3:forward.append(_spawn_bays(game,curve,[0.,72.,172.][i],true,i))
	var defenders:=_spawn_bays(game,curve,300.,false,0)
	game.ctf_spawns=[forward[0].duplicate(),defenders.duplicate()];game.fall_limit=-12;game.map_title="TB — TITANBALL · Ruined City Siege"
	game.match_mode.bases=[Route.sample(curve,0).origin,Route.sample(curve,300).origin];game.match_mode.captures=game.match_mode.bases.duplicate()
	var supply: Array=[]
	for row in [[0.,14.,-1.],[70.,16.,0.],[96.,-11.,0.],[170.,16.,0.],[196.,-11.,0.],[298.,-15.,0.]]:
		supply.append(Route.sample(curve,row[0])*Vector3(row[1],.05,row[2]))
	game.match_mode.titanball.configure(forward,defenders,supply)
	_defences(game,curve)
	preload("res://tools/ba2/gameplay/city.gd").new().build(game,curve)
	game.match_mode.fortress.walkers.configure([{"id":"test","points":points(),"loop":false,"team":Timing.ATTACKERS}])
	if not game.headless:
		for i in Timing.CHECKPOINTS.size():_checkpoint(game,Route.sample(curve,Timing.CHECKPOINTS[i]),i)
		var env: Environment=game.get_node("Environment").environment.duplicate();env.background_mode=Environment.BG_COLOR;env.background_color=Color("677e90");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("c9d8e0");env.ambient_light_energy=.75;env.fog_enabled=false;game.get_node("Environment").environment=env
static func _quad(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	for v in [a,c,b,a,d,c]:tool.add_vertex(v)

static func _checkpoint(game: Node3D,pose: Transform3D,index: int) -> void:
	var gate:=Node3D.new();gate.name="Checkpoint"+str(index+1);gate.transform=pose;game.get_node("Map").add_child(gate)
	var material:=StandardMaterial3D.new();material.albedo_color=Color("e9b449");material.roughness=.8
	for box in [[Vector3(-12,7,0),Vector3(.45,14,.45)],[Vector3(12,7,0),Vector3(.45,14,.45)],[Vector3(0,14,0),Vector3(24.45,.45,.45)],[Vector3(0,.015,0),Vector3(24,.02,.65)]]:
		var visual:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=box[1];visual.mesh=mesh;visual.position=box[0];visual.material_override=material;gate.add_child(visual)
	var label:=Label3D.new();label.text="CHECKPOINT %d · %d m\n+3:00 AFTER ROBOT CLEARS"%[index+1,Timing.CHECKPOINTS[index]];label.position=Vector3(0,12.3,0);label.font_size=64;label.pixel_size=.015;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;gate.add_child(label)

static func _block(game: Node3D,name: String,pose: Transform3D,at: Vector3,size: Vector3,color: Color) -> StaticBody3D:
	var body:=StaticBody3D.new();body.name=name;body.transform=pose;body.position=pose*at
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape)
	if not game.headless:
		var visual:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;visual.mesh=mesh
		var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=.9;visual.material_override=material;body.add_child(visual)
	game.get_node("Map").add_child(body);return body
static func _spawn_bays(game: Node3D,curve: Curve3D,distance: float,attack: bool,stage: int) -> Array:
	var pose:=Route.sample(curve,distance);var result: Array=[]
	var color:=Color("a35c50") if attack else Color("506f9b")
	for side in [-1.,1.]:
		for z in [-1.,1.]:
			var point: Vector3=pose*Vector3(side*18,.05,z);result.append(point);game.spawn_points.append(point)
			game.spawn_yaws.append(pose.basis.get_euler().y+(PI if attack else 0.))
		_block(game,("AttackSpawn"+str(stage) if attack else "DefenderSpawn")+str(side),pose,Vector3(side*18,1.5,4 if attack else -4),Vector3(7,3,.6),color)
		if not game.headless:
			var label:=Label3D.new();label.text=("RED ATTACK SPAWN · "+str(stage)) if attack else "BLUE DEFENDER BASE"
			label.position=pose*Vector3(side*18,3.6,4 if attack else -4);label.font_size=40;label.pixel_size=.01;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;game.get_node("Map").add_child(label)
	return result
static func _defences(game: Node3D,curve: Curve3D) -> void:
	# Keep all solids outside the 26 m robot lane; side lanes remain traversable.
	# Stage 1: low cover only. Stage 2: one elevated nest. Stage 3: crossfire.
	for row in [[38.,-1.,.9],[115.,1.,1.2],[155.,-1.,1.2],[209.,1.,1.3],[250.,-1.,1.3],[280.,1.,1.3]]:
		_block(game,"Cover"+str(row[0]),Route.sample(curve,row[0]),Vector3(row[1]*16,row[2]/2,0),Vector3(4,row[2],1.2),Color("a19779"))
	for row in [[135.,-1.,2.5],[235.,-1.,4.],[235.,1.,4.],[275.,1.,5.]]:
		_balcony(game,Route.sample(curve,row[0]),row[1],row[2],str(row[0])+str(row[1]))
	var finish:=Route.sample(curve,300.)
	_block(game,"BlueBaseGoal",finish,Vector3(0,.025,0),Vector3(25,.05,1.5),Color("4269a8"))
	if not game.headless:
		var label:=Label3D.new();label.text="BLUE BASE · DELIVER TITAN";label.position=finish*Vector3(0,11,0);label.font_size=64;label.pixel_size=.016;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;game.get_node("Map").add_child(label)
static func _balcony(game: Node3D,pose: Transform3D,side: float,height: float,key: String) -> void:
	_block(game,"Balcony"+key,pose,Vector3(side*18,height-.25,0),Vector3(8,.5,16),Color("6d7e86"))
	# Short parapets with firing gaps; no enclosed dead-end nests.
	for z in [-5.,5.]:_block(game,"Parapet"+key+str(z),pose,Vector3(side*14.3,height+.45,z),Vector3(.6,.9,4),Color("556b7c"))
	for direction in [-1.,1.]:
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var near: float=8.*direction;var far: float=20.*direction
		var a:=Vector3(side*18-2.5,height,near);var b:=Vector3(side*18-2.5,0,far)
		var c:=Vector3(side*18+2.5,0,far);var d:=Vector3(side*18+2.5,height,near)
		if direction>0:_quad(surface,a,b,c,d)
		else:_quad(surface,d,c,b,a)
		surface.generate_normals();var mesh:=surface.commit()
		var body:=StaticBody3D.new();body.name="Ramp"+key+str(direction);body.transform=pose
		var collision:=CollisionShape3D.new();collision.shape=mesh.create_trimesh_shape();body.add_child(collision)
		if not game.headless:
			var visual:=MeshInstance3D.new();visual.mesh=mesh;var material:=StandardMaterial3D.new();material.albedo_color=Color("9b9684");material.roughness=.9;visual.material_override=material;body.add_child(visual)
		game.get_node("Map").add_child(body)
