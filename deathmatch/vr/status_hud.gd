extends Control
## Transparent, noninteractive HUD drawn into a head-relative stereo surface.
const W=preload("res://deathmatch/weapons.gd")
const KILLFEED_HEIGHT=100
const CHAT_HEIGHT=132
const NOTIFY_HEIGHT=56
const VIEW_SIZE=Vector2i(960,292+KILLFEED_HEIGHT+CHAT_HEIGHT+NOTIFY_HEIGHT)
var cq:=false
var radio_scope:=0
func update_radio_scope(scope:int)->void:
	if scope!=radio_scope:radio_scope=scope;queue_redraw()
var cq_panel:StyleBox
var cq_font:Font
var legacy_panel:StyleBoxFlat
func configure_cq()->void:
	cq=true;cq_font=preload("res://deathmatch/ui/cq/theme.gd").FONT
	theme=preload("res://deathmatch/ui/cq/theme.gd").theme()
	cq_panel=preload("res://deathmatch/ui/cq/hud.gd").surface()
	for line in chat_labels+kill_labels:line.add_theme_color_override("font_color",preload("res://deathmatch/ui/cq/theme.gd").INK)
	queue_redraw()
func backdrop(rect:Rect2,color:Color)->void:
	if cq:draw_style_box(cq_panel,rect)
	else:draw_rect(rect,color)
var player_status: Dictionary={}
func update_player_status(data: Dictionary) -> void:
	if data!=player_status:player_status=data;queue_redraw()
var kill_labels:Array[Label]=[]
var kill_messages:=PackedStringArray()
var chat_labels: Array[Label]=[]
var chat_messages:=PackedStringArray()

func _ready() -> void:
	if not cq:
		legacy_panel=StyleBoxFlat.new();legacy_panel.bg_color=Color(.10,.075,.05,.80);legacy_panel.border_color=Color("a88550");legacy_panel.set_border_width_all(2)
	for i in 3:
		var line:=Label.new();line.position=Vector2(20,4+i*32);line.size=Vector2(920,30)
		line.add_theme_font_size_override("font_size",20)
		line.add_theme_color_override("font_color",preload("res://deathmatch/ui/cq/theme.gd").INK if cq else INK)
		line.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		line.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(line);kill_labels.append(line)
	for i in 2:
		var line:=Label.new()
		line.position=Vector2(20,KILLFEED_HEIGHT+4+i*64)
		line.size=Vector2(920,60)
		line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		line.max_lines_visible=3
		line.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_theme_font_size_override("font_size",18)
		line.add_theme_color_override("font_color",preload("res://deathmatch/ui/cq/theme.gd").INK if cq else INK)
		line.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(line);chat_labels.append(line)
	_refresh_chat()

func update_killfeed(entries:Array,now:float)->void:
	var next:=PackedStringArray()
	for entry in entries:
		if entry.until>now:next.append(entry.text)
	while next.size()>3:next.remove_at(0)
	if next==kill_messages:return
	kill_messages=next
	for i in kill_labels.size():
		var index:=i-(3-kill_messages.size())
		kill_labels[i].text=kill_messages[index] if index>=0 else ""
	queue_redraw()

func update_chat(entries: Array,now: float) -> void:
	var next:=PackedStringArray()
	for entry in entries:
		if entry.until>now:next.append(entry.text)
	while next.size()>2:next.remove_at(0)
	if next==chat_messages:return
	chat_messages=next
	_refresh_chat()
	queue_redraw()

func _refresh_chat() -> void:
	for i in chat_labels.size():
		# Keep a lone message adjacent to the other notifications.
		var index:=i-(2-chat_messages.size())
		chat_labels[i].text=chat_messages[index] if index>=0 else ""

var values: Dictionary={}
var network:Dictionary={}
var capture_text:=""
var capture_team:=0
func update_capture(data: Dictionary) -> void:
	var next: String="" if data.is_empty() else data.text+"  "+data.detail
	if next!=capture_text:capture_text=next;capture_team=data.get("team",0);queue_redraw()
