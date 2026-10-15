extends RefCounted
const Art=preload("res://deathmatch/ui/cq/theme.gd")
static func surface(margin:float=12.)->StyleBoxTexture:
	var box:=Art.panel(margin);box.modulate_color=Color(1,1,1,.86);return box
static func setup(hud)->void:
	hud.tactical_map=preload("res://deathmatch/ui/cq/tactical_map.gd").new();hud.scoreboard.get_parent().add_child(hud.tactical_map);hud.tactical_map.setup(hud.game)
	for label in [hud.vitals,hud.weapon,hud.ammo,hud.match_status,hud.ability_notice,hud.kill_feed,hud.center_message,hud.toast_label]:
		label.add_theme_color_override("font_color",Art.INK)
	hud.ammo.add_theme_color_override("font_color",Art.ACCENT)
	hud.hit.add_theme_color_override("font_color",Art.ACCENT)
	var row:HBoxContainer=hud.vitals.get_parent();row.add_theme_constant_override("separation",12)
	var bottom:PanelContainer=row.get_parent();bottom.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	bottom.offset_left=16;bottom.offset_right=-16;bottom.offset_top=-112;bottom.offset_bottom=-16
	for label in [hud.vitals,hud.weapon,hud.ammo]:
		var card:=PanelContainer.new();card.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_theme_stylebox_override("panel",surface());row.add_child(card)
		label.reparent(card);label.custom_minimum_size=Vector2(0,68);label.size_flags_vertical=Control.SIZE_EXPAND_FILL;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",24)
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	hud.match_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.match_status.offset_left=16;hud.match_status.offset_right=-268;hud.match_status.offset_top=16
	hud.match_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hud.match_status.add_theme_stylebox_override("normal",surface())
	for index in 3:
		var line:Label=[hud.team_badge,hud.ability_notice,hud.carrier_notice][index]
		line.offset_left=-252;line.offset_right=-16;line.offset_top=16+index*36;line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud.kill_feed.offset_top=136;hud.kill_feed.add_theme_font_size_override("font_size",17)
static func ammo_readout(game,id:int)->Dictionary:
	var state:Dictionary=game.players.get(id,{})
	if state.is_empty():return {"loaded":0,"reserve":0,"capacity":1}
	var data:Dictionary=game.armory.data(state.weapon)
	if data.ammo<0:return {"loaded":-1,"reserve":0,"capacity":1}
	var magazine:Dictionary=game.variant_combat.magazines.states.get(id,{})
	var total:int=state.ammo[data.ammo]
	var loaded:int=magazine.get("clips",{}).get(state.weapon,mini(data.magazine,total))
	return {"loaded":loaded,"reserve":maxi(0,total-loaded),"capacity":data.magazine}
static func refresh(hud,id:int)->void:
	var game=hud.game;var state:Dictionary=game.players.get(id,{})
	if state.is_empty():return
	hud.vitals.text="%03d HEALTH\n%03d ARMOUR"%[state.hp,state.armor]
	hud.vitals.add_theme_color_override("font_color",Color("ff827a") if state.hp<=25 else Art.INK)
	var data:Dictionary=game.armory.data(state.weapon)
	hud.weapon.text=data.name
	if data.ammo<0:hud.ammo.text="TOOL\nREADY";return
	var magazine:Dictionary=game.variant_combat.magazines.states.get(id,{})
	var ammo:=ammo_readout(game,id)
	hud.ammo.text="%02d LOADED\n%03d RESERVE"%[ammo.loaded,ammo.reserve]
	if magazine.get("reloading",-1)==state.weapon:hud.weapon.text+="\nRELOADING"
