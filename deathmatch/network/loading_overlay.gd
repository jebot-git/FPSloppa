extends Control
## Noninteractive corner telemetry; only the pre-spawn loading screen captures input.
var game
var cancel:Button
var refresh:=0.0
func setup(arena: Node) -> void:
	game=arena;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	cancel=Button.new();cancel.text="CANCEL CONNECTION";cancel.custom_minimum_size=Vector2(240,42)
	add_child(cancel);cancel.pressed.connect(func():game.disconnect_game("Connection cancelled."))
	cancel.hide()
func _process(delta: float) -> void:
	if not game:return
	mouse_filter=Control.MOUSE_FILTER_STOP if game.loading.blocking else Control.MOUSE_FILTER_IGNORE
	cancel.visible=game.loading.blocking
	cancel.position=Vector2((size.x-240)/2,size.y/2+108)
	refresh+=delta
	if refresh>=.1:refresh=0;queue_redraw()
func line(at: Vector2,value: String,font_size: int=16,color: Color=Color("e5d5ad")) -> void:
	draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func bar(rect: Rect2,fraction: float) -> void:
	draw_rect(rect,Color("342c23"));draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(fraction,0,1),rect.size.y)),Color("c7a36a"))
func _draw() -> void:
	if not game:return
	var state:Dictionary=game.loading.snapshot()
	if state.blocking:
		draw_rect(Rect2(Vector2.ZERO,size),Color(.035,.028,.023,.98))
		var width:float=minf(600,size.x-48);var left:float=(size.x-width)/2;var top:float=size.y/2-110
		line(Vector2(left,top),"PREPARING YOUR MATCH",28)
		line(Vector2(left,top+44),state.phase.left(62),19)
		bar(Rect2(left,top+66,width,14),minf(state.fraction,.99) if not game.loading.sent_ready else 1)
		line(Vector2(left,top+108),"%s / %s   ·   %d%%"%[String.humanize_size(state.done),String.humanize_size(state.total),int(state.fraction*100)] if state.total>0 else "Checking server assets…")
		line(Vector2(left,top+140),state.eta,16,Color("b9a98e"))
		line(Vector2(left,top+174),"You enter after the map and player models are verified.",16,Color("b9a98e"))
		return
	if state.visible:
		var at:=Vector2(18,size.y-128)
		draw_rect(Rect2(at-Vector2(8,22),Vector2(280,49)),Color(.06,.05,.04,.85))
		line(at,"↓ ASSETS  %d%% · %s"%[int(state.fraction*100),String.humanize_size(state.done)],14)
		bar(Rect2(at+Vector2(0,10),Vector2(260,3)),state.fraction)
	if game.active and not game.practice:
		var ping:int=game.local_ping
		var tint:=Color("ae9571") if ping<100 else Color("e4b36b") if ping<200 else Color("ed8874")
		var label:="HOST" if multiplayer.is_server() else "%d ms"%ping if ping>0 else "— ms"
		line(Vector2(size.x-88,30),label,14,tint)