var burning:=false
func update_burning(value: bool) -> void:
	if value!=burning:burning=value;queue_redraw()
var water_text:=""
func update_water(submerged: bool,air: float) -> void:
	var next:=("AIR %ds"%ceili(air) if air>0 else "DROWNING · SURFACE!") if submerged else ""
	if next!=water_text:water_text=next;queue_redraw()
var vote_text:=""
func update_vote(data: Dictionary) -> void:
	var next: String="" if data.is_empty() else "%s · YES %d/%d · NO %d · %ds\nMENU → TEAMS & VOTES TO RESPOND"%[data.title,data.yes,data.needed,data.no,data.seconds]
	if next!=vote_text:vote_text=next;queue_redraw()
func update_network(progress: Dictionary,ping: int,host: bool) -> void:
	var next:={"show":progress.visible,"percent":int(progress.fraction*100),"ping":ping,"host":host}
	if next!=network:network=next;queue_redraw()
const INK=Color("e5d5ad")
func update_status(state: Dictionary,remaining: float,limit: int,leader: int,intermission: bool,mic: bool,objective: String="",radio: bool=false,weapon_data: Dictionary={},capacities: Array=W.MAX_AMMO,cq_ammo:Dictionary={}) -> void:
	if weapon_data.is_empty():weapon_data=W.DATA[clampi(state.weapon,0,9)]
	var ammo_type:int=weapon_data.ammo
	var next:={"objective":objective,"spectator":state.get("spectator",false),"hp":maxi(0,state.hp),"armor":state.armor,"ammo":state.ammo[ammo_type] if ammo_type>=0 else -1,"capacity":capacities[ammo_type] if ammo_type>=0 else 1,"weapon":weapon_data.name,"seconds":maxi(0,ceili(remaining)),"frags":maxi(0,limit-leader),"dead":state.dead,"pause":intermission,"mic":mic,"radio":radio}
	if cq and not cq_ammo.is_empty():next.ammo=cq_ammo.loaded;next.capacity=cq_ammo.capacity;next.reserve=cq_ammo.reserve
	if next!=values:values=next;queue_redraw()
func label(at: Vector2,value: String,font_size: int,color: Color=INK) -> void:
	if cq and color in [INK,Color("d8bc8b"),Color("b9a98e"),Color("ffcf80")]:color=preload("res://deathmatch/ui/cq/theme.gd").INK
	draw_string(cq_font if cq else ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,preload("res://deathmatch/ui/cq/theme.gd").INK if cq and color==INK else color)
