extends VBoxContainer
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Names=preload("res://deathmatch/ui/name_style.gd")
class Overview extends Control:
	const Land=preload("res://tools/voxel_battle/landscape.gd")
	const Water=preload("res://tools/voxel_battle/hydrology.gd")
	const Face=preload("res://deathmatch/ui/cq/theme.gd")
	var view
	var read_only:=false
	var terrain:Texture2D
	func _ready()->void:
		var image:=Image.create(64,64,false,Image.FORMAT_RGB8)
		for z in 64:
			for x in 64:
				var h:=Land.natural((x/63.-.5)*Land.EXTENT,(z/63.-.5)*Land.EXTENT)
				image.set_pixel(x,z,Color("0d2226").lerp(Color("48605b"),clampf(h/500.,0,1)))
		terrain=ImageTexture.create_from_image(image)
	func area()->Rect2:
		var side:=minf(size.x,size.y)-24.;return Rect2((size-Vector2.ONE*side)*.5,Vector2.ONE*side)
	func project(at:Vector3)->Vector2:return area().position+(Vector2(at.x,at.z)/Land.EXTENT+Vector2.ONE*.5)*area().size
	func _gui_input(event:InputEvent)->void:
		if read_only:return
		if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:return
		var best:=18.;var choice:=""
		for i in view.zones().size():
			var distance:float=event.position.distance_to(project(view.zones()[i].position))
			if distance<best:best=distance;choice="p:"+str(i)
		for member in view.members():
			if member.dead or member.staging:continue
			var distance:float=event.position.distance_to(project(member.position))
			if distance<best:best=distance;choice="m:%d:%d"%[member.id,member.life]
		if not choice.is_empty():view.choose(choice);accept_event()
	func _draw()->void:
		var rect:=area();draw_rect(Rect2(Vector2.ZERO,size),Color("09171c"))
		if terrain:draw_texture_rect(terrain,rect,false)
		for i in range(1,8):
			var k:=i/8.;draw_line(rect.position+Vector2(rect.size.x*k,0),rect.position+Vector2(rect.size.x*k,rect.size.y),Color(1,1,1,.07))
			draw_line(rect.position+Vector2(0,rect.size.y*k),rect.position+Vector2(rect.size.x,rect.size.y*k),Color(1,1,1,.07))
		for river in Water.RIVERS:
			for i in river.points.size()-1:draw_line(project(river.points[i]),project(river.points[i+1]),Color("406b7b"),3,true)
		for team in 2:
			var base:=project(Vector3((-.72 if team==0 else .72)*Land.EXTENT*.5,0,0))
			draw_rect(Rect2(base-Vector2(5,22),Vector2(10,44)),Color("ed8077") if team==0 else Color("80c3ef"))
		for i in view.zones().size():
			var zone:Dictionary=view.zones()[i];var at:=project(zone.position)
			var colour:Color=Color("ed8077") if zone.owner==0 else Color("80c3ef") if zone.owner==1 else Color("98a7a8")
			draw_circle(at,7,colour);draw_arc(at,10,0,TAU,24,Color("e7d879") if zone.contested else colour,1.5,true)
			var progress:float=maxf(zone.progress[0],zone.progress[1])/10.
			if progress>0:draw_arc(at,13,-PI/2,-PI/2+TAU*progress,24,Color.WHITE,2,true)
			if view.selected=="p:"+str(i):draw_arc(at,16,0,TAU,24,Color.WHITE,2,true)
			draw_string(Face.FONT,at+[Vector2(-55,-10),Vector2(10,-10),Vector2(10,18),Vector2(-65,22),Vector2(-30,24),Vector2(-10,-12),Vector2(-75,-10),Vector2(-25,24),Vector2(10,-10),Vector2(10,-10),Vector2(10,-10)][i],["TOWN","FACTORY","PORT","MILITARY","RADAR","W. RELAY","CROSSING","RIVER CAMP","CANOPY","SUMMIT","E. RUINS"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Face.INK)
		for member in view.members():
			if member.dead or member.staging:continue
			var at:=project(member.position);var hot:bool=member.get("combat_until",0.)>view.service.frame().get("mode",{}).get("time",0.)
			draw_circle(at,4,Color("ffcc75") if hot else Face.ACCENT)
			if view.selected=="m:%d:%d"%[member.id,member.life]:draw_arc(at,9,0,TAU,20,Color.WHITE,2,true)
			draw_string(Face.FONT,at+Vector2(7,14),str(member.number),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Face.INK)
		var mine:int=view.game.multiplayer.get_unique_id()
		var player:Dictionary=view.game.players.get(mine,{})
		if view.game.fighters.has(mine) and not player.get("dead",true) and not player.get("spectator",false):
			var actor=view.game.fighters[mine];var at:=project(actor.render_position())
			var yaw:float=view.game.local_yaw+(view.game.xr_rig.head.rotation.y if view.game.is_vr() else 0.)
			var forward:=Vector2(-sin(yaw),-cos(yaw));var side:=Vector2(-forward.y,forward.x)
			draw_circle(at,7,Color("081217"));draw_colored_polygon(PackedVector2Array([at+forward*11,at-forward*6+side*6,at-forward*6-side*6]),Color.WHITE)
		draw_string(Face.FONT,rect.position+Vector2(4,15),"N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Face.INK)
var game
var hud
var service
var map:Overview
var squad_buttons:Array=[]
var selector
var notice:Label
var summary:Label
var deploy:Button
var selected:="base"
var poll:=0.
var requested:=0
func setup(arena,interface,owner_service)->void:
	game=arena;hud=interface;service=owner_service
	var page=hud.menu_pages.add_page("cq_deployment","TACTICAL DEPLOYMENT","cq_prepare");page.add_child(self)
	var tools:=HBoxContainer.new();add_child(tools)
	hud.button(tools,"CLASS",func():hud.menu_pages.navigate("cq_classes"))
	hud.button(tools,"LOADOUT",func():hud.menu_pages.navigate("cq_loadout"))
	hud.button(tools,"CALIBRATE",func():hud.menu_pages.navigate("cq_calibrate"))
	var main:=HBoxContainer.new();main.add_theme_constant_override("separation",16);add_child(main)
	map=Overview.new();map.view=self;map.custom_minimum_size=Vector2(360,304);map.size_flags_horizontal=Control.SIZE_EXPAND_FILL;main.add_child(map)
	var options:=VBoxContainer.new();options.custom_minimum_size.x=280;main.add_child(options)
	summary=Label.new();summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;options.add_child(summary)
	var grid:=GridContainer.new();grid.columns=2;options.add_child(grid)
	for i in 4:
		var button:Button=hud.button(grid,"",service.join.bind(i));button.toggle_mode=true;squad_buttons.append(button)
	selector=preload("res://deathmatch/ui/choice.gd").new();options.add_child(selector);selector.selected.connect(choose)
	deploy=hud.button(options,"DEPLOY",submit)
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.custom_minimum_size.x=280;options.add_child(notice)
	var legend:=Label.new();legend.text="POI: RED / BLUE / NEUTRAL · RING: CAPTURE / CONTESTED\nSQUAD: CYAN · AMBER: IN COMBAT · SELECT A MARKER TO SPAWN";legend.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;legend.add_theme_font_size_override("font_size",14);add_child(legend)
	hud.menu_pages.parents.cq_classes="cq_deployment";hud.menu_pages.parents.cq_loadout="cq_deployment";hud.menu_pages.parents.cq_calibrate="cq_deployment"
	refresh()
func zones()->Array:
	return service.frame().get("mode",{}).get("zones",[]) if service.frame().has("mode") else game.match_mode.objectives.sites.map(func(site):return {"position":site.position,"owner":-1,"contested":false,"progress":[0.,0.]})
func members()->Array:
	var result:Array=[];var mine:int=game.multiplayer.get_unique_id()
	for id in service.frame().get("players",{}):
		var row:Dictionary=service.frame().players[id]
		if id==mine or not service.same_squad(mine,id):continue
		var member:Dictionary=row.duplicate();member.id=id;member.number=result.size()+1;result.append(member)
	return result
func choose(value:String)->void:
	selector.close_popup();selected=value;requested=0;refresh()
func selection()->Array:
	var parts:=selected.split(":")
	return [1,int(parts[1]),0] if parts[0]=="p" and parts.size()==2 else [2,int(parts[1]),int(parts[2])] if parts[0]=="m" and parts.size()==3 else [0,0,0]
func submit()->void:
	var choice:=selection()
	if service.spawn(choice[0],choice[1],choice[2]):requested=Time.get_ticks_msec()
	refresh()
func refresh()->void:
	var mine:Dictionary=service.local();var team:int=mine.get("team",0);var squad:int=mine.get("squad",-1)
	summary.text=("RED" if team==0 else "BLUE")+" · "+(service.NAMES[squad] if squad>=0 else "JOIN A SQUAD")
	for i in 4:
		var count:int=service.count(team,i);var button:Button=squad_buttons[i]
		button.text="%s %d/8"%[service.NAMES[i],count];button.set_pressed_no_signal(i==squad)
		button.disabled=mine.is_empty() or not mine.dead and not mine.get("staging",false) or count>=8 and i!=squad
	var choices:Array=[{"id":"base","title":"TEAM INSERTION"}]
	for i in zones().size():
		var zone:Dictionary=zones()[i]
		if zone.owner==team:choices.append({"id":"p:"+str(i),"title":Landscape.TYPES[i].to_upper()+(" · CONTESTED" if zone.contested else " · POI")})
	for member in members():choices.append({"id":"m:%d:%d"%[member.id,member.life],"title":Names.plain(game.players.get(member.id,{}).get("name","Squad member"))+" · SQUAD"})
	if not selector.popup.visible:selector.configure(choices,"SPAWN LOCATION");selector.set_block_signals(true);selector.choose(selected) if choices.any(func(row):return row.id==selected) else selector.clear_selection();selector.set_block_signals(false)
	var choice:=selection();var reason:String=service.reason(choice[0],choice[1],choice[2])
	deploy.disabled=not reason.is_empty();notice.text=reason if not reason.is_empty() else "Ready. Select DEPLOY."
	if requested>0:notice.text="Deploying…" if Time.get_ticks_msec()-requested<1500 else "Location changed or obstructed. Select another point and retry."
	map.queue_redraw()
func _process(delta:float)->void:
	if not is_visible_in_tree():return
	poll-=delta
	if poll<=0:poll=.1;refresh()
