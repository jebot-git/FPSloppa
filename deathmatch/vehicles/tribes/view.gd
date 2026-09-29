extends Node3D
const Data=preload("res://deathmatch/vehicles/tribes/scout_data.gd")
var controller
var nodes: Dictionary={}
var shots: Dictionary={}
var labels: Dictionary={}
func setup(value):
	controller=value
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
func release(node: Node3D):
	var engine=node.get_node_or_null("Turbine")
	if engine:engine.stop()
	node.queue_free()
func clear():
	for node in nodes.values():if is_instance_valid(node):release(node)
	for node in shots.values():if is_instance_valid(node):release(node)
	nodes.clear();shots.clear();labels.clear()
func update(delta: float):
	var c=controller;var game=c.game
	for key in nodes.keys():
		if not c.rows.has(key):release(nodes[key]);nodes.erase(key);labels.erase(key)
	for key in c.rows:
		var row: Dictionary=c.rows[key];var d: Dictionary=c.definition(row)
		if nodes.has(key) and nodes[key].get_meta("kind","scout")!=row.get("kind","scout"):release(nodes[key]);nodes.erase(key);labels.erase(key)
		if not nodes.has(key):
			var scene=load("res://deathmatch/vehicles/tribes/"+row.get("kind","scout")+".scn")
			if scene==null:continue
			var model: Node3D=scene.instantiate();add_child(model);nodes[key]=model;model.set_meta("kind",row.get("kind","scout"));model.global_transform=c.seat_frame(row)
			var engine:=AudioStreamPlayer3D.new();engine.name="Turbine";engine.stream=load("res://deathmatch/vehicles/tribes/turbine.res");engine.max_distance=100;engine.unit_size=4;engine.volume_db=-14;model.add_child(engine);engine.play()
			var label:=Label3D.new();label.name="ScoutStatus";label.position=Vector3(0,3.5,1);label.font_size=24;label.pixel_size=.005;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;model.add_child(label);labels[key]=label
		var model: Node3D=nodes[key]
		if model.get_meta("team",-1)!=row.team:
			model.set_meta("team",row.team)
			for mesh in model.find_children("*","MeshInstance3D",true,false):
				for surface in mesh.mesh.get_surface_count():
					var material=mesh.get_active_material(surface)
					if material and "TeamPanel" in material.resource_name:
						material=material.duplicate();material.albedo_color=Color("923a2f") if row.team==0 else Color("306b9d");mesh.set_surface_override_material(surface,material)
		model.global_transform=c.render_frame(key)
		model.get_node("Turbine").pitch_scale=.8+minf(1,row.velocity.length()/d.speed)*.8
		labels[key].text="%s · %d%% · %d km/h · %d/%d"%[d.name,roundi(row.hp/d.hp*100),roundi(row.velocity.length()*3.6),c.occupants(row).filter(func(id):return id!=0).size(),d.seats.size()]
		labels[key].modulate=Color("e96b55") if row.team==0 else Color("5bb1f5")
		# Fighter render origins and animated graphics read this same frame.
		for person in c.occupants(row):
			if game.fighters.has(person):game.fighters[person].update_mounted_visuals()
		labels[key].visible=not c.mounted(game.multiplayer.get_unique_id())
	for key in shots.keys():
		if not c.rockets.has(key):shots[key].queue_free();shots.erase(key)
	for key in c.rockets:
		if not shots.has(key):
			var mesh:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.09;sphere.height=.18;mesh.mesh=sphere
			var mat:=StandardMaterial3D.new();mat.albedo_color=Color("ffb854");mat.emission_enabled=true;mat.emission=mat.albedo_color;mat.emission_energy_multiplier=2;mesh.material_override=mat;add_child(mesh);shots[key]=mesh
		shots[key].global_position=c.rockets[key].position
