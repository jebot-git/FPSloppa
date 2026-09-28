extends RefCounted
## Original native geometry in the arsenal's dark metal / team accent palette.
## Three batched material surfaces, no textures, bones or imported dependencies.
static var meshes: Dictionary={}
static func mesh(parts: Array,team: int) -> ArrayMesh:
	var mesh:=ArrayMesh.new()
	var colors: Array=[Color("374952"),Color("e45e51") if team==0 else Color("67a5ed"),Color("9be9d3")]
	for layer in 3:
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);var count:=0
		for part in parts:
			if part[0]!=layer:continue
			var box:=BoxMesh.new();box.size=part[2];surface.append_from(box,0,Transform3D(Basis.IDENTITY,part[1]));count+=1
		if count==0:continue
		var mat:=StandardMaterial3D.new();mat.albedo_color=colors[layer];mat.metallic=.65;mat.roughness=.55
		if layer==2:mat.emission_enabled=true;mat.emission=colors[layer];mat.emission_energy_multiplier=.4
		surface.set_material(mat);surface.commit(mesh)
	return mesh
static func make(kind: String,team: int=0,packed: bool=false) -> Node3D:
	var root:=Node3D.new();var key:=kind+str(team)
	if not meshes.has(key):
		var parts: Array=[[0,Vector3(0,.08,0),Vector3(.72,.16,.64)],[1,Vector3(0,.18,0),Vector3(.53,.12,.45)]]
		match kind:
			"turret":
				parts.append_array([[0,Vector3(0,.5,0),Vector3(.34,.66,.34)],[1,Vector3(0,.79,0),Vector3(.62,.23,.55)]])
				for x in [-.4,.4]:parts.append([0,Vector3(x,.16,.2),Vector3(.18,.2,.68)])
			"inventory":
				parts.append_array([[0,Vector3(0,.7,.12),Vector3(1.1,1.15,.48)],[1,Vector3(0,1.35,.08),Vector3(1.22,.2,.58)],[2,Vector3(0,1.0,-.135),Vector3(.72,.38,.025)],[0,Vector3(0,.72,-.3),Vector3(.95,.12,.4)]])
			"ammo_station":
				parts.append_array([[0,Vector3(0,.42,0),Vector3(1.12,.6,.72)],[1,Vector3(0,.74,0),Vector3(1.2,.1,.78)],[2,Vector3(0,.53,-.367),Vector3(.4,.1,.02)]])
				for x in [-.32,0,.32]:parts.append([0,Vector3(x,.58,-.45),Vector3(.16,.2,.15)])
			"pulse":
				parts.append_array([[0,Vector3(0,.56,0),Vector3(.15,.9,.15)],[1,Vector3(0,1.07,0),Vector3(.82,.4,.12)],[2,Vector3(0,1.09,-.09),Vector3(.12,.12,.15)]])
			"motion":parts.append_array([[0,Vector3(0,.32,0),Vector3(.4,.28,.4)],[2,Vector3(0,.35,-.21),Vector3(.25,.15,.03)]])
			"remote_jammer":
				parts.append([0,Vector3(0,.4,0),Vector3(.42,.5,.4)])
				for x in [-.3,.3]:parts.append_array([[0,Vector3(x,.68,0),Vector3(.055,.62,.06)],[2,Vector3(x,.98,0),Vector3(.1,.04,.1)]])
			"camera":parts.append([0,Vector3(0,.35,0),Vector3(.12,.4,.12)])
		meshes[key]=mesh(parts,team)
	var body:=MeshInstance3D.new();body.mesh=meshes[key];root.add_child(body)
	if kind=="turret":
		var head:=MeshInstance3D.new();head.name="Head";head.position=Vector3(0,.83,0)
		var head_key:="head"+str(team)
		if not meshes.has(head_key):meshes[head_key]=mesh([[0,Vector3.ZERO,Vector3(.5,.27,.55)],[1,Vector3(0,.06,-.35),Vector3(.3,.16,.38)],[2,Vector3(0,.06,-.56),Vector3(.13,.09,.08)]],team)
		head.mesh=meshes[head_key];root.add_child(head)
	elif kind=="camera":
		var head:=MeshInstance3D.new();head.name="Head";head.position=Vector3(0,.57,0)
		var head_key:="camera_head"+str(team)
		if not meshes.has(head_key):meshes[head_key]=mesh([[1,Vector3.ZERO,Vector3(.48,.2,.32)],[2,Vector3(0,0,-.22),Vector3(.14,.13,.17)]],team)
		head.mesh=meshes[head_key];root.add_child(head)
	if packed:root.scale=Vector3.ONE*.3;body.position.y=-.2
	return root