func _draw() -> void:
	for i in kill_labels.size():
		if not kill_labels[i].text.is_empty():backdrop(Rect2(4,2+i*32,952,30),Color(.10,.075,.05,.88))
	for i in chat_labels.size():
		if not chat_labels[i].text.is_empty():backdrop(Rect2(4,KILLFEED_HEIGHT+2+i*64,952,62),Color(.10,.075,.05,.88))
	draw_set_transform(Vector2(0,KILLFEED_HEIGHT+CHAT_HEIGHT))
	if not player_status.is_empty():
		var team: int=player_status.team
		var color: Color=Color("ff9c88") if team==0 else Color("91caff") if team==1 else INK
		if not player_status.ability.is_empty():
			backdrop(Rect2(4,0,720,27),Color(.10,.075,.05,.88));label(Vector2(20,22),player_status.ability,20)
		if not player_status.team_text.is_empty():
			backdrop(Rect2(748,0,208,27),Color(.10,.075,.05,.90));label(Vector2(762,22),player_status.team_text,20,color)
		if not player_status.carrier.is_empty():
			backdrop(Rect2(4,28,952,27),Color(.10,.075,.05,.94));label(Vector2(20,50),player_status.carrier,21,Color("ffdf86"))
	draw_set_transform(Vector2(0,KILLFEED_HEIGHT+CHAT_HEIGHT+NOTIFY_HEIGHT))
	if not capture_text.is_empty():
		backdrop(Rect2(4,0,952,70),Color(.23,.06,.04,.94) if capture_team==0 else Color(.035,.10,.23,.94))
		label(Vector2(20,28),capture_text.left(82),22,Color("fff0bf"))
		if not vote_text.is_empty():label(Vector2(20,56),vote_text.split("\n")[0].left(86),18)
	elif not vote_text.is_empty():
		backdrop(Rect2(4,0,952,70),Color(.16,.07,.025,.94))
		var lines:=vote_text.split("\n")
		label(Vector2(20,25),lines[0].left(86),20,Color("ffcf80"))
		label(Vector2(20,53),lines[1],21,Color("ffcf80"))
	draw_set_transform(Vector2(0,KILLFEED_HEIGHT+CHAT_HEIGHT+NOTIFY_HEIGHT+72))
	if not network.is_empty():
		if network.show:label(Vector2(16,205),"↓ ASSETS %d%%"%network.percent,18,Color("d8bc8b"))
		label(Vector2(832,205),"HOST" if network.host else "%d ms"%network.ping if network.ping>0 else "— ms",18,Color("b9a98e"))
	if not water_text.is_empty():label(Vector2(335,205),water_text,21,Color("83c9ec"))
	elif burning:label(Vector2(390,205),"BURNING",21,Color("ff9b47"))
	if values.is_empty():return
	if not cq:legacy_panel.border_color=Color("ff9c88") if player_status.get("team",-1)==0 else Color("91caff") if player_status.get("team",-1)==1 else Color("a88550")
	draw_style_box(cq_panel if cq else legacy_panel,Rect2(4,4,952,172))
	label(Vector2(30,34),"ROUND OVER" if values.pause else values.objective if not values.objective.is_empty() else "%d FRAGS LEFT"%values.frags,21,Color("d8bc8b"))
	if not cq:label(Vector2(615,34),"%02d:%02d"%[values.seconds/60,values.seconds%60],23)
	label(Vector2(810,34),("SQUAD" if cq and radio_scope==1 else "TEAM" if cq else "RADIO") if values.radio else "MIC LIVE" if values.mic else "",21,Color("86dfb0"))
	if values.spectator:
		label(Vector2(30,96),"SPECTATING",36)
		label(Vector2(30,140),"LEFT STICK MOVE · RIGHT STICK UP / DOWN TO FLY",20)
		return
	var colors:=[Color("86dfb0") if values.hp>25 else Color("ff827a"),Color("83c9ec"),Color("65e0d5") if cq else Color("edce91")]
	var amounts:=[values.hp,values.armor,values.ammo]
	for i in range(3):
		var x:float=30+i*314;var tint:Color=colors[i]
		if i==0:
			draw_rect(Rect2(x+11,71,8,30),tint);draw_rect(Rect2(x,82,30,8),tint)
		elif i==1:
			draw_polyline(PackedVector2Array([Vector2(x,73),Vector2(x+15,68),Vector2(x+30,73),Vector2(x+26,93),Vector2(x+15,103),Vector2(x+4,93),Vector2(x,73)]),tint,3,true)
		else:
			for j in range(3):draw_rect(Rect2(x+j*11,76-j*3,7,26+j*3),tint)
		label(Vector2(x+46,105),"∞" if amounts[i]<0 else str(amounts[i]),46,tint)
		if cq and i==2 and amounts[i]>=0:label(Vector2(x+150,100),"%d SPARE"%values.get("reserve",0),18,Color("8faeb5"))
		label(Vector2(x,142),["HEALTH","ARMOUR",values.weapon][i],19,INK)
		draw_line(Vector2(x,157),Vector2(x+264,157),Color(.25,.32,.35,.8),5,true)
		var ratio:float=1.0 if amounts[i]<0 else clampf(float(amounts[i])/([100.0,200.0,float(values.capacity)][i]),0,1)
		if ratio>0:draw_line(Vector2(x,157),Vector2(x+264*ratio,157),tint,5,true)
	if values.dead:label(Vector2(295,67),"FRAGGED · A / TRIGGER TO RESPAWN",19,Color("ffaaa0"))
