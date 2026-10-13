extends Window
var service
var library
var options
var detail: Label
var feedback: Label
var stage: Node3D
var preview: Node3D
var viewport: SubViewport
var chooser: PanelContainer
var apply_button: Button
var hashes: Array = []
var current := ""
var preview_hash:=""
var preview_request:=0
var preview_button: Button
var animation_mode := 0
var rotating := true
var skin_dialog:PanelContainer
var skin_model
var skin_group
var skin_face
var skin_status:Label
var skin_import_button:Button
var skin_package:Dictionary={}
var skin_templates:Dictionary={}
var skin_recognition:Dictionary={}

func setup(network: Node) -> void:
	theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	service = network
	library = service.library
	title = "FPSloppa / PLAYER MODEL"
	size = Vector2i(1000,760)
	min_size = Vector2i(740,640)
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
	options = preload("res://deathmatch/ui/drag_list.gd").new()
	options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options.item_selected.connect(func(index): select_model(hashes[index]))
	left.add_child(options)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.max_lines_visible=10
	detail.custom_minimum_size = Vector2(250,130)
	left.add_child(detail)
	preview_button=add_button(left,"LOAD SELECTED PREVIEW",func():show_model(current))
	add_button(left,"IMPORT .utx SKIN…",func(): chooser.open())
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
	var animation:=preload("res://deathmatch/ui/choice.gd").new();animation.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var clips: Array=[]
	for i in 4:clips.append({"id":str(i),"title":["Idle","Walk","Run","Fire"][i]})
	animation.configure(clips,"ANIMATION");animation.choose("0")
	animation.selected.connect(func(value):
		animation_mode=int(value)
		if preview:preview.preview_mode=animation_mode)
	controls.add_child(animation)
	var rotate := CheckButton.new()
	rotate.text = "Rotate"
	rotate.button_pressed = true
	rotate.toggled.connect(func(value): rotating = value)
	controls.add_child(rotate)
	var weapons:=preload("res://deathmatch/ui/choice.gd").new();weapons.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var weapon_items: Array=[]
	for i in preload("res://deathmatch/weapons.gd").DATA.size():weapon_items.append({"id":str(i),"title":preload("res://deathmatch/weapons.gd").DATA[i].name})
	weapons.configure(weapon_items,"WEAPON");weapons.choose("2")
	weapons.selected.connect(func(value):
		if preview:preview.set_weapon(int(value)))
	controls.add_child(weapons)
	animation.trigger.pressed.connect(func():weapons.popup.hide());weapons.trigger.pressed.connect(func():animation.popup.hide())
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 45
	feedback.text = "All models: 1.70 m visual height · identical collision and damage hitbox."
	column.add_child(feedback)
	var hint := Label.new()
	hint.text = "UTX skins: up to 25 MB. Imported skins use a prepared UT99 base model.
Selected avatars are shared with match participants.\nOnly import models you have permission to use and share."
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
	chooser = preload("res://deathmatch/ui/file_browser.gd").new()
	add_child(chooser)
	chooser.setup("utx","IMPORT UTX SKIN · MAXIMUM 25 MB")
	chooser.file_selected.connect(import_skin_package)
	setup_skin_dialog()
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
	detail.text="%s\n\n%s\nUT99 %s · %.1f MB\n%s"%[info.title,info.author,info.version,float(info.size)/1_000_000,info.license]
	detail.tooltip_text=detail.text
	apply_button.disabled=false;preview_button.disabled=false
	if is_instance_valid(preview):preview.visible=preview_hash==hash
	feedback.text="Selected. Use this model directly, or load its 3D preview."
func show_model(hash: String) -> void:
	if not library.entries.has(hash) or not visible:return
	if preview_hash==hash and is_instance_valid(preview):preview.show();return
	preview_request+=1;var request:=preview_request
	preview_button.disabled=true;feedback.text="Loading selected UT99 preview…"
	# Paint feedback first; cancel superseded requests before expensive plugin work.
	await get_tree().create_timer(.15).timeout
	if request!=preview_request or not visible or current!=hash:return
	var model: Node3D=library.create_avatar(hash)
	preview_button.disabled=false
	if not model:feedback.text=library.last_error;return
	if is_instance_valid(preview):preview.queue_free()
	preview=model;preview_hash=hash;stage.add_child(preview);preview.preview_mode=animation_mode
	feedback.text="1.70 m visual height · identical collision and damage hitbox."

