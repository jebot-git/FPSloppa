extends Control
var station
var telemetry: Dictionary={}
const CYAN=Color("8ce9df")
func draw_live() -> void:
	var font:=ThemeDB.fallback_font
	var t: Dictionary=telemetry
	var prep: bool=float(t.preparation)>0
	var seconds:=ceili(float(t.preparation if prep else t.time))
	draw_rect(Rect2(18,18,1244,92),Color(.015,.04,.065,.90))
	draw_string(font,Vector2(38,51),"BA-2  /  FORWARD OPTICAL LINK",HORIZONTAL_ALIGNMENT_LEFT,-1,25,CYAN)
	draw_string(font,Vector2(890,51),("PREPARE " if prep else "TIME ")+"%02d:%02d"%[seconds/60,seconds%60],HORIZONTAL_ALIGNMENT_LEFT,-1,25,CYAN)
	draw_string(font,Vector2(38,88),"PILOT HP %03d  /  ARMOUR %03d"%[t.hp,t.armor],HORIZONTAL_ALIGNMENT_LEFT,-1,25,CYAN)
	draw_string(font,Vector2(680,88),"TO GOAL %.1f m  /  CHECKPOINTS %d / 2"%[t.remaining,t.checkpoints],HORIZONTAL_ALIGNMENT_LEFT,-1,23,CYAN)
	var centre:=Vector2(640,360)
	for sign in [-1,1]:
		draw_line(centre+Vector2(sign*9,0),centre+Vector2(sign*25,0),CYAN,2)
		draw_line(centre+Vector2(0,sign*9),centre+Vector2(0,sign*20),CYAN,2)
	# One authoritative heat reservoir per linked upper/lower cannon pair.
	for side in 2:
		var x:=38+side*870;var heat: float=t.heat[side];var locked: bool=t.locked[side]
		var color:=Color("ff745e") if locked else CYAN
		draw_rect(Rect2(x-12,552,342,148),Color(.015,.04,.065,.90))
		draw_string(font,Vector2(x,580),("LEFT" if side==0 else "RIGHT")+" / LINKED CANNONS",HORIZONTAL_ALIGNMENT_LEFT,-1,22,CYAN)
		draw_string(font,Vector2(x,620),"PAIR HEAT %03d%%"%roundi(heat),HORIZONTAL_ALIGNMENT_LEFT,-1,23,color)
		for segment in 20:draw_rect(Rect2(x+segment*16,634,12,15),color if heat>segment*5 else Color("24444f"))
		draw_string(font,Vector2(x,682),"VENTING / BOTH LOCKED" if locked else "READY / TWO BARRELS",HORIZONTAL_ALIGNMENT_LEFT,-1,21,color)
	draw_string(font,Vector2(453,595),"%s / %.2f m/s"%[str(t.state).to_upper(),t.speed],HORIZONTAL_ALIGNMENT_LEFT,-1,23,CYAN)
	draw_string(font,Vector2(474,632),"AMMUNITION UNLIMITED",HORIZONTAL_ALIGNMENT_LEFT,-1,21,CYAN)
	var lock: float=t.get("exit_lock",0.)
	draw_string(font,Vector2(470,674),"EXIT LOCK %.1f s"%lock if lock>0 else "JUMP / USE TO EXIT",HORIZONTAL_ALIGNMENT_LEFT,-1,23,CYAN)
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1280,720))
	if not telemetry.is_empty():
		draw_live();return
	if not station:return
	var font:=ThemeDB.fallback_font
	draw_rect(Rect2(18,18,1244,52),Color(0.015,.04,.065,.85))
	draw_string(font,Vector2(38,51),"BA-2  /  FORWARD OPTICAL LINK",HORIZONTAL_ALIGNMENT_LEFT,-1,25,CYAN)
	draw_string(font,Vector2(925,50),"REMOTE PILOT / LOCKED",HORIZONTAL_ALIGNMENT_LEFT,-1,20,CYAN)
	var centre:=Vector2(640,360)
	for sign in [-1,1]:
		draw_line(centre+Vector2(sign*9,0),centre+Vector2(sign*25,0),CYAN,2)
		draw_line(centre+Vector2(0,sign*9),centre+Vector2(0,sign*20),CYAN,2)
	for side in 2:
		var p: Vector2=station.impacts[side]
		if Rect2(22,75,1236,550).has_point(p):
			draw_arc(p,8,0,TAU,20,Color("ff745e") if station.obstructed[side] else Color("ffd295"),2)
			draw_string(font,p+Vector2(12,5),"L" if side==0 else "R",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ffd295"))
		var x:=38+side*870;var heat: float=station.controls.heat[side]
		var locked: bool=station.controls.locked[side]
		var color:=Color("ff745e") if locked else CYAN
		draw_rect(Rect2(x-12,594,342,106),Color(.015,.04,.065,.90))
		draw_string(font,Vector2(x,623),("LEFT" if side==0 else "RIGHT")+" PAIR  /  "+("VENTING" if locked else ("COVER" if station.obstructed[side] else "READY")),HORIZONTAL_ALIGNMENT_LEFT,-1,20,color)
		for segment in 20:
			draw_rect(Rect2(x+segment*16,637,12,15),color if heat>segment/20.0 else Color("24444f"))
		draw_string(font,Vector2(x,681),"HEAT %03d%%  |  HITS %02d" % [roundi(heat*100),station.hits[side]],HORIZONTAL_ALIGNMENT_LEFT,-1,19,color)
	draw_string(font,Vector2(470,648),"CANNON ELEVATION %+04.1f°" % station.controls.aim.y,HORIZONTAL_ALIGNMENT_LEFT,-1,20,CYAN)
	draw_string(font,Vector2(495,677),"X HINGE  /  LIMIT ±4°",HORIZONTAL_ALIGNMENT_LEFT,-1,18,CYAN)
