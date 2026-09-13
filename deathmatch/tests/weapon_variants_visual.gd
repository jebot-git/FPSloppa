extends SceneTree
const Art=preload("res://deathmatch/art.gd")
const Rules=preload("res://deathmatch/experimental/weapon_rules.gd")
var failures: Array=[]
func _initialize():run.call_deferred()
func label(parent: Node3D,text: String,position: Vector3,size: int=34) -> void:
	var node:=Label3D.new();node.text=text;node.font_size=size;node.pixel_size=.004;node.position=position;node.no_depth_test=true;parent.add_child(node)
func run() -> void:
	root.size=Vector2i(1920,1080)
	root.content_scale_size=Vector2i(1920,1080)
	var stage:=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();var settings:=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("12151b");settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("ced8eb");settings.ambient_light_energy=.7;env.environment=settings;stage.add_child(env)
	var lamp:=DirectionalLight3D.new();lamp.rotation_degrees=Vector3(-40,-25,0);lamp.light_energy=1.4;stage.add_child(lamp)
	var camera:=Camera3D.new();camera.position=Vector3(0,0,15);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=16;stage.add_child(camera)
	for column in 3:
		var rules:=Rules.new();rules.select(Rules.IDS[column])
		label(stage,rules.NAMES[rules.kind],Vector3((column-1)*5.2,3.6,0),48)
		var slots: Array=[0,2,3,4,5,6,7,8,9] if rules.kind=="quake" else range(rules.table.size())
		for index in slots.size():
			var slot: int=slots[index]
			var model:=Art.weapon(slot,2,rules.kind);stage.add_child(model)
			model.position=Vector3((column-1)*5.2+(index%2-.5)*2.3,2.15-(index/2)*1.13,0)
			model.rotation_degrees=Vector3(8,65,-8);model.scale=Vector3.ONE*1.8
			label(stage,rules.data(slot).name,model.position+Vector3(0,-.44,.5),30)
			if not model.has_meta("muzzle"):failures.append("Missing muzzle "+rules.kind+str(slot))
	var axe:=Art.weapon(0,2,"quake");stage.add_child(axe)
	var asset: Node3D=axe.get_child(0)
	var edge: Vector3=asset.get_meta("cutting_edge")
	if absf(edge.x)>.01 or edge.z>-.30:failures.append("Axe cutting edge must face forward, not sideways")
	axe.free()
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	var path:="res://test-results/weapon-variants/weapons.png";root.get_texture().get_image().save_png(path)
	# Every raw experimental WAV is readable without editor import, including exports.
	var bank=load("res://deathmatch/audio/spatial.gd").new()
	for rules in ["quake","ut99"]:
		for slot in (10 if rules=="quake" else 12):
			for alt in ["","_alt"]:
				var stream=bank.choose(rules+"_weapon_"+str(slot)+alt)
				if not stream or stream.get_length()<=0:failures.append("Unreadable sound "+rules+str(slot)+alt)
	bank.free()
	print("VARIANT_VISUAL_RESULT ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"image":path}))
	stage.free();quit(0 if failures.is_empty() else 1)
