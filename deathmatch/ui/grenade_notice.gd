extends Control
## Observe accepted selection state, so rejected requests never flash a false icon.
const Icons=preload("res://deathmatch/ui/weapon_icons.gd")
const NAMES=["HE GRENADE","FLASHBANG","SMOKE GRENADE"]
const DURATION:=1.6
var identity: Array=[]
var selected:=-1
var until:=0.0
var icon: Texture2D
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE;hide()
func update_selection(game,id: int):
	var de=game.match_mode.defusal;var player: Dictionary=game.players.get(id,{})
	if not de.enabled() or player.get("dead",true) or player.get("spectator",false) or de.phase!="live":
		identity=[];selected=-1;hide();return
	var life: Array=[game.map_epoch,de.round_id,id,player.serial]
	if identity!=life:identity=life;selected=-1;until=0
	var state: Dictionary=de.utility.state(id)
	var kind: int=de.utility.shoulder_selected(id) if state.shoulder>=0 else de.utility.selected(id)
	if kind!=selected:
		selected=kind;until=game.clock+DURATION if kind>=0 else 0
		icon=Icons.texture(NAMES[kind]) if kind>=0 else null
	visible=selected>=0 and game.clock<until
	if visible:modulate.a=clampf((until-game.clock)/.25,0,1);queue_redraw()
func _draw():
	if selected<0 or not icon:return
	draw_rect(Rect2(Vector2.ZERO,size),Color(.08,.065,.045,.92))
	draw_rect(Rect2(Vector2.ONE,size-Vector2.ONE*2),Color("a88550"),false,2)
	draw_texture_rect(icon,Rect2(10,8,64,48),false,Color("ffe0a0"))
	draw_string(ThemeDB.fallback_font,Vector2(88,28),NAMES[selected],HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("ffe0a0"))
	draw_string(ThemeDB.fallback_font,Vector2(88,51),"SELECTED",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e5d5ad"))
