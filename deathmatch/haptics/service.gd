extends Node
## Local presentation only. Never initialize this service on a server.
const Preferences=preload("res://deathmatch/haptics/preferences.gd")
const GameProfile=preload("res://deathmatch/haptics/profile.gd")
const Output=preload("res://deathmatch/haptics/osc.gd")
var game
var values:=Preferences.defaults()
var profile:=GameProfile.new()
var health_serial:=-1
var health_last:=-1
var healed_pending:=0
var last_effect:=""
var output=Output.new()
var native_output: RefCounted
var focused:=true
var cooldowns: Dictionary={}
var testing_until:=0.0
var was_allowed:=false
func setup(arena: Node) -> void:
	game=arena;name="ClientHaptics";configure(Preferences.read_settings())
func configure(settings: Dictionary) -> void:
	var previous:=values
	values=Preferences.sanitize(settings);stop()
	var reuse: bool=output.is_open() and previous.backend==values.backend and values.enabled and client_available() and (values.backend=="ble" or previous.host==values.host and previous.port==values.port)
	if not reuse:
		output.close()
		if values.backend=="ble":
			if not native_output:native_output=load("res://deathmatch/haptics/native.gd").new()
			output=native_output
		else:output=Output.new()
		if values.enabled and client_available():output.open(values.host,values.port)
	if values.backend=="ble":output.intensity=values.intensity
	set_process(true)
func client_available() -> bool:
	return game!=null and not game.headless and not game.dedicated and not OS.has_feature("dedicated_server")
func has_focus() -> bool:
	if not client_available() or game.quitting:return false
	if game.is_vr():return game.xr_rig.focused and game.xr_rig.head_tracked()
	return focused
func context_allowed() -> bool:
	return values.enabled and has_focus() and game.active and not game.menu_open and not game.map_loading and not game.demos.playing
func accepts(id: int) -> bool:
	return output.is_open() and context_allowed() and id==game.multiplayer.get_unique_id() and game.players.has(id) and not game.players[id].get("spectator",false)
func claim(key: String,interval: float,now: float) -> bool:
	if now<float(cooldowns.get(key,-1.0)):return false
	cooldowns[key]=now+interval;return true
func play_effect(effect: String,target: Array,scale: float=1.0) -> void:
	if effect.is_empty():return
	last_effect=effect
	var now:=Time.get_ticks_msec()*.001
	output.sequence(profile.sequence(effect,target,scale),now);output.tick(now)
func shot(id: int,weapon: int,offhand: bool=false,alternate: bool=false) -> void:
	if not values.recoil or not accepts(id) or game.players[id].get("dead",false):return
	var now:=Time.get_ticks_msec()*.001
	if not claim("offhand" if offhand else "shot",.07,now):return
	var use_left: bool=game.is_vr() and game.xr_rig.left_handed!=offhand
	if not game.is_vr():use_left=offhand
	var title: String=game.armory.data(weapon,alternate).name
	play_effect(profile.recoil(title),[0,1,4,5] if use_left else [2,3,6,7],.8 if alternate else 1.0)
static func impact_motors(direction: Vector3,body_basis: Basis) -> Array:
	if not direction.is_finite() or direction.length_squared()<.01 or not body_basis.is_finite() or absf(body_basis.determinant())<.01:return [5,6,9,10,25,26,29,30]
	# Damage direction travels into the victim. Negate to find its source.
	var source:=body_basis.inverse()*-direction
	if Vector2(source.x,source.z).length()<.1:return [5,6,9,10,25,26,29,30]
	if absf(source.x)>absf(source.z):
		return [0,4,8,12,23,27,31,35] if source.x<0 else [3,7,11,15,20,24,28,32]
	return [5,6,9,10] if source.z<0 else [25,26,29,30]
