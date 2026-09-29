extends Node
## Portable tactical map: a 2D terrain survey and team-filtered markers, shared in VR.
const SIZE:=Vector2(1040,720)
const MAP:=Rect2(24,86,660,550)
const Wrist=preload("res://deathmatch/tribes/wrist_display.gd")
const PANEL_SIZE:=Wrist.PDA_SIZE
const GRID:=64
class MapCanvas extends Control:
	var view
	func _draw():view.draw_map(self)
var rules
var opened:=false
var canvas: MapCanvas
var layer: CanvasLayer
var viewport: SubViewport
var surface: MeshInstance3D
var wrist
var marker: Label3D
var terrain: Array=[]
var survey_at:=0
var lowest:=INF
var highest:=-INF
var epoch:=-1
var bounds:=AABB()
var center:=Vector2.ZERO
var zoom:=1.0
var sensors:=true
var names:=true
var tab:="units"
var page:=0
var selected: Array=[]
var device:=""
var verb:=""
var buttons: Array=[]
var cursor:=Vector2.INF
var trigger_was:=true
var dragging:=false
var next_update:=0.0
var seen_order:=""
var game:
	get:return rules.game
func setup(value):rules=value
func _exit_tree():
	for node in [wrist,marker]:
		if is_instance_valid(node):node.queue_free()
func create_view():
	viewport=SubViewport.new();viewport.size=Vector2i(SIZE);viewport.transparent_bg=false;viewport.disable_3d=true;viewport.gui_disable_input=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
	canvas=MapCanvas.new();canvas.view=self;canvas.size=SIZE;viewport.add_child(canvas)
	layer=CanvasLayer.new();layer.layer=10;add_child(layer)
	var image:=TextureRect.new();image.texture=viewport.get_texture();image.name="Screen";image.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(image)
	wrist=Wrist.new();game.add_child(wrist);wrist.setup(viewport.get_texture(),"pda");surface=wrist.screen;surface.hide();layer.hide()
func toggle():
	if opened:close();return
	var id: int=game.multiplayer.get_unique_id()
	if not rules.deployables.accessible(id) or game.demos.playing or rules.vehicles.mounted(id):return
	rules.close_remote_view()
	if is_instance_valid(rules.panel):rules.panel.close()
	if game.is_vr():game.xr_rig.weapon_wheel.close();game.xr_rig.physical_actions.reset()
	if not is_instance_valid(viewport):create_view()
	opened=true;selected=[id];device="";verb="";trigger_was=true;cursor=Vector2.INF
	if not game.is_vr():Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	update(0)
func close():
	opened=false;verb="";dragging=false
	if is_instance_valid(viewport):viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;layer.hide();surface.hide();wrist.hide()
	if game.active and not game.menu_open and not game.is_vr():Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func scale_world() -> float:return MAP.size.y/maxf(1,maxf(bounds.size.x,bounds.size.z))*zoom
func project(point: Vector3) -> Vector2:return MAP.get_center()+(Vector2(point.x,point.z)-center)*scale_world()
func unproject(point: Vector2) -> Vector3:
	var at:=center+(point-MAP.get_center())/scale_world()
	var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x,bounds.end.y-.1,at.y),Vector3(at.x,bounds.position.y+.1,at.y),1))
	return hit.get("position",Vector3.INF)
func reset_map():
	epoch=game.map_epoch;terrain.clear();survey_at=0;lowest=INF;highest=-INF;zoom=1;page=0
	var pads=rules.stations();bounds=pads.playable_bounds if pads else AABB(Vector3(-500,-100,-500),Vector3(1000,400,1000));center=Vector2(bounds.get_center().x,bounds.get_center().z)