func setup_skin_dialog() -> void:
	skin_dialog=PanelContainer.new();add_child(skin_dialog)
	skin_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skin_dialog.offset_left=40;skin_dialog.offset_top=40;skin_dialog.offset_right=-40;skin_dialog.offset_bottom=-40
	skin_dialog.add_theme_stylebox_override("panel",preload("res://deathmatch/ui/iron_theme.gd").panel(20))
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);skin_dialog.add_child(column)
	var label:=Label.new();label.text="IMPORT UTX SKIN";label.add_theme_font_size_override("font_size",24);column.add_child(label)
	var hint:=Label.new();hint.text="Check the suggested base model, then choose the skin family and face. You can override the model.";hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(hint)
	skin_model=preload("res://deathmatch/ui/choice.gd").new();column.add_child(skin_model)
	skin_group=preload("res://deathmatch/ui/choice.gd").new();column.add_child(skin_group)
	skin_face=preload("res://deathmatch/ui/choice.gd").new();column.add_child(skin_face)
	skin_model.selected.connect(func(_value):update_skin_groups())
	skin_group.selected.connect(func(_value):update_skin_faces())
	skin_face.selected.connect(func(_value):skin_import_button.disabled=skin_face.value.is_empty())
	skin_status=Label.new();skin_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(skin_status)
	var spacer:=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(spacer)
	skin_import_button=add_button(column,"IMPORT SELECTED SKIN",finish_skin_import)
	add_button(column,"CANCEL",func():close_skin_dialog())
	skin_dialog.hide()
func close_skin_dialog() -> void:
	for choice in [skin_model,skin_group,skin_face]:choice.close_popup()
	skin_dialog.hide();skin_package.clear()
func import_skin_package(path:String) -> void:
	feedback.text="Reading UTX skin package…"
	await get_tree().process_frame
	if not visible:return
	skin_package=preload("res://deathmatch/avatars/utx.gd").read(path)
	if skin_package.has("error"):feedback.text=skin_package.error;skin_package.clear();return
	skin_templates=library.base_templates()
	var names:={"Soldier":"Male Soldier","Commando":"Male Commando","SGirl":"Female Soldier","FCommando":"Female Commando","Boss":"Boss / Xan"}
	var items:Array=[]
	for model in names:
		if skin_templates.has(model):items.append({"id":model,"title":names[model]})
	skin_model.configure(items,"BASE MODEL")
	var fallback:String=library.entries.get(current,{}).get("base_model","Soldier")
	skin_recognition=preload("res://deathmatch/avatars/skin_import.gd").recognize(skin_package,skin_templates.keys(),fallback)
	skin_dialog.show();skin_dialog.move_to_front();skin_model.choose(skin_recognition.model)

func update_skin_groups() -> void:
	var groups:=preload("res://deathmatch/avatars/skin_import.gd").groups(skin_package,skin_model.value)
	var items:Array=[]
	for group in groups:items.append({"id":group,"title":group})
	skin_group.configure(items,"SKIN FAMILY")
	skin_status.text="No complete skin family for this model. Choose the matching base model." if groups.is_empty() else "Skin: "+skin_package.filename+" · model keeps its animations and constrained IK."
	if not skin_recognition.is_empty():
		var recognition:String="Suggested: "+skin_recognition.model+" ("+skin_recognition.confidence+"). "+skin_recognition.reason
		if skin_model.value!=skin_recognition.model:recognition+=" Manual override: "+skin_model.value+"."
		skin_status.text=recognition+"\n"+skin_status.text
	skin_import_button.disabled=groups.is_empty()
	if groups.is_empty():skin_face.configure([],"FACE")
	else:skin_group.choose(groups[0])
func update_skin_faces() -> void:
	var faces:=preload("res://deathmatch/avatars/skin_import.gd").faces(skin_package,skin_model.value,skin_group.value)
	var items:Array=[]
	for face in faces:items.append({"id":face,"title":skin_package.textures[face].name})
	skin_face.configure(items,"FACE")
	skin_import_button.disabled=faces.is_empty()
	if not faces.is_empty():
		var chosen:String=faces[0]
		for face in faces:
			if face.length()>skin_group.value.length()+1:chosen=face;break
		skin_face.choose(chosen)
func finish_skin_import() -> void:
	skin_import_button.disabled=true;skin_status.text="Preparing skin and checking avatar…"
	await get_tree().process_frame
	if not visible or not skin_dialog.visible or skin_package.is_empty():return
	var hash:String=library.register_skin(skin_package,skin_templates.get(skin_model.value,""),skin_group.value,skin_face.value)
	if hash.is_empty():skin_status.text=library.last_error;skin_import_button.disabled=false;return
	close_skin_dialog();refresh();options.select(hashes.find(hash));select_model(hash)
	show_model(hash)

func _process(delta: float) -> void:
	if visible and preview and rotating: preview.rotation.y += delta*.35
