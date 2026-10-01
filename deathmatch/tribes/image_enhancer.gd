extends RefCounted
## T1's armour-mounted image enhancer, independent of the equipped weapon.
const LEVELS=[2.0,5.0,10.0,20.0]
var index:=0
var active:=false
var released:=true
var game
func setup(value) -> void:game=value
func reset() -> void:active=false;released=false;index=0
func magnification() -> float:return LEVELS[index] if active else 1.0
static func zoom_fov(base: float,amount: float) -> float:
	return rad_to_deg(2.0*atan(tan(deg_to_rad(base)*.5)/amount))
func cycle(direction: int=1) -> void:index=posmod(index+direction,LEVELS.size())
func update(held: bool,allowed: bool) -> void:
	# Closing a menu, respawning or recovering tracking must not re-enter zoom
	# until its trigger has been released. Range survives ordinary weapon swaps.
	if not allowed:
		active=false
		released=false
		return
	if not held:released=true
	active=held and released
func allowed() -> bool:
	var s: Dictionary=game.local_state();var id: int=game.multiplayer.get_unique_id()
	return game.match_mode.tribes.enabled() and game.active and not s.is_empty() and not s.get("dead",true) and not s.get("spectator",false) and not game.menu_open and not game.match_mode.tribes.menu_open() and not game.map_loading and not game.quitting and not game.demos.playing and game.intermission<=0 and not game.match_mode.tribes.operating(id) and not game.match_mode.tribes.vehicles.piloting(id) and not game.match_mode.special.blocked(id) and not (game.hud and game.hud.chat.has_focus())
func desktop_update() -> void:
	update(game.bindings.pressed("alt_fire"),allowed() and DisplayServer.window_is_focused())
func desktop_input(event: InputEvent) -> bool:
	if not allowed():return false
	if game.bindings.matches("zoom_range",event):cycle();return true
	if game.bindings.pressed("alt_fire"):
		if game.bindings.matches("next_weapon",event):cycle();return true
		if game.bindings.matches("previous_weapon",event):cycle(-1);return true
	return false