func survey():
	# Bounded, incremental static collision survey; no camera can expose hidden players.
	var excluded: Array[RID]=[]
	for node in rules.vehicles.bodies.values():excluded.append(node.get_rid())
	for node in rules.deployables.nodes.values():excluded.append(node.get_rid())
	for i in mini(64,GRID*GRID-survey_at):
		var cell:=Vector2i(survey_at%GRID,survey_at/GRID);survey_at+=1
		var x: float=bounds.position.x+(cell.x+.5)*bounds.size.x/GRID;var z: float=bounds.position.z+(cell.y+.5)*bounds.size.z/GRID
		var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,bounds.end.y-.1,z),Vector3(x,bounds.position.y+.1,z),1,excluded))
		if not hit.is_empty():
			lowest=minf(lowest,hit.position.y);highest=maxf(highest,hit.position.y)
			terrain.append({"point":hit.position,"light":.65+.35*maxf(0,hit.normal.dot(Vector3(-.4,.8,-.4).normalized()))})
func objects() -> Array:
	var result: Array=[];var me: int=game.multiplayer.get_unique_id();var team: int=game.local_state().get("team",-1)
	if team not in [0,1]:return result
	for id in game.players:
		var s: Dictionary=game.players[id]
		if s.spectator or not game.fighters.has(id):continue
		if s.team!=team and (s.dead or id not in rules.deployables.contacts[team]):continue
		result.append({"tag":"p%d"%id,"kind":"player","ref":id,"point":game.fighters[id].position,"name":s.name.left(22),"friendly":s.team==team,"active":not s.dead,"range":0.0})
	var pads=rules.stations()
	if pads:
		for key in pads.defences.rows.size():
			var r: Dictionary=pads.defences.rows[key]
			if r.team==team:result.append({"tag":"f%d"%key,"kind":"fixed","ref":key,"point":r.position,"name":pads.defences.Data.TYPES[r.kind].name,"friendly":true,"active":pads.defences.active(key),"range":0.0})
		for key in pads.assets.rows.size():
			var r: Dictionary=pads.assets.rows[key]
			if r.team==team:result.append({"tag":"a%d"%key,"kind":"asset","ref":key,"point":r.frame.origin,"name":r.kind.to_upper(),"friendly":true,"active":pads.assets.active(key),"range":float(r.get("range",pads.assets.SENSOR_RANGE)) if r.kind=="pulse" else 0.0})
		for key in pads.generators.size():
			var r: Dictionary=pads.generators[key]
			if r.team==team:result.append({"tag":"g%d"%key,"kind":"asset","ref":key,"point":r.position,"name":"GENERATOR","friendly":true,"active":pads.source_active(r),"range":0.0})
	for key in rules.deployables.rows:
		var r: Dictionary=rules.deployables.rows[key]
		if r.team==team:result.append({"tag":"d%d"%key,"kind":"deployed","ref":key,"point":r.position,"name":r.kind.to_upper().replace("_"," ")+" %d"%key,"friendly":true,"active":rules.deployables.operational(r) and game.clock>=r.ready,"range":float(rules.deployables.Data.KINDS[r.kind].range) if r.kind in ["pulse","motion","remote_jammer"] else 0.0})
	for key in rules.vehicles.rows:
		var r: Dictionary=rules.vehicles.rows[key]
		if r.team==team:result.append({"tag":"v%d"%key,"kind":"vehicle","ref":key,"point":r.position,"name":rules.vehicles.definition(r).name,"friendly":true,"active":true,"range":0.0})
	return result
func choices() -> Array:
	return objects().filter(func(r):return r.friendly and (r.kind=="player" if tab=="units" else r.kind!="player"))
func screen_point(pixel: Vector2) -> Vector2:
	var image=layer.get_node("Screen");return (pixel-image.position)/image.scale
static func ray_point(pose: Transform3D,aim: Transform3D) -> Vector2:
	var inverse:=pose.affine_inverse();var origin: Vector3=inverse*aim.origin;var direction: Vector3=inverse.basis*(-aim.basis.z)
	# The case is opaque: pointing at the back or through its bezel cannot click.
	if origin.z<=0 or direction.z>=-.0001:return Vector2.INF
	var distance: float=-origin.z/direction.z
	if distance<0 or distance>3:return Vector2.INF
	var hit:=origin+direction*distance
	var uv:=Vector2(hit.x/PANEL_SIZE.x+.5,.5-hit.y/PANEL_SIZE.y)
	return uv*SIZE if Rect2(Vector2.ZERO,Vector2.ONE).has_point(uv) else Vector2.INF
