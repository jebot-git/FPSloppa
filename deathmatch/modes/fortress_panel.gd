extends PanelContainer
var game
var choice=preload("res://deathmatch/ui/choice.gd").new()
var tool=preload("res://deathmatch/ui/choice.gd").new()
var details: Label
var notice: Label
var title: Label
var tribes_menu:=false
var tribes_shop=preload("res://deathmatch/tribes/buy_wheel.gd").new()
var equipment: GridContainer
var pack_choice=preload("res://deathmatch/ui/choice.gd").new()
var inventory_button: Button
var queue_button: Button
func setup(arena: Node) -> void:
	game=arena;hide();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=preload("res://deathmatch/ui/iron_theme.gd").theme()
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",14);add_child(column)
	title=Label.new();title.text="TF · CHOOSE YOUR CLASS";column.add_child(title)
	column.add_child(choice)
	var classes: Array=[]
	for key in game.match_mode.fortress.CLASSES:classes.append({"id":key,"title":game.match_mode.fortress.CLASSES[key].name})
	choice.configure(classes,"SELECT CLASS");choice.choose("soldier")
	choice.selected.connect(func(value):
		if tribes_menu:tribes_shop.armour=value;tribes_shop.guns=tribes_shop.A.defaults(value);refresh_guns()
		refresh())
	details=Label.new();details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(details)
	column.add_child(tool);tool.configure([{"id":"sentry","title":"ENGINEER: SENTRY"},{"id":"dispenser","title":"ENGINEER: DISPENSER"}],"SELECT BUILD TOOL");tool.choose("sentry")
	choice.trigger.pressed.connect(func():tool.popup.hide());tool.trigger.pressed.connect(func():choice.popup.hide())
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.text="Changes apply at your next respawn. Use E on desktop or weapon-hand A/X (ability binding) in VR for your class action. Engineer: turn-stick up/down selects sentry/dispenser. Class badges identify players regardless of avatar.";column.add_child(notice)
	column.add_child(pack_choice)
	var packs: Array=[]
	for key in tribes_shop.A.PACKS:packs.append({"id":key,"title":tribes_shop.A.PACKS[key].name})
	pack_choice.configure(packs,"BACKPACK");pack_choice.choose("energy")
	pack_choice.selected.connect(func(value):tribes_shop.pack=value;tribes_shop.guns=tribes_shop.guns.filter(func(w):return tribes_shop.A.allowed(tribes_shop.armour,w,value));refresh_guns();refresh())
	equipment=GridContainer.new();equipment.columns=4;column.add_child(equipment)
	inventory_button=Button.new();inventory_button.text="PURCHASE / REFIT AT BASE";inventory_button.custom_minimum_size.y=44;column.add_child(inventory_button)
	inventory_button.pressed.connect(func():game.match_mode.tribes.choose_equipment(choice.value,tribes_shop.guns,pack_choice.value,true))
	queue_button=button(column,"QUEUE CLASS FOR NEXT RESPAWN",func():
		if tribes_menu:game.match_mode.tribes.choose_equipment(choice.value,tribes_shop.guns,pack_choice.value)
		else:game.match_mode.fortress.choose(choice.value,tool.value)
		notice.text="Favourites saved. Purchase at a friendly inventory station." if tribes_menu and game.match_mode.tribes.base_ctf() else "Class selection sent. Changes apply at your next respawn.")
	button(column,"BACK",hide)
func button(parent: Node,text: String,action: Callable) -> Button:
	var b:=Button.new();b.text=text;b.custom_minimum_size.y=52;b.pressed.connect(action);parent.add_child(b);return b
