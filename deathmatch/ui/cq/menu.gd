extends RefCounted
## CQ navigation over the shared arena interface. Hidden legacy controls retain
## their references for shared refresh code, but have no CQ navigation route.
static func retire(node:Control)->void:
	node.hide();node.mouse_filter=Control.MOUSE_FILTER_IGNORE
static func setup(hud)->void:
	var game=hud.game;var book=hud.menu_pages
	book.titles.home="CQ / JUNGLE FRONTIER";book.titles.player="IDENTITY";book.titles.play="PLAY";book.titles.match="MATCH"
	for child in book.pages.home.get_children():
		if child is Button and child not in [hud.resume,hud.play_category,hud.match_category]:retire(child)
	# An index of actions, without importers, demos or an in-game manual.
	hud.play_category.text="PLAY";hud.match_category.text="MATCH"
	book.link("home","cq_prepare","DEPLOYMENT")
	book.link("home","player","IDENTITY")
	hud.button(book.pages.home,"SETTINGS",func():hud.settings_panel.open())
	book.pages.home.move_child(hud.status,-1)
	hud.status.add_theme_color_override("font_color",Color("8faeb5"))
	hud.name_field.text=hud.Profile.Names.plain(hud.name_field.text);hud.clan_field.text=hud.Profile.Names.plain(hud.clan_field.text)
	hud.name_field.max_length=hud.Profile.Names.NAME_LIMIT;hud.clan_field.max_length=hud.Profile.Names.CLAN_LIMIT
	hud.name_field.tooltip_text="18 characters. Saved for your next match.";hud.clan_field.tooltip_text="8 characters. Shown in brackets before your callsign."
	hud.status.text="Jungle Frontier · Capture and hold objectives · First to 200"
	book.titles.cq_prepare="DEPLOYMENT";book.titles.cq_classes="CLASS";book.parents.cq_classes="cq_prepare"
	# Identity is deliberately separate from equipment and communication.
	for child in book.pages.player.get_children():
		if child is Button:retire(child)
	var identity:Control=hud.name_field.get_parent()
	for child in identity.get_children():
		if child is Button:retire(child)
	# Split the wide identity row into two readable rows.
	var clan:=HBoxContainer.new();book.pages.player.add_child(clan)
	var clan_label:Label=identity.get_child(hud.clan_field.get_index()-1)
	clan_label.reparent(clan);hud.clan_field.reparent(clan);hud.clan_field.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	clan_label.custom_minimum_size.x=110
	var direct=book.add_page("cq_connect","DIRECT CONNECTION","play")
	hud.address_field.get_parent().reparent(direct);hud.spectator_choice.reparent(direct)
	hud.launch_buttons[1].reparent(direct)
	var play:Control=book.pages.play
	hud.launch_buttons[2].reparent(play);hud.launch_buttons[2].text="BROWSE SERVERS"
	book.link("play","cq_connect","DIRECT CONNECTION")
	hud.launch_buttons[0].reparent(play);hud.launch_buttons[0].text="HOST CQ MATCH"
	# CQ has one map, class equipment and an objective score. Do not expose
	# fixed selectors or frag/time limits which the authority does not use.
	var host=hud.host_panel.get_meta("menu_book")
	for child in host.pages.home.get_children():retire(child)
	host.titles.home="HOST CQ MATCH"
	var description=hud.text(host.pages.home,"JUNGLE FRONTIER\nTwo teams · Capture and hold · First to 200",22)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud.host_port.get_parent().reparent(host.pages.home)
	hud.host_mode.hide();hud.weapon_choice.hide()
	host.navigate("home")
	# Team membership and balance votes remain; map and global-loadout votes
	# are inherited arena features and do not apply to the CQ class mode.
	retire(hud.votes_panel.selector);retire(hud.votes_panel.call_map);retire(hud.votes_panel.call_loadout)
	hud.votes_button.text="TEAMS & BALANCE"
	hud.suicide.text="RESPAWN";hud.suicide.tooltip_text="Return after the normal respawn delay."
	book.navigate("home")
