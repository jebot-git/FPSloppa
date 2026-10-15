extends Node
## Class → loadout navigation, with server-authoritative next-spawn equipment.
var game
var hud
var selected_class:="shocktroop"
var buttons:Array=[]
var summary:Label
var pending:=false
var calibration_confirmed:=false
var calibration_skin:=""
var deploy_button:Button
func setup(arena,interface) -> void:
	game=arena;hud=interface
	var pages=hud.menu_pages
	var classes_page=pages.add_page("cq_classes","CLASS SELECTION","player")

	for role in game.classes.CLASSES:
		hud.button(classes_page,role.to_upper(),choose_class.bind(role))
	var loadout=pages.add_page("cq_loadout","LOADOUT","cq_classes")
	summary=Label.new();summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;loadout.add_child(summary)
	hud.button(loadout,"CHANGE CLASS",func():pages.navigate("cq_classes"))
	for slot in ["PRIMARY","SECONDARY","UTILITY"]:
		var slot_page=pages.add_page("cq_"+slot.to_lower(),slot+" EQUIPMENT","cq_loadout")
		pages.link("cq_loadout","cq_"+slot.to_lower(),slot+" EQUIPMENT")
		for role in game.classes.CLASSES:
			var rows:Array=game.classes.UTILITIES[role] if slot=="UTILITY" else (game.classes.progression.secondaries if slot=="SECONDARY" else game.classes.progression.tracks)[role]
			for row in rows:
				var value=row.id if slot=="UTILITY" else row.weapon
				var button:Button=hud.button(slot_page,"",select.bind(role,slot,value))
				buttons.append({"button":button,"role":role,"slot":slot,"value":value,"xp":row.get("xp",0),"name":row.name if slot=="UTILITY" else game.armory.data(value).name,"tier":row.get("tier",1) if slot=="UTILITY" else 1 if row.xp==0 else 2})
	hud.button(loadout,"REVIEW DEPLOYMENT",func():game.squads.open_map() if game.active else pages.navigate("cq_prepare"))
	var preparation=pages.add_page("cq_prepare","PREPARE TO DEPLOY","home")
	hud.button(preparation,"CLASS AND LOADOUT",func():pages.navigate("cq_classes"))
	hud.button(preparation,"CHOOSE SKIN",hud.avatar_picker.open)
	hud.button(preparation,"CALIBRATE AND PREVIEW AVATAR",func():pages.navigate("cq_calibrate"))
	deploy_button=hud.button(preparation,"DEPLOY",deploy)
	var calibration=pages.add_page("cq_calibrate","AVATAR CALIBRATION","cq_prepare")
	var preview=preload("res://deathmatch/vr/calibration_preview.gd").new();calibration.add_child(preview);preview.setup(game)
	hud.button(calibration,"BACK TO DEPLOYMENT",func():game.squads.open_map() if game.active else pages.navigate("cq_prepare"))
	refresh()
func begin_deployment()->void:
	pending=true;calibration_confirmed=false;selected_class=game.classes.ensure(game.multiplayer.get_unique_id()).get("next","shocktroop");game.menu_open=true;hud.show_menu(true);hud.menu_pages.navigate("cq_prepare");refresh()
func deploy()->void:
	if game.active and game.squads:game.squads.open_map();return
	refresh()
	if pending and not calibration_confirmed:return
	if pending:game.resident.request(10)
	pending=false;game.menu_open=false;hud.show_menu(false)
func choose_class(role:String) -> void:
	selected_class=role;game.request_class(role);refresh()
	if game.active:game.squads.open_map()
	else:hud.menu_pages.navigate("cq_loadout")
func select(role:String,slot:String,value:Variant) -> void:
	if slot=="UTILITY":game.request_utility(role,value)
	else:game.request_equipment(role,value,slot=="SECONDARY")
	refresh()
func refresh() -> void:
	if calibration_confirmed and calibration_skin!=game.avatars.library.selected:calibration_confirmed=false
	if deploy_button:
		deploy_button.disabled=not game.active;deploy_button.text="JOIN A MATCH TO DEPLOY" if not game.active else "TACTICAL DEPLOYMENT"
	var state:Dictionary=game.classes.states.get(game.multiplayer.get_unique_id(),{})
	var xp:int=state.get("xp",{}).get(selected_class,0)
	summary.text=selected_class.to_upper()+" · LEVEL %d · %d CLASS XP\nChoices apply on your next spawn. T2 utility kits unlock at level 15.\nNVG visor included · offhand trigger above forehead · N on desktop."%[game.classes.progression.level(xp),xp]
	if state.is_empty():summary.text+="\nJoin or start a match to select equipment."
	for row in buttons:
		row.button.visible=row.role==selected_class
		row.button.disabled=state.is_empty() or xp<row.xp
		var choice=state.get("utility_choices",{}).get(row.role,game.classes.UTILITIES[row.role][0].id) if row.slot=="UTILITY" else state.get("secondary_choices" if row.slot=="SECONDARY" else "primary_choices",{}).get(row.role,8 if row.role=="scout" else 2) if row.slot=="SECONDARY" else state.get("primary_choices",{}).get(row.role,game.classes.progression.STARTERS[row.role][0])
		row.button.text=("✓ " if row.value==choice else "")+"T%d · "%row.tier+row.name+(" · LOCKED LEVEL %d · %d / %d XP"%[game.classes.progression.level(row.xp),xp,row.xp] if xp<row.xp else "")
