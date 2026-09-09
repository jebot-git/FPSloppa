extends Control
## Transparent, noninteractive HUD drawn into a head-relative stereo surface.
const W=preload("res://deathmatch/weapons.gd")
var values: Dictionary={}
const INK=Color("e5d5ad")
func update_status(state: Dictionary,remaining: float,limit: int,leader: int,intermission: bool,mic: bool,objective: String="") -> void:
	var ammo_type:int=W.DATA[state.weapon].ammo
	var next:={"objective":objective,"spectator":state.get("spectator",false),"hp":maxi(0,state.hp),"armor":state.armor,"ammo":state.ammo[ammo_type] if ammo_type>=0 else -1,"capacity":W.MAX_AMMO[ammo_type] if ammo_type>=0 else 1,"weapon":W.DATA[state.weapon].name,"seconds":maxi(0,ceili(remaining)),"frags":maxi(0,limit-leader),"dead":state.dead,"pause":intermission,"mic":mic}
	if next!=values:values=next;queue_redraw()
func label(at: Vector2,value: String,font_size: int,color: Color=INK) -> void:
	draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func _draw() -> void:
	if values.is_empty():return
	var style:=StyleBoxFlat.new();style.bg_color=Color(.10,.075,.05,.80);style.border_color=Color("a88550");style.set_border_width_all(2)
	draw_style_box(style,Rect2(4,4,952,172))
	label(Vector2(30,34),"ROUND OVER" if values.pause else values.objective if not values.objective.is_empty() else "%d FRAGS LEFT"%values.frags,21,Color("d8bc8b"))
	label(Vector2(615,34),"%02d:%02d"%[values.seconds/60,values.seconds%60],23)
	label(Vector2(810,34),"MIC LIVE" if values.mic else "",21,Color("86dfb0"))
	if values.spectator:
		label(Vector2(30,96),"SPECTATING",36)
		label(Vector2(30,140),"LEFT STICK MOVE · RIGHT STICK UP / DOWN TO FLY",20)
		return
	var colors:=[Color("86dfb0") if values.hp>25 else Color("ff827a"),Color("83c9ec"),Color("edce91")]
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
		label(Vector2(x,142),["HEALTH","ARMOUR",values.weapon][i],19,INK)
		draw_line(Vector2(x,157),Vector2(x+264,157),Color(.25,.32,.35,.8),5,true)
		var ratio:float=1.0 if amounts[i]<0 else clampf(float(amounts[i])/([100.0,200.0,float(values.capacity)][i]),0,1)
		if ratio>0:draw_line(Vector2(x,157),Vector2(x+264*ratio,157),tint,5,true)
	if values.dead:label(Vector2(295,67),"FRAGGED · A / TRIGGER TO RESPAWN",19,Color("ffaaa0"))
