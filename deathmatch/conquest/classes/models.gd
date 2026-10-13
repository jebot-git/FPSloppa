extends RefCounted
static var manifest:Dictionary={}
static func entry(id:int,rules:String) -> String:
	if id==6:return "health_box" if rules=="cq_medic" else "ammo_box"
	if id==7:return "injector" if rules=="cq_medic" else "repair_kit"
	return {0:"burst_pistol",1:"assault_rifle",2:"pistol",3:"smg",4:"carbine",5:"massacre",8:"designator",9:"scout_pistol",10:"beam_pistol",11:"guided_launcher"}.get(id,"pistol")
static func metadata(id:int,rules:String) -> Dictionary:
	if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/weapons/cq/manifest.json"))
	return manifest.get(entry(id,rules),{})
static func weapon(id:int,rules:String) -> Node3D:
	var node:Node3D=load("res://deathmatch/weapons/cq/"+entry(id,rules)+".glb").instantiate()
	var data:=metadata(id,rules)
	for key in ["scope_rear","scope_front"]:
		if data.has(key):node.set_meta(key,Vector3(data[key][0],data[key][1],data[key][2]))
	if data.has("scope_radius"):node.set_meta("scope_radius",data.scope_radius);node.set_meta("cq_zoom",true)
	if data.has("zoom_steps"):node.set_meta("zoom_steps",data.zoom_steps)
	if data.get("red_dot",false):node.set_meta("red_dot",true)
	if id in [0,3,4,8]:
		var dot:=MeshInstance3D.new();var aperture:=QuadMesh.new();aperture.size=Vector2(.016,.016);dot.mesh=aperture
		var finish:=ShaderMaterial.new();finish.shader=preload("res://deathmatch/conquest/classes/red_dot.gdshader");dot.material_override=finish;dot.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(dot);dot.name="AlignedRedDot";dot.position=Vector3(0,.234 if id==4 else .164,-.09)
		if data.has("red_dot_position"):
			var p:Array=data.red_dot_position;dot.position=Vector3(p[0],p[1],p[2])
	if id==5 and not node.find_child("InsertedAmmo",true,false):
		var ammo:=ammunition(node,id);node.add_child(ammo);ammo.name="InsertedAmmo";ammo.position=Vector3(-.08,.015,.02)
	if id in [5,11]:
		var monitor:=Label3D.new();monitor.name="GuidanceMonitor";monitor.text="SALVO" if id==5 else "SEARCH";monitor.font_size=32;monitor.pixel_size=.00042;monitor.modulate=Color("65ddd5");monitor.no_depth_test=false
		var p:Array=data.get("monitor_position",[0,.1,-.09]);monitor.position=Vector3(p[0],p[1],p[2]);node.add_child(monitor)
	return node
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
		handle.position=handle.get_meta("reload_rest")+Vector3(0,0,.065*state.get("stroke",0.0))
	var ammo=model.find_child("InsertedAmmo",true,false)
	if ammo:ammo.visible=state.get("mag",true)
