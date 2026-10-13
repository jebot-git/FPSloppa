extends RefCounted
static var manifest:Dictionary={}
static func entry(id:int,rules:String) -> String:
	if id==6:return "health_box" if rules=="cq_medic" else "ammo_box"
	if id==7:return "injector" if rules=="cq_medic" else "repair_kit"
	return {2:"pistol",4:"carbine",5:"massacre",8:"designator",9:"scout_pistol"}.get(id,"pistol")
static func metadata(id:int,rules:String) -> Dictionary:
	if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/weapons/cq/manifest.json"))
	return manifest.get(entry(id,rules),{})
static func weapon(id:int,rules:String) -> Node3D:
	var node:Node3D=load("res://deathmatch/weapons/cq/"+entry(id,rules)+".glb").instantiate()
	var data:=metadata(id,rules)
	for key in ["scope_rear","scope_front"]:
		if data.has(key):node.set_meta(key,Vector3(data[key][0],data[key][1],data[key][2]))
	if data.has("scope_radius"):node.set_meta("scope_radius",data.scope_radius);node.set_meta("cq_zoom",true)
	if id in [4,8]:
		var dot:=MeshInstance3D.new();var aperture:=QuadMesh.new();aperture.size=Vector2(.016,.016);dot.mesh=aperture
		var finish:=ShaderMaterial.new();finish.shader=preload("res://deathmatch/conquest/classes/red_dot.gdshader");dot.material_override=finish;dot.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(dot);dot.name="AlignedRedDot";dot.position=Vector3(0,.234 if id==4 else .164,-.09)
	if id==5:
		var ammo:=ammunition(node,id);node.add_child(ammo);ammo.name="InsertedAmmo";ammo.position=Vector3(-.08,.015,.02)
	return node
static func ammunition(model:Node3D,id:int) -> MeshInstance3D:
	var result:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(.032,.085,.03) if id in [2,9] else Vector3(.06,.055,.06) if id==5 else Vector3(.034,.065,.034);result.mesh=mesh
	var surfaces:=model.find_children("*","MeshInstance3D",true,false)
	if not surfaces.is_empty():result.material_override=surfaces[0].get_active_material(0)
	return result
static func muzzle(id:int,rules:String) -> Vector3:
	var p:Array=metadata(id,rules).get("muzzle",[0,0,-.2]);return Vector3(p[0],p[1],p[2])

static func animate_reload(model:Node3D,state:Dictionary) -> void:
	if not is_instance_valid(model):return
	var handle=model.find_child("ChargingHandle",true,false)
	if handle:handle.position.z=.065*state.get("stroke",0.0)
	var ammo=model.find_child("InsertedAmmo",true,false)
	if ammo:ammo.visible=state.get("mag",true)
