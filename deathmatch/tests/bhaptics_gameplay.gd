extends SceneTree
## Opt-in hardware simulation through the same service/profile used by gameplay.
const Service=preload("res://deathmatch/haptics/service.gd")
const Fixture=preload("res://deathmatch/tests/bhaptics.gd").Fixture
var game: Node
var service: Node
var failures: Array=[]
var results: Array=[]
class Actor extends Node3D:
	var collision_height:=1.65
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> bool:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
	return ok
func stats() -> Dictionary:return JSON.parse_string(service.output.bridge.diagnostics_json())
func connected() -> bool:return service.output.bridge.device_connected() and stats().write_errors==0
func scenarios() -> Array:
	var rows: Array=[]
	for weapon in 10:
		rows.append({"label":"Fire "+preload("res://deathmatch/weapons.gd").DATA[weapon].name,"event":"shot","rules":"doom","weapon":weapon,"repeat":6 if weapon in [1,5,7] else 1})
	for extra in [["quake",4,"Grenade launcher"],["quake",7,"Super nailgun"],["quake",8,"Lightning gun"],["ut99",3,"Shock rifle alt-fire"],["ut99",4,"Flak cannon"],["ut99",8,"Redeemer"],["ut99",9,"Sniper rifle"]]:
		rows.append({"label":"Fire "+extra[2],"event":"shot","rules":extra[0],"weapon":extra[1],"alternate":extra[2].contains("alt")})
	rows.append({"label":"Dual pistols, alternating hands","event":"dual"})
	for hit in [
		["Pistol to front chest","PISTOL",Vector3(0,1,-.2),Vector3.BACK,12],
		["Shotgun to rear abdomen","SHOTGUN",Vector3(0,.55,.2),Vector3.FORWARD,35],
		["Super shotgun to left shoulder","SUPER SHOTGUN",Vector3(-.3,1.3,0),Vector3.RIGHT,60],
		["Chaingun to right arm","CHAINGUN",Vector3(.3,1.1,0),Vector3.LEFT,10],
		["Plasma to front abdomen","PLASMA RIFLE",Vector3(0,.6,-.2),Vector3.BACK,20],
		["Railgun head hit represented at vest top","RAILGUN",Vector3(0,1.55,-.2),Vector3.BACK,70],
		["Nailgun to left leg represented at vest bottom","NAILGUN",Vector3(-.2,.2,0),Vector3.RIGHT,9],
		["Axe to rear upper torso","AXE",Vector3(0,1.3,.2),Vector3.FORWARD,20]]:
		rows.append({"label":hit[0],"event":"hurt","weapon_name":hit[1],"position":hit[2],"direction":hit[3],"amount":hit[4]})
	for hit in [["Rocket explosion from left",Vector3.RIGHT,50],["Grenade explosion behind",Vector3.FORWARD,35],["Rocket jump / blast below",Vector3.UP,20]]:
		rows.append({"label":hit[0],"event":"hurt","weapon_name":"ROCKET LAUNCHER","position":Vector3(0,.8,0),"direction":hit[1],"amount":hit[2],"blast":true})
	for weapon in ["LAVA","SLIME","BURN","DROWNING","FALL","environment"]:
		rows.append({"label":"Environment: "+weapon,"event":"hurt","weapon_name":weapon,"amount":20})
	rows.append({"label":"Health pickup +25","event":"heal","amount":25})
	rows.append({"label":"Medic treatment +35","event":"heal","amount":35})
	rows.append({"label":"Regeneration +5","event":"heal","amount":5})
	rows.append({"label":"Armor pickup","event":"pickup","kind":"armor"})
	rows.append({"label":"Fatal impact","event":"hurt","weapon_name":"SHOTGUN","amount":80,"dead":true})
	return rows
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1:push_error("Requires one exact X40 ID after --");quit(2);return
	game=Fixture.new();root.add_child(game)
	var actor:=Actor.new();game.add_child(actor);game.fighters[1]=actor
	game.players[1].hp=50;game.players[1].serial=1
	service=Service.new();game.add_child(service);game.haptics=service;service.game=game
	service.configure({"enabled":true,"backend":"ble","intensity":.25,"pickups":true})
	if not check(service.output.is_open(),"Native profile backend opens"):await finish();return
	service.output.scan()
	var start:=Time.get_ticks_msec()
	while service.output.status_text().begins_with("Scanning") and Time.get_ticks_msec()-start<12000:await process_frame
	var selected:=""
	for device in service.output.devices():
		if str(device.id)==args[0] and str(device.name)=="TactSuitX40":selected=str(device.id)
	if not check(not selected.is_empty() and service.output.connect_device(selected),"Selected X40 connection requested"):await finish();return
	start=Time.get_ticks_msec()
	while service.output.status_text().begins_with("Connecting") and Time.get_ticks_msec()-start<10000:await process_frame
	if not check(connected(),"Connected directly to X40"):await finish();return
	var cases:=scenarios()
	for index in cases.size():
		var scenario: Dictionary=cases[index]
		print("SIMULATION ",index+1,"/",cases.size()," ",scenario.label)
		service.stop();service.last_effect=""
		await create_timer(.2).timeout
		var before:=stats()
		match scenario.event:
			"shot":
				game.armory.select(scenario.rules)
				for shot in int(scenario.get("repeat",1)):
					service.shot(1,scenario.weapon,false,scenario.get("alternate",false));await create_timer(.12).timeout
			"dual":
				game.armory.select("doom")
				for shot in 6:service.shot(1,2,shot%2==1);await create_timer(.15).timeout
			"hurt":service.hurt(1,scenario.get("direction",Vector3.ZERO),scenario.amount,scenario.get("dead",false),false,scenario.get("position",Vector3.INF),scenario.weapon_name,scenario.get("blast",false))
			"heal":game.players[1].hp=50;service.observe_health();game.players[1].hp+=int(scenario.amount);service.observe_health()
			"pickup":service.pickup(1,scenario.kind)
		await create_timer(1.35).timeout
		var after:=stats()
		var ok: bool=connected() and after.active_writes>before.active_writes and after.last_active_motors==0
		results.append({"scenario":scenario.label,"effect":service.last_effect,"passed":ok,"active_writes":after.active_writes-before.active_writes,"frame_changes":after.frame_changes-before.frame_changes})
		if not check(ok,scenario.label+" produced output and released all motors"):await finish();return
	await finish()
func finish() -> void:
	var final_stats: Dictionary={}
	if service and service.output.bridge:
		final_stats=stats();service.shutdown()
		var start:=Time.get_ticks_msec()
		while service.output.bridge.is_running() and Time.get_ticks_msec()-start<5000:await process_frame
		check(not service.output.bridge.is_running(),"Simulation worker exits cleanly")
	var report: Dictionary={"date":Time.get_datetime_string_from_system(),"profile":"fpsloppa-vest-v1","intensity":.25,"results":results,"failures":failures,"diagnostics":final_stats}
	var file:=FileAccess.open("res://test-results/bhaptics-gameplay.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	print("BHAPTICS_GAMEPLAY_RESULT ",JSON.stringify(report))
	if game:game.free()
	quit(0 if failures.is_empty() else 1)
