extends RefCounted
## Collision-first ruined city fixture. Decorative boxes batch by material.
const Route=preload("res://deathmatch/vehicles/ba2/route.gd")
const CONCRETE=Color("68675d")
const STONE=Color("8c897b")
const BRICK=Color("74534a")
const STEEL=Color("3a4248")
const DARK=Color("1c282f")
const RUST=Color("97704a")
var game: Node3D
var solid: StaticBody3D
var batches: Dictionary={}
var rooms: Array=[]
var bridges: Array=[]
func box(pose: Transform3D,at: Vector3,size: Vector3,color: Color,collision: bool=true,visible: bool=true) -> void:
	var transform:=pose*Transform3D(Basis.IDENTITY,at)
	if collision:
		var shape:=CollisionShape3D.new();var cube:=BoxShape3D.new();cube.size=size;shape.shape=cube;shape.transform=transform;solid.add_child(shape)
	if not game.headless and visible:
		var key:=color.to_html()
		if not batches.has(key):var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);batches[key]=tool
		var mesh:=BoxMesh.new();mesh.size=size;batches[key].append_from(mesh,0,transform)
func label(at: Vector3,text: String,color: Color=Color.WHITE) -> void:
	if game.headless:return
	var node:=Label3D.new();node.position=at;node.text=text;node.modulate=color;node.font_size=56;node.pixel_size=.013;node.billboard=BaseMaterial3D.BILLBOARD_ENABLED;game.get_node("Map").add_child(node)
func build(arena: Node3D,curve: Curve3D) -> void:
	game=arena;solid=StaticBody3D.new();solid.name="RuinedCity";game.get_node("Map").add_child(solid)
	box(Transform3D.IDENTITY,Vector3(0,-.3,128),Vector3(210,.6,312),Color("494a43"))
	# Bound the playable district, including roofs, while preserving side streets.
	for x in [-104.,104.]:box(Transform3D.IDENTITY,Vector3(x,25,128),Vector3(2,50,312),DARK,true,false)
	for z in [-28.,284.]:box(Transform3D.IDENTITY,Vector3(0,25,z),Vector3(210,50,2),DARK,true,false)
	for d in range(25,299,8):
		var pose:=Route.sample(curve,d)
		for side in [-1.,1.]:
			box(pose,Vector3(side*12,.035,0),Vector3(.16,.02,3.5),Color("b0a57e"),false)
			box(pose,Vector3(side*13,.12,0),Vector3(.3,.24,7.7),STONE)
	for row in [[43.,-1.,31.],[43.,1.,24.],[115.,-1.,38.],[115.,1.,29.],[158.,-1.,24.],[158.,1.,36.],[245.,-1.,42.],[245.,1.,31.]]:
		tower(Route.sample(curve,row[0]),row[1],row[2],int(row[0]))
	for d in [88.,198.]:overpass(Route.sample(curve,d),d)
	base(Route.sample(curve,300.))
	hangar()
	# Rubble stays on the sidewalk edges, away from spawns and the central lane.
	for d in [50.,105.,150.,207.,260.]:
		var pose:=Route.sample(curve,d)
		for i in 4:
			var side: float=-1. if i%2==0 else 1.
			box(pose,Vector3(side*(21.+i*.3),.25+(i%2)*.2,i*1.4-2),Vector3(1.8,.5+(i%2)*.4,1.1),STONE)
	for key in batches:
		var mesh: ArrayMesh=batches[key].commit();var material:=StandardMaterial3D.new();material.albedo_color=Color(key);material.roughness=.95;mesh.surface_set_material(0,material)
		var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.name="CityMaterial"+key;solid.add_child(visual)
	solid.set_meta("ambush_rooms",rooms);solid.set_meta("overpasses",bridges)
func tower(pose: Transform3D,side: float,height: float,seed_value: int) -> void:
	var x: float=side*34.
	# Leave a street between buildings where the route doubles back.
	for attempt in 3:
		var centre: Vector3=pose*Vector3(x,0,0)
		if rooms.any(func(room):return room.centre.distance_to(centre)<32.):x+=side*12.
	# Accessible street-level rooms have a road entrance and two street exits.
	box(pose,Vector3(x,4.2,0),Vector3(16,.5,23),CONCRETE)
	for z in [-7.5,7.5]:box(pose,Vector3(x-side*8,2,z),Vector3(.8,4,8),BRICK)
	box(pose,Vector3(x+side*8,2,0),Vector3(.8,4,23),BRICK)
	for z in [-11.5,11.5]:
		for offset in [-5.5,5.5]:box(pose,Vector3(x+offset,2,z),Vector3(5,4,.8),BRICK)
	# Interior ambush cover, leaving the centre and all exits connected.
	box(pose,Vector3(x+side*3,.65,5),Vector3(4,1.3,1.4),STONE)
	rooms.append({"centre":pose*Vector3(x,.05,0),"entrance":pose*Vector3(x-side*8,.05,0),"exits":[pose*Vector3(x,.05,-12),pose*Vector3(x,.05,12)]})
	# Tall intact cores and broken facade bands; upper floors are scenery.
	box(pose,Vector3(x+side*1.2,(height+4.5)/2,0),Vector3(12,height-4.5,19),DARK)
	for floor_index in range(1,int(height/4)):
		var y:=4.+floor_index*4.
		box(pose,Vector3(x,y,0),Vector3(16.5,.45,23.5),STONE,false)
		for z in [-9.,-3.,3.,9.]:
			if floor_index>int(height/4)-3 and int(z+seed_value+floor_index)%3==0:continue
			box(pose,Vector3(x-side*8,y-1.8,z),Vector3(.8,3.5,.8),CONCRETE,false)
			box(pose,Vector3(x-side*8,y-3.2,z),Vector3(.8,.65,5.5),BRICK,false)
		for edge in [-1.,1.]:
			box(pose,Vector3(x+edge*5.5,y-1.8,11.5),Vector3(1,3.5,.8),CONCRETE,false)
	# Jagged roof fragments and exposed steel, without accessible sharp rubble.
	for i in 3:box(pose,Vector3(x-6+i*5,height+float(i%2),-8+i*7),Vector3(1.1,2.+i,1.2),CONCRETE,false)
	label(pose*Vector3(x-side*8.5,3,0),"ARCADE" if seed_value<180 else "DEFENCE BLOCK",Color("c5b99a"))
