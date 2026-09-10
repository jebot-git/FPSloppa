extends Window
var service
var library
var options: ItemList
var detail: Label
var feedback: Label
var stage: Node3D
var preview: Node3D
var viewport: SubViewport
var chooser: FileDialog
var apply_button: Button
var hashes: Array = []
var current := ""
var preview_hash:=""
var preview_request:=0
var preview_button: Button
var animation_mode := 0
var rotating := true

func setup(network: Node) -> void:
	theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	service = network
	library = service.library
	title = "FPSloppa / PLAYER MODEL"
	size = Vector2i(940,640)
	min_size = Vector2i(740,540)
	transient = true
	exclusive = true
	close_requested.connect(hide)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var title_label := Label.new()
	title_label.text = "CHOOSE YOUR COMBATANT"
	title_label.add_theme_font_size_override("font_size",24)
	column.add_child(title_label)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 260
	row.add_child(left)
	options = ItemList.new()
	options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options.item_selected.connect(func(index): select_model(hashes[index]))
	left.add_child(options)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(250,130)
	left.add_child(detail)
	preview_button=add_button(left,"LOAD SELECTED PREVIEW",func():show_model(current))
	add_button(left,"IMPORT .VRM…",func(): chooser.popup_centered_ratio(.8))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.custom_minimum_size = Vector2(400,350)
	right.add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.size = Vector2i(580,440)
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("102129")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c3d8e6")
	env.environment.ambient_light_energy = .3
	stage.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35,-30,0)
	key.light_energy = .7
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20,150,0)
	fill.light_color = Color("91cbef")
	fill.light_energy = .25
	stage.add_child(fill)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0,1.05,-3.5)
	camera.look_at(Vector3(0,.90,0))
	camera.fov = 37
	var floor_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .9
	cylinder.bottom_radius = .94
	cylinder.height = .06
	floor_mesh.mesh = cylinder
	floor_mesh.position.y = -.04
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("365760")
	material.metallic = .5
	material.roughness = .5
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	var controls := HBoxContainer.new()
	right.add_child(controls)
	var animation := OptionButton.new()
	for clip in ["Idle","Walk","Run","Fire"]: animation.add_item(clip)
	animation.item_selected.connect(func(index):
		animation_mode = index
		if preview: preview.preview_mode = animation_mode
	)
	controls.add_child(animation)
	var rotate := CheckButton.new()
	rotate.text = "Rotate"
	rotate.button_pressed = true
	rotate.toggled.connect(func(value): rotating = value)
	controls.add_child(rotate)
	var weapons := OptionButton.new()
	for item in preload("res://deathmatch/weapons.gd").DATA: weapons.add_item(item.name)
	weapons.select(2)
	weapons.item_selected.connect(func(index):
		if preview: preview.set_weapon(index)
	)
	controls.add_child(weapons)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 45
	feedback.text = "All models: 1.70 m visual height · identical collision and damage hitbox."
	column.add_child(feedback)
	var hint := Label.new()
	hint.text = "Custom VRMs: up to 25 MB. Selected files are shared with match participants.\nOnly import models you have permission to use and share."
	hint.add_theme_font_size_override("font_size",13)
	column.add_child(hint)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	apply_button = add_button(actions,"USE THIS MODEL",func():
		library.choose(current)
		service.offered = ""
		hide()
	)
	add_button(actions,"BACK",hide)
	chooser = FileDialog.new()
	chooser.access = FileDialog.ACCESS_FILESYSTEM
	chooser.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	chooser.filters = PackedStringArray(["*.vrm ; VRM humanoid avatar"])
	chooser.title = "Import VRM · maximum 25 MB"
	add_child(chooser)
	chooser.file_selected.connect(import_model)
	visibility_changed.connect(func():
		if not visible:preview_request+=1;preview_button.disabled=false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
		viewport.process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED
	)
	hide()

func add_button(parent: Node, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 36
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func open() -> void:
	refresh()
	popup_centered()
	select_model(library.selected)

func refresh() -> void:
	options.clear()
	hashes = library.entries.keys()
	for hash in hashes:
		options.add_item(library.entries[hash].title)
		if hash==library.selected: options.select(options.item_count-1)

func select_model(hash: String) -> void:
	preview_request+=1
	current=hash
	if not library.entries.has(hash):apply_button.disabled=true;preview_button.disabled=true;return
	var info: Dictionary=library.entries[hash]
	detail.text="%s\n\n%s\nVRM %s · %.1f MB\n%s"%[info.title,info.author,info.version,float(info.size)/1_000_000,info.license]
	apply_button.disabled=false;preview_button.disabled=false
	if is_instance_valid(preview):preview.visible=preview_hash==hash
	feedback.text="Selected. Use this model directly, or load its 3D preview."
func show_model(hash: String) -> void:
	if not library.entries.has(hash) or not visible:return
	if preview_hash==hash and is_instance_valid(preview):preview.show();return
	preview_request+=1;var request:=preview_request
	preview_button.disabled=true;feedback.text="Loading selected VRM preview…"
	# Paint feedback first; cancel superseded requests before expensive plugin work.
	await get_tree().create_timer(.15).timeout
	if request!=preview_request or not visible or current!=hash:return
	var model: Node3D=library.create_avatar(hash)
	preview_button.disabled=false
	if not model:feedback.text=library.last_error;return
	if is_instance_valid(preview):preview.queue_free()
	preview=model;preview_hash=hash;stage.add_child(preview);preview.preview_mode=animation_mode
	feedback.text="1.70 m visual height · identical collision and damage hitbox."

func import_model(path: String) -> void:
	feedback.text = "Checking VRM…"
	await get_tree().process_frame
	var hash: String = library.register_file(path)
	if hash.is_empty():
		feedback.text = library.last_error
		return
	refresh()
	options.select(hashes.find(hash))
	select_model(hash)

func _process(delta: float) -> void:
	if visible and preview and rotating: preview.rotation.y += delta*.35
