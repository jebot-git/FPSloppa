extends SceneTree
const Profile=preload("res://deathmatch/haptics/profile.gd")
const Output=preload("res://deathmatch/haptics/osc.gd")
const Service=preload("res://deathmatch/haptics/service.gd")
const Prefs=preload("res://deathmatch/haptics/preferences.gd")
const Fixture=preload("res://deathmatch/tests/bhaptics.gd").Fixture
var failures: Array=[]
class MemoryOutput extends Output:
	var opened:=true
	var frames: Array=[]
	func is_open() -> bool:return opened
	func _send_levels(levels: PackedByteArray) -> void:frames.append(levels)
	func _send(_states: PackedByteArray) -> void:pass
	func close() -> void:stop();opened=false
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var profile:=Profile.new()
	check(profile.data.get("id")=="fpsloppa-vest-v1","Game profile loads")
	var output:=MemoryOutput.new()
	for effect in profile.data.effects:
		output.stop();output.sequence(profile.sequence(effect,[5,6]),10)
		var active:=false
		for i in 30:
			var levels:=output.levels_at(10+i*.05)
			active=active or levels.count(0)<40
			for value in levels:
				if value>15:check(false,"Unbounded profile intensity")
		check(active and output.levels_at(12).count(0)==40,"Bounded finite profile effect: "+effect)
	check(Profile.hit_zone(Vector3.BACK,Basis.IDENTITY,Vector3(0,1.55,-.2))==[1,2],"Head hit maps to upper front vest")
	check(Profile.hit_zone(Vector3.FORWARD,Basis.IDENTITY,Vector3(0,.55,.2))==[33,34],"Rear abdomen hit maps to lower back")
	check(Profile.hit_zone(Vector3.RIGHT,Basis.IDENTITY,Vector3(-.3,1.2,0))==[4,27],"Left arm hit maps to left vest edges")
	check(Profile.hit_zone(Vector3.LEFT,Basis.IDENTITY,Vector3(.2,.2,0))==[19,36],"Right leg hit maps to lower vest edges")
	check(Profile.hit_zone(Vector3.RIGHT,Basis(Vector3.UP,PI/2),Vector3(-.2,1.55,0))==[1,2],"Tracked yaw rotates hit localization")
	check(profile.damage("SHOTGUN")=="hit_shotgun" and profile.damage("SHOTGUN",true)=="hit_blast","Authoritative explosion context overrides weapon family")
	check(Prefs.Platform.default_backend("Linux","x86_64")=="ble" and Prefs.Platform.default_backend("Windows","x86_64")=="ble","Native is preferred on both desktop build targets")
	check(Prefs.Platform.default_backend("Android","arm64")=="ble","Android ARM64 defaults to native Bluetooth")
	check(Prefs.Platform.default_backend("Android","x86_64")=="osc" and not Prefs.Platform.supports_native("Linux","arm64"),"Unsupported native targets retain OSC")
	check(Prefs.sanitize({"backend":"osc"}).backend=="osc" and not Prefs.defaults().enabled,"Explicit OSC preferences persist; feedback remains opt-in")
	var g:=Fixture.new();root.add_child(g)
	g.players[1].hp=50;g.players[1].serial=1
	var service:=Service.new();g.add_child(service);service.game=g;g.haptics=service
	service.output=output;service.values=Prefs.sanitize({"enabled":true,"backend":"osc"});service.set_process(false)
	for rules in ["doom","quake","ut99"]:
		g.armory.select(rules)
		for weapon in g.armory.table.size():
			service.stop();service.shot(1,weapon)
			check(output.has_pending(Time.get_ticks_msec()*.001)==(g.armory.data(weapon).name!="TRANSLOCATOR"),"Weapon profile resolves: "+rules+" / "+g.armory.data(weapon).name)
	service.stop();service.observe_health();g.players[1].hp=75;service.observe_health()
	check(service.last_effect=="healing" and not output.cues.is_empty(),"Observed health gain plays healing wave")
	service.stop();service.last_effect="";g.players[1].serial=2;g.players[1].hp=100;service.observe_health()
	check(output.cues.is_empty(),"Respawn health reset is not healing")
	g.menu_open=true;g.players[1].hp=120;service.observe_health();g.menu_open=false;service.observe_health()
	check(output.cues.is_empty(),"Suppressed health gains do not replay on menu close")
	service.hurt(1,Vector3.ZERO,20,false,false,Vector3.INF,"LAVA")
	check(service.last_effect=="environment_fire","Lava selects heat pattern")
	service.stop();service.values.environment=false;service.hurt(1,Vector3.ZERO,20,false,false,Vector3.INF,"DROWNING")
	check(output.cues.is_empty(),"Environment toggle suppresses hazard patterns")
	service.values.environment=true;service.hurt(1,Vector3.BACK,20,false,false,Vector3.INF,"SHOTGUN")
	g.menu_open=true;service._process(0)
	check(output.cues.is_empty(),"Menu stop clears future pattern stages")
	service.shutdown();g.free()
	print("BHAPTICS_PROFILE_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
