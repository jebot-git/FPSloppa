extends RefCounted
## Shared native art. No collision, targeting, power or replication state lives here.
static var scenes: Dictionary={}
static var materials: Dictionary={}
static func make(kind: String,team: int=0) -> Node3D:
	if not scenes.has(kind):scenes[kind]=load("res://deathmatch/tribes/props/"+kind+".scn")
	var root: Node3D=scenes[kind].instantiate();root.set_meta("st_team",team);set_active(root,true);return root
static func set_active(root: Node3D,active: bool):
	if not is_instance_valid(root) or root.has_meta("st_active") and root.get_meta("st_active")==active:return
	root.set_meta("st_active",active)
	var team: int=root.get_meta("st_team",0)
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var source=mesh.mesh.surface_get_material(i)
			if not source is StandardMaterial3D:continue
			var paint: bool="TeamPanel" in source.resource_name
			var lamp: bool="StatusLight" in source.resource_name
			if not paint and not lamp:continue
			var key: String=source.resource_name+str(team)+str(active)
			if not materials.has(key):
				var mat=source.duplicate()
				if paint:mat.albedo_color=(Color("a44232") if team==0 else Color("387ab0")) if active else Color("51555a")
				if lamp:
					mat.albedo_color=Color("56cfdf") if active else Color("7d2824");mat.emission=mat.albedo_color;mat.emission_energy_multiplier=1.1 if active else .12
				materials[key]=mat
			mesh.set_surface_override_material(i,materials[key])
