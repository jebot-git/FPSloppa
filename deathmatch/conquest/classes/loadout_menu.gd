extends Node
## Class → loadout navigation, with server-authoritative next-spawn equipment.
var game
var hud
var selected_class:="shocktroop"
var buttons:Array=[]
var summary:Label
func setup(arena,interface) -> void:
	game=arena;hud=interface
	var pages=hud.menu_pages
	var classes_page=pages.add_page("cq_classes","CLASS SELECTION","player")
	pages.link("player","cq_classes","CLASS AND LOADOUT")
	for role in game.classes.CLASSES:
		hud.button(classes_page,role.to_upper(),choose_class.bind(role))
	var loadout=pages.add_page("cq_loadout","LOADOUT","cq_classes")
	summary=Label.new();summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;loadout.add_child(summary)
	hud.button(loadout,"CHANGE CLASS",func():pages.navigate("cq_classes"))
	for slot in ["PRIMARY","SECONDARY","UTILITY"]:
		var label:=Label.new();label.text=slot;label.add_theme_font_size_override("font_size",22);loadout.add_child(label)
		for role in game.classes.CLASSES:
			var rows:Array=game.classes.UTILITIES[role] if slot=="UTILITY" else (game.classes.progression.secondaries if slot=="SECONDARY" else game.classes.progression.tracks)[role]
			for row in rows:
				var value=row.id if slot=="UTILITY" else row.weapon
				var button:Button=hud.button(loadout,"",select.bind(role,slot,value))
				buttons.append({"button":button,"role":role,"slot":slot,"value":value,"xp":row.get("xp",0),"name":row.name if slot=="UTILITY" else game.armory.data(value).name,"tier":row.get("tier",1) if slot=="UTILITY" else 1 if row.xp==0 else 2})
	hud.button(loadout,"DONE · NEXT SPAWN",func():pages.navigate("cq_classes"))
	refresh()
func choose_class(role:String) -> void:
	selected_class=role;game.request_class(role);refresh();hud.menu_pages.navigate("cq_loadout")
func select(role:String,slot:String,value:Variant) -> void:
	if slot=="UTILITY":game.request_utility(role,value)
	else:game.request_equipment(role,value,slot=="SECONDARY")
	refresh()
func refresh() -> void:
	var state:Dictionary=game.classes.states.get(game.multiplayer.get_unique_id(),{})
	var xp:int=state.get("xp",{}).get(selected_class,0)
	summary.text=selected_class.to_upper()+" · LEVEL %d · %d CLASS XP\nChoices apply on your next spawn. T2 utility kits unlock at level 15.\nNVG visor included · offhand trigger above forehead · N on desktop."%[game.classes.progression.level(xp),xp]
	if state.is_empty():summary.text+="\nJoin or start a match to select equipment."
	for row in buttons:
		row.button.visible=row.role==selected_class
		row.button.disabled=state.is_empty() or xp<row.xp
		var choice=state.get("utility_choices",{}).get(row.role,game.classes.UTILITIES[row.role][0].id) if row.slot=="UTILITY" else state.get("secondary_choices" if row.slot=="SECONDARY" else "primary_choices",{}).get(row.role,8 if row.role=="scout" else 2) if row.slot=="SECONDARY" else state.get("primary_choices",{}).get(row.role,game.classes.progression.STARTERS[row.role][0])
		row.button.text=("✓ " if row.value==choice else "")+"T%d · "%row.tier+row.name+(" · LOCKED LEVEL %d · %d / %d XP"%[game.classes.progression.level(row.xp),xp,row.xp] if xp<row.xp else "")
