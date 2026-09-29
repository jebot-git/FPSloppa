extends SceneTree
const Props=preload("res://deathmatch/tribes/prop_library.gd")
var stage: Node3D
var camera: Camera3D
var display: Node3D
func _initialize():run.call_deferred()
func shot(name: String):
	for frame in 6:await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://test-results/st-equipment-design/"+name+".png")==OK)
func clear():
	if is_instance_valid(display):display.free()
	display=Node3D.new();stage.add_child(display)
func run():
	root.size=Vector2i(1440,900);root.title="ST equipment design review"
	stage=Node3D.new();root.add_child(stage)
	var world:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("17202a");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("c1cbd5");env.ambient_light_energy=.75;world.environment=env;stage.add_child(world)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);light.light_energy=1.7;stage.add_child(light)
	camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true
	var groups: Dictionary={"stations":["station_inventory","station_ammo","station_command","station_vehicle"],"turrets":["fixed_fusion","fixed_mini","fixed_elf","fixed_missile","fixed_mortar"],"deployables":["turret","inventory","ammo_station","pulse","motion","remote_jammer","camera","beacon"],"power":["generator","portable_generator","solar"],"sensors":["base_sensor","large_sensor"]}
	for group in groups:
		clear();var kinds: Array=groups[group];var small: bool=group=="deployables";var spacing: float=2.1 if small else 8.3 if group in ["power","sensors"] else 4.3
		for i in kinds.size():
			var model=Props.make(kinds[i],i%2);display.add_child(model);model.position.x=(i-(kinds.size()-1)*.5)*spacing
			if small:model.position=Vector3((i%4-1.5)*3,0,(i/4)*3.3)
			if group=="power":model.rotation.y=PI;model.position.y=1.6
			var label:=Label3D.new();label.text=str(kinds[i]).replace("station_","").replace("fixed_","").replace("_"," ").to_upper();label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=36;label.pixel_size=.005 if small else .012;display.add_child(label);label.position=model.position+Vector3(0,1.65 if small else 6.7 if group=="sensors" else 4.1,0)
		camera.size=9 if small else maxf(5,kinds.size()*spacing*.80);camera.position=Vector3(2,8 if small else 10,-13 if small else -22);camera.look_at(Vector3(0,.6 if small else 1.8,1.65 if small else 0));await shot(group)
	# Readable close-ups and moving-head / disabled-state inspection.
	for kind in ["station_inventory","fixed_fusion","fixed_missile","fixed_elf","fixed_mortar","turret","inventory","pulse","remote_jammer","generator","base_sensor","camera"]:
		clear();var item=Props.make(kind,0);display.add_child(item)
		if kind=="generator":item.rotation.y=PI;item.position.y=1.6
		if item.has_node("Head"):item.get_node("Head").rotation_degrees=Vector3(12,20,0)
		var big: bool=kind.begins_with("fixed_") or kind.begins_with("station_") or kind in ["generator","base_sensor"]
		camera.size=8 if kind=="base_sensor" else 7 if kind=="generator" else 5.5 if big else 2.0
		var center:=Vector3(0,2.9 if kind=="base_sensor" else 1.6 if big else .65,0)
		camera.position=center+Vector3(3,2,-6);camera.look_at(center);await shot("detail-"+kind)
		if kind=="station_inventory":Props.set_active(item,false);await shot("station-offline")
	clear()
	var canvas:=CanvasLayer.new();root.add_child(canvas)
	var icons=["remote_turret","remote_inventory","remote_ammo","pulse_sensor","motion_sensor","remote_jammer","remote_camera"]
	for i in icons.size():
		var icon:=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.texture=load("res://deathmatch/weapons/tribes/tribes_"+icons[i]+".res");assert(icon.texture.get_image().has_mipmaps());icon.position=Vector2(96+i*178,350);icon.size=Vector2(160,160);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;canvas.add_child(icon)
		var label:=Label.new();label.text=icons[i].replace("_"," ").to_upper();label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.position=Vector2(86+i*178,525);label.size=Vector2(180,40);canvas.add_child(label)
	await shot("purchase-icons");canvas.free()
	print("ST_PROPS_PREVIEW_PASS");stage.free();quit()