func ramp(pose: Transform3D,x: float,y: float,z_start: float,z_end: float,rise: float,width: float) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a:=Vector3(x-width/2,y,z_start);var b:=Vector3(x-width/2,y+rise,z_end);var c:=Vector3(x+width/2,y+rise,z_end);var d:=Vector3(x+width/2,y,z_start)
	for vertex in ([a,c,b,a,d,c] if z_end>z_start else [a,b,c,a,c,d]):st.add_vertex(pose*vertex)
	st.generate_normals();var mesh:=st.commit();var shape:=CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();solid.add_child(shape)
	if not game.headless:
		var key:=STONE.to_html()
		if not batches.has(key):var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);batches[key]=tool
		batches[key].append_from(mesh,0,Transform3D.IDENTITY)
func overpass(pose: Transform3D,distance: float) -> void:
	var height:=14.
	box(pose,Vector3(0,height-.4,0),Vector3(78,.8,6),CONCRETE)
	for z in [-3.,3.]:box(pose,Vector3(0,height+.5,z),Vector3(78,1,.45),STEEL)
	for side in [-1.,1.]:
		box(pose,Vector3(side*25,6.6,0),Vector3(1.4,13.2,2),CONCRETE)
		var x: float=side*34.
		for flight in 4:
			var ascending:=flight%2==0;var lane: float=x+(-2. if ascending else 2.)
			ramp(pose,lane,flight*3.5,-6 if ascending else 6,6 if ascending else -6,3.5,3.4)
			box(pose,Vector3(x,(flight+1)*3.5-.15,7. if ascending else -7.),Vector3(8,.3,2),STONE)
		box(pose,Vector3(x,height-.15,-3.5),Vector3(8,.3,5),STONE)
		bridges.append({"route":distance,"height":height,"bottom":pose*Vector3(x-2,.05,-6),"top":pose*Vector3(x,height+.05,0)})
	label(pose*Vector3(0,height+1.6,0),"ELEVATED TRANSIT · "+str(int(distance)),Color("c8b07f"))
func base(pose: Transform3D) -> void:
	# Thick pillboxes with firing slits and rear doors, flanking the delivery zone.
	for side in [-1.,1.]:
		var x: float=side*31.
		box(pose,Vector3(x,6,0),Vector3(16,1,16),CONCRETE)
		for edge in [-7.5,7.5]:box(pose,Vector3(x+edge,3,0),Vector3(1,6,16),CONCRETE)
		box(pose,Vector3(x,.65,-7.5),Vector3(16,1.3,1),CONCRETE)
		box(pose,Vector3(x,4,-7.5),Vector3(16,4,1),CONCRETE)
		for edge in [-6.,0.,6.]:box(pose,Vector3(x+edge,1.65,-7.5),Vector3(1.2,.7,1),CONCRETE)
		for edge in [-5.,5.]:box(pose,Vector3(x+edge,3,7.5),Vector3(6,6,1),CONCRETE)
		# Door facing the lane prevents a defender base dead end.
		label(pose*Vector3(x,7,0),"BLUE STRONGPOINT",Color("91bada"))
	box(pose,Vector3(0,15,7),Vector3(49,2,2),CONCRETE)
	for side in [-1.,1.]:box(pose,Vector3(side*23.5,7,7),Vector3(2,14,2),CONCRETE)
func hangar() -> void:
	var pose:=Transform3D.IDENTITY
	box(pose,Vector3(0,8,-8),Vector3(47,16,1),STEEL)
	for x in [-23.,23.]:box(pose,Vector3(x,8,5),Vector3(1,16,27),STEEL)
	box(pose,Vector3(0,16,5),Vector3(47,1,27),STEEL)
	# Door aperture: 26 m wide, 13 m tall. Slits are only 0.30 m high.
	box(pose,Vector3(0,14.5,18),Vector3(47,3,1),CONCRETE)
	for side in [-1.,1.]:
		for x in [14.5,21.5]:box(pose,Vector3(side*x,6.5,18),Vector3(3,13,1),CONCRETE)
		box(pose,Vector3(side*18,.65,18),Vector3(4,1.3,1),CONCRETE)
		box(pose,Vector3(side*18,7.3,18),Vector3(4,11.4,1),CONCRETE)
		label(Vector3(side*18,2.2,17.4),"FIRING SLIT",Color("cda967"))
	var gate:=AnimatableBody3D.new();gate.name="HangarGate";gate.sync_to_physics=false;game.get_node("Map").add_child(gate)
	var shape:=CollisionShape3D.new();var cube:=BoxShape3D.new();cube.size=Vector3(26,13,1);shape.shape=cube;shape.position=Vector3(0,6.5,18);gate.add_child(shape)
	if not game.headless:
		var visual:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=cube.size;visual.mesh=mesh;visual.position=shape.position;var material:=StandardMaterial3D.new();material.albedo_color=RUST;visual.material_override=material;gate.add_child(visual)
	label(Vector3(0,14,16.9),"TITAN DEPOT · GATE OPENS AFTER PREPARATION",Color("e0bb73"))
	game.match_mode.titanball.update_gate()
