extends Node3D
const Map=preload("res://tools/voxel_battle/map.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
var map
var camera: Camera3D
var panel: CanvasLayer
var status: Label
var selector: OptionButton
var viewpoint: OptionButton
var visor_mode:=0
var visor_effect=preload("res://deathmatch/conquest/classes/night_vision_effect.gd").new()
var benchmarks:=false
var points: Array=[]
func _ready() -> void:
	var world:=WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color(.38,.55,.63)
	world.compositor=Compositor.new();world.compositor.compositor_effects=[visor_effect]
	add_child(world)
	map=Map.new();map.name="JungleTerrain";add_child(map);map.build(true,false)
	camera=$Camera3D;camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;camera.current=true;camera.far=2200;camera.fov=85
	points=[{"name":"Canopy edge","position":Vector3(-1000,0,-300),"direction":Vector3(.8,-.08,-1)}, {"name":"Canyon overlook","position":Vector3(-300,0,180),"direction":Vector3(-1,-.16,-.3)}, {"name":"Mountain foothills","position":Vector3(850,0,-1080),"direction":Vector3(.6,-.12,-1)}]
	points.append({"name":"Prone canopy","position":Vector3(-1000,0,-300),"direction":Vector3(.8,0,-1),"eye_height":.45})
	for site in Landscape.sites():points.append({"name":site.name,"position":site.position,"direction":Vector3(.6,-.2,-1)})
	panel=CanvasLayer.new();add_child(panel)
	var column:=VBoxContainer.new();column.position=Vector2(16,16);panel.add_child(column)
	var title:=Label.new();title.text="JUNGLE FRONTIER · 8 km²\nRMB look · WASD move · Q/E down/up · Shift fast · L site labels";column.add_child(title)
	selector=OptionButton.new()
	for mode in ["mesh","billboard","svo","hybrid"]:selector.add_item(mode)
	selector.selected=3;selector.item_selected.connect(func(i):map.environment.set_mode(selector.get_item_text(i)));column.add_child(selector)
	var lighting_choice:=OptionButton.new()
	for label in ["Day/night cycle · 20 minutes","Day","Golden hour","Dusk","Twilight","Night","Dawn twilight","Dawn","Morning"]:lighting_choice.add_item(label)
	lighting_choice.item_selected.connect(func(i):
		map.lighting.phase_override=-1.0
		if i>0:map.lighting.synchronize([0.0,288.0,348.0,396.0,600.0,804.0,852.0,912.0][i-1])
	);column.add_child(lighting_choice)
	var visor:=OptionButton.new()
	for label in ["Visor off","NVG · standard","NVG · scout"]:visor.add_item(label)
	visor.item_selected.connect(func(i):visor_mode=i);column.add_child(visor)
	var grass_toggle:=CheckButton.new();grass_toggle.text="Hybrid canopy + bushes (no collision)";grass_toggle.button_pressed=true
	grass_toggle.toggled.connect(func(value):map.grass.set_enabled(value));column.add_child(grass_toggle)
	var distance:=OptionButton.new()
	for value in [24,64,96,144]:distance.add_item("Undergrowth %d m"%value)
	distance.selected=2;distance.item_selected.connect(func(i):map.grass.set_distance([24,64,96,144][i]));column.add_child(distance)
	viewpoint=OptionButton.new()
	for point in points:viewpoint.add_item(point.name)
	viewpoint.item_selected.connect(set_view);column.add_child(viewpoint)
	status=Label.new();column.add_child(status);viewpoint.selected=0;set_view(0)
	if "--poi-night" in OS.get_cmdline_user_args():
		viewpoint.select(8);set_view(8);lighting_choice.select(5);map.lighting.synchronize(600)
		camera.position=Landscape.CENTERS[4]+Vector3(0,1.7,48);camera.look_at(Landscape.CENTERS[4]+Vector3(0,1.7,10))
func set_view(index: int) -> void:
	var point: Dictionary=points[index]
	var p: Vector3=point.position
	p.y=Landscape.surface(p.x,p.z).x+point.get("eye_height",1.7)
	camera.position=p;camera.look_at(p+point.direction,Vector3.UP)
func _process(delta: float) -> void:
	visor_effect.enabled=visor_mode>0
	if visor_effect.enabled:visor_effect.configure(lerpf(6000,1.3,map.lighting.light_fraction()),visor_mode==2,0,Time.get_ticks_msec()/1000.0)
	if not benchmarks:
		var move:=Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		camera.position+=camera.basis*move*delta*(160 if Input.is_physical_key_pressed(KEY_SHIFT) else 25)
		camera.position.x=clampf(camera.position.x,-Map.LIMIT,Map.LIMIT);camera.position.z=clampf(camera.position.z,-Map.LIMIT,Map.LIMIT)
		map.update_view(camera)
		status.text="%.1f ms · %d terrain tiles · %d/%d visible/resident plants · %d foliage draws\nGrass: %d/%d tuft cap · %d draws · %.2f ms update\n%s · camera %.0f, %.0f, %.0f"%[delta*1000,map.terrain.resident.size(),map.environment.visible_features,map.environment.resident_features,map.environment.draw_calls,map.grass.visible_tufts,map.grass.CAPACITY,map.grass.draw_calls,map.grass.update_ms,map.environment.render_mode,camera.position.x,camera.position.y,camera.position.z]
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.rotation.y-=event.relative.x*.003;camera.rotation.x=clampf(camera.rotation.x-event.relative.y*.003,-1.5,1.5)
	if event is InputEventKey and event.pressed and event.keycode==KEY_L:
		for child in map.get_children():
			if child is Label3D:child.visible=not child.visible

func _exit_tree() -> void:
	visor_effect.enabled=false
	if DisplayServer.get_name()!="headless":RenderingServer.call_on_render_thread(visor_effect.release)