func input(event: InputEvent) -> bool:
	if not opened:return false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_C,KEY_ESCAPE]:close();return true
	if game.is_vr():return false
	if event is InputEventMouseMotion:
		cursor=screen_point(event.position)
		if dragging:center-=event.relative/layer.get_node("Screen").scale/scale_world()
		refresh();return true
	if event is InputEventMouseButton:
		cursor=screen_point(event.position)
		if event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed and MAP.has_point(cursor)
		if event.pressed:
			if event.button_index==MOUSE_BUTTON_LEFT:click(cursor,event.shift_pressed)
			elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:zoom=clampf(zoom*(1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.2),1,6)
		refresh();return true
	return false
func click(point: Vector2,append:=false):
	for row in buttons:
		if row.rect.has_point(point):action(row.action);return
	if not MAP.has_point(point):return
	if not verb.is_empty():
		var where:=unproject(point)
		if where.is_finite():rules.command_action(verb,selected,where);verb=""
		return
	var nearest: Dictionary={};var distance:=16.0
	for row in objects():
		var near:=project(row.point).distance_to(point)
		if near<distance:nearest=row;distance=near
	if not nearest.is_empty():pick(nearest,append)
func pick(row: Dictionary,append:=false):
	if not row.friendly:return
	if row.kind=="player":
		if not append:selected.clear()
		if row.ref in selected:selected.erase(row.ref)
		else:selected.append(row.ref)
		device=""
	else:device=row.tag;selected.clear()
func action(value: String):
	if value=="close":close()
	elif value=="zoom+":zoom=minf(6,zoom*1.4)
	elif value=="zoom-":zoom=maxf(1,zoom/1.4)
	elif value=="sensors":sensors=not sensors
	elif value=="names":names=not names
	elif value in ["units","devices"]:tab=value;page=0
	elif value=="prev":page=maxi(0,page-1)
	elif value=="next":page+=1
	elif value=="center":
		var me: int=game.multiplayer.get_unique_id();var id: int=selected[0] if not selected.is_empty() else me
		if game.fighters.has(id):center=Vector2(game.fighters[id].position.x,game.fighters[id].position.z)
	elif value.begins_with("pick:"):
		var tag:=value.trim_prefix("pick:")
		for row in objects():
			if row.tag==tag:pick(row);break
	elif value in ["move","attack","defend"]:
		if not selected.is_empty():verb=value
	elif value in ["accept","complete","decline","follow","unfollow"]:rules.command_action(value,selected)
	elif value=="control":
		for row in objects():
			if row.tag!=device or not row.active:continue
			if row.kind=="fixed":close();rules.control_turret(row.ref)
			elif row.kind=="deployed" and rules.deployables.rows[row.ref].kind in ["camera","turret"]:close();rules.control_remote(row.ref)
	refresh()
func update(delta: float):
	if epoch!=game.map_epoch:reset_map()
	var me: int=game.multiplayer.get_unique_id();var state: Dictionary=game.local_state()
	if opened and (not rules.deployables.accessible(me) or game.menu_open or game.demos.playing or rules.vehicles.mounted(me)):close()
	var order: Dictionary=rules.commander.orders.get(me,{})
	var signature:=str(order)
	if signature!=seen_order:
		seen_order=signature
		if not order.is_empty():game.status("Order: "+order.verb.to_upper()+" · "+order.status+" · open PDA")
	if not is_instance_valid(marker):marker=Label3D.new();marker.font_size=28;marker.pixel_size=.006;marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED;game.add_child(marker)
	marker.visible=not order.is_empty() and order.status=="accepted" and rules.deployables.accessible(me)
	if marker.visible:marker.global_position=order.point+Vector3.UP*2;marker.text="◇ "+order.verb.to_upper()
	if not opened:return
	survey()
	if game.is_vr():
		layer.hide()
		var rig=game.xr_rig;surface.visible=wrist.mount(rig)
		var aim=rig.left_aim if rig.left_handed else rig.right_aim
		var tracked: bool=wrist.visible and (rig.simulated or aim.get_has_tracking_data())
		var previous:=cursor
		cursor=ray_point(surface.global_transform,aim.global_transform) if tracked else Vector2.INF
		if previous.is_finite()!=cursor.is_finite() or cursor.is_finite() and previous.distance_to(cursor)>1:refresh()
		var pressed: bool=game.bindings.vr_pressed(rig,"fire")
		if tracked and pressed and not trigger_was and cursor.is_finite():click(cursor)
		trigger_was=pressed
		var pan: Vector2=rig.control_axis("move")
		if pan.length()>.25:center+=Vector2(pan.x,-pan.y)*delta*150/zoom;refresh()
	else:
		surface.hide();wrist.hide();layer.show();var screen=layer.get_node("Screen");var factor:=minf(game.get_viewport().get_visible_rect().size.x/SIZE.x,game.get_viewport().get_visible_rect().size.y/SIZE.y)*.94
		screen.scale=Vector2.ONE*factor;screen.size=SIZE;screen.position=(game.get_viewport().get_visible_rect().size-SIZE*factor)*.5
	if game.clock>=next_update:next_update=game.clock+.1;refresh()