func open() -> void:
	var state: Dictionary=game.local_state()
	tribes_menu=game.match_mode.tribes.enabled()
	queue_button.text="SAVE STATION FAVOURITES" if tribes_menu and game.match_mode.tribes.base_ctf() else "QUEUE CLASS FOR NEXT RESPAWN"
	inventory_button.text="PURCHASE / REFIT AT STATION" if game.match_mode.tribes.base_ctf() else "PURCHASE / REFIT AT BASE"
	title.text="TRIBES · CHOOSE YOUR ARMOUR" if tribes_menu else "TF · CHOOSE YOUR CLASS"
	var classes: Array=[]
	var definitions: Dictionary=game.match_mode.tribes.CLASSES if tribes_menu else game.match_mode.fortress.CLASSES
	for key in definitions:classes.append({"id":key,"title":definitions[key].name})
	choice.configure(classes,"SELECT ARMOUR" if tribes_menu else "SELECT CLASS")
	choice.choose(state.get("tribes_next","light") if tribes_menu else state.get("tf_next","soldier"));tool.choose(state.get("tf_tool","sentry"))
	notice.text="Cost is paid from team energy each respawn. If funds run out, you receive free light armour; your queued choice remains selected. Health shows armour condition; ENERGY powers your jets." if tribes_menu else "Changes apply at your next respawn. Use E on desktop or weapon-hand A/X (ability binding) in VR for your class action. Engineer: turn-stick up/down selects sentry/dispenser. Class badges identify players regardless of avatar."
	if tribes_menu and game.match_mode.tribes.base_ctf():notice.text="You spawn in Light armour with blaster, chaingun and disc. Save favourites here, then walk into a friendly inventory station to buy them. Carried equipment is traded in; ammunition uses the team reserve."
	if tribes_menu and not game.match_mode.tribes.mode_enabled():notice.text="Your selected armour, weapons and backpack apply at the next respawn. ENERGY powers your jets and energy weapons."
	pack_choice.visible=tribes_menu;equipment.visible=tribes_menu;inventory_button.visible=tribes_menu and game.match_mode.tribes.mode_enabled()
	if tribes_menu:
		var packs: Array=[]
		for key in tribes_shop.A.PACKS:
			if game.match_mode.tribes.mode_enabled() or not game.match_mode.tribes.deployables.Data.is_pack(key):packs.append({"id":key,"title":tribes_shop.A.PACKS[key].name})
		pack_choice.configure(packs,"BACKPACK")
		tribes_shop.open(state);pack_choice.choose(tribes_shop.pack);refresh_guns()
	get_parent().move_child(self,-1);refresh();show()
func _process(_delta: float) -> void:
	if visible and tribes_menu:refresh()
func refresh() -> void:
	if tribes_menu:
		var data: Dictionary=game.match_mode.tribes.Armour.definition(choice.value)
		var id: int=game.multiplayer.get_unique_id();var state: Dictionary=game.local_state()
		var available: int=game.match_mode.tribes.energy[game.match_mode.tribes.bank(id)]
		details.text="%d HEALTH · %d ENERGY · %.0f m/s WALK · %d GUNS\n\n%d TEAM ENERGY per spawn · AVAILABLE %d (+700 / 30s)\nCURRENT: %s · NEXT: %s%s"%[data.hp,data.energy,data.walk,data.guns,tribes_shop.A.cost(choice.value,tribes_shop.guns,pack_choice.value),available,state.get("tribes_class","light").to_upper(),state.get("tribes_next","light").to_upper(),"\nINSUFFICIENT FUNDS: light armour fallback" if available<tribes_shop.A.cost(choice.value,tribes_shop.guns,pack_choice.value) else ""]
		if game.match_mode.tribes.base_ctf():details.text="%d HEALTH · %d ENERGY · %.0f m/s WALK · %d GUNS\n\nTEAM ENERGY %d (+700 / 30s) · REFIT %d\nCURRENT: %s · FAVOURITE: %s"%[data.hp,data.energy,data.walk,data.guns,available,game.match_mode.tribes.refit_cost(id,choice.value,tribes_shop.guns,pack_choice.value),state.get("tribes_class","light").to_upper(),state.get("tribes_next","light").to_upper()]
		if not game.match_mode.tribes.mode_enabled():details.text="%d HEALTH · %d ENERGY · %.0f m/s WALK · %d GUNS\n\nCURRENT: %s · NEXT: %s"%[data.hp,data.energy,data.walk,data.guns,state.get("tribes_class","light").to_upper(),state.get("tribes_next","light").to_upper()]
		inventory_button.disabled=not game.match_mode.tribes.can_refit(id) or not tribes_shop.A.valid_loadout(choice.value,tribes_shop.guns,pack_choice.value) or available<game.match_mode.tribes.refit_cost(id,choice.value,tribes_shop.guns,pack_choice.value)
		tool.hide();return
	var key: String=choice.value;var data: Dictionary=game.match_mode.fortress.class_definition(key)
	details.text="%d HEALTH · %d ARMOR · %.0f%% SPEED\n\n%s"%[data.hp,data.armor,data.speed*100,data.action]
	tool.visible=key=="engineer"

func refresh_guns():
	if not equipment:return
	for child in equipment.get_children():child.free()
	for w in 8:
		var b:=CheckButton.new();b.text=tribes_shop.A.NAMES[w];b.button_pressed=w in tribes_shop.guns
		b.disabled=not tribes_shop.A.allowed(tribes_shop.armour,w,tribes_shop.pack) or w not in tribes_shop.guns and tribes_shop.guns.size()>=game.match_mode.tribes.Armour.definition(tribes_shop.armour).guns
		b.toggled.connect(func(on):
			if on:tribes_shop.guns.append(w)
			else:tribes_shop.guns.erase(w)
			refresh_guns.call_deferred();refresh())
		equipment.add_child(b)
