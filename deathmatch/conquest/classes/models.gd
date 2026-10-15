extends RefCounted
static var manifest:Dictionary={}
static var slide_meshes:Dictionary={}
static func entry(id:int,rules:String) -> String:
	if id==6 and rules=="cq_turret":return "designator"
	if id==6:return "health_box" if rules=="cq_medic" else "ammo_box"
	if id==7:return "injector" if rules=="cq_medic" else "repair_kit"
	return {0:"burst_pistol",1:"assault_rifle",2:"pistol",3:"smg",4:"carbine",5:"massacre",8:"designator",9:"scout_pistol",10:"beam_pistol",11:"guided_launcher"}.get(id,"pistol")
static func metadata(id:int,rules:String) -> Dictionary:
	if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/weapons/cq/manifest.json"))
	return manifest.get(entry(id,rules),{})
static func weapon(id:int,rules:String) -> Node3D:
	var node:Node3D=load("res://deathmatch/weapons/cq/"+entry(id,rules)+".glb").instantiate()
	node.set_meta("cq_weapon",id)
	node.set_meta("muzzle",muzzle(id,rules))
	var data:=metadata(id,rules)
	for key in ["scope_rear","scope_front"]:
		if data.has(key):node.set_meta(key,Vector3(data[key][0],data[key][1],data[key][2]))
	if data.has("scope_radius"):node.set_meta("scope_radius",data.scope_radius);node.set_meta("cq_zoom",true)
	if data.has("zoom_steps"):node.set_meta("zoom_steps",data.zoom_steps)
	if data.get("red_dot",false):node.set_meta("red_dot",true)
	if id in [0,3,4,8]:
		var dot:=MeshInstance3D.new();var aperture:=QuadMesh.new();aperture.size=Vector2(.028,.028);dot.mesh=aperture
		var finish:=ShaderMaterial.new();finish.shader=preload("res://deathmatch/conquest/classes/red_dot.gdshader");dot.material_override=finish;dot.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(dot);dot.name="AlignedRedDot";dot.position=Vector3(0,.234 if id==4 else .164,-.09)
		if data.has("red_dot_position"):
			var p:Array=data.red_dot_position;dot.position=Vector3(p[0],p[1],p[2])
		dot.position.z+=.018
	var handle=node.find_child("ChargingHandle",true,false)
	if handle:
		if id in [0,2,9,10,8]:handle.free()
		else:handle.position=anchor(id,"rack_anchor")
	if id in [0,2,9,10]:split_slide(node,entry(id,rules))
	if id==5 and not node.find_child("InsertedAmmo",true,false):
		var ammo:=ammunition(node,id);node.add_child(ammo);ammo.name="InsertedAmmo";ammo.position=Vector3(-.08,.015,.02)

	return node
static func support_pose(model:Transform3D,id:int,left:bool)->Transform3D:
	return Transform3D(model.basis.orthonormalized()*Basis(Vector3.BACK,PI/2 if left else -PI/2),model*anchor(id,"support_anchor"))
static func ammunition(model:Node3D,id:int) -> MeshInstance3D:
	var inserted=model.find_child("InsertedAmmo",true,false)
	if inserted is MeshInstance3D:
		var copy:MeshInstance3D=inserted.duplicate();copy.transform=Transform3D.IDENTITY;copy.visible=true;return copy
	var result:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(.032,.085,.03) if id in [2,3,9] else Vector3(.06,.055,.06) if id in [5,11] else Vector3(.034,.065,.034);result.mesh=mesh
	var surfaces:=model.find_children("*","MeshInstance3D",true,false)
	if not surfaces.is_empty():result.material_override=surfaces[0].get_active_material(0)
	return result
static func muzzle(id:int,rules:String) -> Vector3:
	var p:Array=metadata(id,rules).get("muzzle",[0,0,-.2]);return Vector3(p[0],p[1],p[2])

static func animate_reload(model:Node3D,state:Dictionary) -> void:
	if not is_instance_valid(model):return
	var handle=model.find_child("ChargingHandle",true,false)
	if handle:
		if not handle.has_meta("reload_rest"):handle.set_meta("reload_rest",handle.position)
		handle.position=handle.get_meta("reload_rest")+Vector3(0,0,.065*maxf(state.get("stroke",0.0),.7 if state.get("locked",false) and not state.get("ready",true) else 0.0))
	var slide=model.find_child("SlidingBolt",true,false)
	if slide:slide.position.z=.065*maxf(state.get("stroke",0.0),.7 if state.get("locked",false) and not state.get("ready",true) else 0.0)
	var ammo=model.find_child("InsertedAmmo",true,false)
	if ammo:ammo.visible=state.get("mag",true)

static func anchor(id:int,key:String) -> Vector3:
	var data:=metadata(id,"cq_shocktroop");var a:Array=data.get(key,[0,0,0])
	return Vector3(a[0],a[1],a[2])

static func ammunition_pose(grip:Transform3D,aim:Transform3D)->Transform3D:
	# Controller grip axes are tilted; insertion and the visible magazine share aim axes.
	return Transform3D(aim.basis.scaled(Vector3.ONE*.65),grip.origin+aim.basis*Vector3(0,-.012,0))
static func split_slide(model:Node3D,key:String)->void:
	var body:MeshInstance3D=model if model is MeshInstance3D else model.find_child(key,true,false)
	if not body or not body.mesh or not body.mesh is ArrayMesh:return
	if not slide_meshes.has(key):
		var parts:=[ArrayMesh.new(),ArrayMesh.new()]
		for surface in body.mesh.get_surface_count():
			var arrays:=body.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i in vertices.size():indices.append(i)
			for part in 2:
				var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);var count:=0
				tool.set_material(body.mesh.surface_get_material(surface))
				for tri in range(0,indices.size(),3):
					var a:int=indices[tri];var b:int=indices[tri+1];var c:int=indices[tri+2]
					var moving:bool=minf(vertices[a].y,minf(vertices[b].y,vertices[c].y))>.075
					if int(moving)!=part:continue
					for index in [a,b,c]:
						if arrays[Mesh.ARRAY_NORMAL]!=null:tool.set_normal(arrays[Mesh.ARRAY_NORMAL][index])
						if arrays[Mesh.ARRAY_TEX_UV]!=null:tool.set_uv(arrays[Mesh.ARRAY_TEX_UV][index])
						var point:Vector3=vertices[index]
						if key=="pistol" and absf(point.x)<.004 and point.y>.17 and absf(point.z+.245)<.008:point.y+=.00035
						tool.add_vertex(point);count+=1
				if count>0:tool.commit(parts[part])
		slide_meshes[key]=parts
	body.mesh=slide_meshes[key][0]
	var slide:=MeshInstance3D.new();slide.name="SlidingBolt";slide.mesh=slide_meshes[key][1];body.add_child(slide)