func refresh():
	if opened and is_instance_valid(canvas):canvas.queue_redraw();viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
func label(c: Control,at: Vector2,text: String,color:=Color("dcebe8"),size:=18):c.draw_string(ThemeDB.fallback_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func button(c: Control,rect: Rect2,title: String,command: String,on:=false):
	c.draw_style_box(style(Color("285349") if on else Color("1c3038")),rect);label(c,rect.position+Vector2(10,25),title);buttons.append({"rect":rect,"action":command})
func style(color: Color) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=color;box.set_corner_radius_all(5);return box
func draw_map(c: Control):
	buttons.clear();c.draw_rect(Rect2(Vector2.ZERO,SIZE),Color("0c171e"));label(c,Vector2(24,32),"TRIBES  /  COMMAND",Color("8be0c3"),24)
	var team: int=game.local_state().get("team",0);var score: Array=rules.mode.scores
	label(c,Vector2(390,32),"RED %d : %d BLUE   ·   ENERGY %d"%[score[0],score[1],rules.balance(game.multiplayer.get_unique_id())])
	button(c,Rect2(910,12,105,40),"CLOSE","close")
	for i in 5:button(c,Rect2(24+i*132,40,124,36),["ZOOM +","ZOOM −","CENTER","SENSORS","NAMES"][i],["zoom+","zoom-","center","sensors","names"][i],sensors if i==3 else names if i==4 else false)
	c.draw_rect(MAP,Color("15272c"))
	var cell_size:=Vector2(bounds.size.x,bounds.size.z)/GRID*scale_world()
	for cell in terrain:
		var rect:=Rect2(project(cell.point)-cell_size*.5,cell_size+Vector2.ONE).intersection(MAP)
		var height: float=clampf((cell.point.y-lowest)/maxf(1,highest-lowest),0,1)
		if rect.has_area():c.draw_rect(rect,Color("243e48").lerp(Color("8a9b70"),height)*Color(cell.light,cell.light,cell.light))
	for i in 9:
		var x: float=MAP.position.x+i*MAP.size.x/8;var y: float=MAP.position.y+i*MAP.size.y/8
		c.draw_line(Vector2(x,MAP.position.y),Vector2(x,MAP.end.y),Color(1,1,1,.07));c.draw_line(Vector2(MAP.position.x,y),Vector2(MAP.end.x,y),Color(1,1,1,.07))
	var items:=objects()
	for row in items:
		if sensors and row.active and row.range>0:
			var points:=PackedVector2Array()
			for i in 65:
				var at: Vector2=project(row.point)+Vector2(cos(i*TAU/64),sin(i*TAU/64))*row.range*scale_world()
				if MAP.has_point(at):points.append(at)
				elif points.size()>1:c.draw_polyline(points,Color("52898b"));points.clear()
			if points.size()>1:c.draw_polyline(points,Color("52898b"))
	for unit in rules.commander.orders:
		var order: Dictionary=rules.commander.orders[unit]
		if game.players.get(unit,{}).get("team",-1)!=team or order.status not in ["accepted","pending"] or not game.fighters.has(unit):continue
		var a:=project(game.fighters[unit].position);var b:=project(order.point)
		if MAP.has_point(a) and MAP.has_point(b):c.draw_line(a,b,Color("e7bf64") if order.status=="pending" else Color("6bd8ad"),2);c.draw_circle(b,4,Color("e7bf64"))
	for i in rules.mode.flags.size():
		var flag: Dictionary=rules.mode.flags[i];var at:=project(flag.position)
		if MAP.has_point(at):c.draw_rect(Rect2(at-Vector2(5,5),Vector2(10,10)),Color("f07169") if i==0 else Color("70b8f0"));label(c,at+Vector2(8,-8),"FLAG "+("AWAY" if flag.carrier!=0 or flag.dropped else "HOME"),Color("f1d995"),14)
	var occupied_labels: Array[Rect2]=[]
	items.sort_custom(func(a,b):return (a.tag==device or a.kind=="player" and a.ref in selected) and not (b.tag==device or b.kind=="player" and b.ref in selected))
	for row in items:
		var at:=project(row.point)
		if not MAP.has_point(at):continue
		var color:=Color("66d4b0") if row.friendly else Color("f07169")
		if not row.active:color=Color("6b7579")
		c.draw_circle(at,5 if row.kind=="player" else 3,color)
		if row.ref in selected and row.kind=="player" or row.tag==device:c.draw_arc(at,10,0,TAU,20,Color("ffe7a0"),2)
		if names:
			var extent:=ThemeDB.fallback_font.get_string_size(row.name.left(20),HORIZONTAL_ALIGNMENT_LEFT,-1,12)
			var rect:=Rect2(at+Vector2(8,-9),Vector2(extent.x,16))
			if MAP.encloses(rect) and not occupied_labels.any(func(previous):return previous.intersects(rect)):
				label(c,rect.position+Vector2(0,13),row.name.left(20),color,12);occupied_labels.append(rect)
	button(c,Rect2(710,86,148,38),"TEAM","units",tab=="units");button(c,Rect2(866,86,148,38),"EQUIPMENT","devices",tab=="devices")
	var options:=choices();page=clampi(page,0,maxi(0,(options.size()-1)/8))
	for i in mini(8,maxi(0,options.size()-page*8)):
		var row: Dictionary=options[page*8+i];button(c,Rect2(710,134+i*42,304,38),("● " if row.active else "○ ")+row.name.left(23),"pick:"+row.tag,row.tag==device or row.kind=="player" and row.ref in selected)
	button(c,Rect2(710,478,148,36),"PREVIOUS","prev");button(c,Rect2(866,478,148,36),"NEXT","next")
	if tab=="units":
		for i in 3:button(c,Rect2(710+i*102,526,96,36),["MOVE","ATTACK","DEFEND"][i],["move","attack","defend"][i],verb==["move","attack","defend"][i])
		button(c,Rect2(710,570,148,36),"FOLLOW","follow");button(c,Rect2(866,570,148,36),"UNFOLLOW","unfollow")
	else:button(c,Rect2(710,526,304,40),"CONTROL SELECTED","control")
	for i in 3:button(c,Rect2(710+i*102,614,96,36),["ACCEPT","DONE","DECLINE"][i],["accept","complete","decline"][i])
	label(c,Vector2(24,667),"Choose "+verb.to_upper()+" destination on map" if not verb.is_empty() else "Select a teammate or device · right-drag / offhand stick pans",Color("b3c4c7"),17)
	var order: Dictionary=rules.commander.orders.get(game.multiplayer.get_unique_id(),{})
	label(c,Vector2(24,696),"ORDER: "+order.verb.to_upper()+" / "+order.status.to_upper() if not order.is_empty() else "No active order · teammates choose their commander with FOLLOW",Color("e7bf64"),16)
	if cursor.is_finite():c.draw_arc(cursor,7,0,TAU,20,Color.WHITE,2)