func body_basis() -> Basis:
	if game.is_vr():
		var rig=game.xr_rig
		if rig.tracking:
			var body: Dictionary=rig.tracking.sample()
			for role in ["chest","hips"]:
				if body.has(role):return Basis(Vector3.UP,(rig.global_basis*body[role].basis).get_euler().y)
		return Basis(Vector3.UP,rig.head.global_rotation.y)
	return Basis(Vector3.UP,game.local_yaw)
func hurt(id: int,direction: Vector3,amount: int,dead: bool,screen_only: bool=false,impact: Vector3=Vector3.INF,weapon: String="",blast: bool=false) -> void:
	if screen_only or amount<=0 or not accepts(id):return
	var effect:=profile.damage(weapon,blast)
	if effect.begins_with("environment_"):
		if not values.environment:return
	elif not values.damage:return
	var now:=Time.get_ticks_msec()*.001
	if not dead and not claim("hurt",.09,now):return
	var target:=impact_motors(direction,body_basis())
	if impact.is_finite() and game.fighters.has(id):
		var actor=game.fighters[id]
		target=GameProfile.hit_zone(direction,body_basis(),impact,actor.global_position,actor.collision_height)
	if dead:output.stop();effect="death"
	play_effect(effect,target,clampf(.55+amount/100.0,.55,1.0))
func pickup(id: int,kind: String) -> void:
	# Health comes from observed HP gains, including medics, regeneration and lifesteal.
	if not values.pickups or not accepts(id) or kind not in ["armor","power"]:return
	var now:=Time.get_ticks_msec()*.001
	if claim("pickup",.3,now):play_effect(kind,[13,14])
func observe_health() -> void:
	var id: int=game.multiplayer.get_unique_id()
	if not game.players.has(id):health_last=-1;health_serial=-1;healed_pending=0;return
	var state: Dictionary=game.players[id]
	var hp: int=int(state.get("hp",0))
	var serial: int=int(state.get("serial",0))
	var gained: int=hp-health_last if health_last>=0 and serial==health_serial else 0
	health_last=hp;health_serial=serial
	if not values.healing or not accepts(id) or state.get("dead",false):healed_pending=0;return
	healed_pending+=maxi(0,gained)
	if healed_pending>0 and claim("healing",.8,Time.get_ticks_msec()*.001):
		play_effect("healing",[],clampf(.65+healed_pending/100.0,.65,1.0));healed_pending=0
func test_pulse() -> bool:
	if not values.enabled or not has_focus() or not output.is_open() or game.demos.playing:return false
	if values.backend=="ble" and not output.bridge.device_connected():return false
	var now:=Time.get_ticks_msec()*.001
	if not claim("test",.5,now):return false
	output.stop();testing_until=now+.15;output.pulse([5,6],.15,now);output.tick(now);return true
func status_text() -> String:
	if not client_available():return "bHaptics is available on graphical clients only."
	if values.backend=="osc" and not Preferences.valid_endpoint(values.host,values.port):return "Enter a valid receiver IP address and UDP port."
	if not values.enabled:return "bHaptics is off."
	if not output.error.is_empty():return output.error
	if values.backend=="ble":return output.status_text()
	if not output.is_open():return "OSC output is unavailable."
	return "OSC output to %s:%d · Suit connection is not reported by OSC."%[values.host,values.port]
func stop() -> void:
	testing_until=0;cooldowns.clear();was_allowed=false;healed_pending=0;health_last=-1;health_serial=-1;output.stop()
func shutdown() -> void:
	stop();output.close();set_process(false)
func _process(_delta: float) -> void:
	if not output.is_open():return
	observe_health()
	if not client_available():shutdown();return
	var now:=Time.get_ticks_msec()*.001
	var allowed: bool=context_allowed() or (testing_until>now and has_focus() and not game.demos.playing)
	if not allowed and (was_allowed or output.has_pending(now)):stop()
	was_allowed=allowed
	output.tick(now)
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused=false
		if game!=null and not game.is_vr():stop()
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:focused=true
func _exit_tree() -> void:output.close()
