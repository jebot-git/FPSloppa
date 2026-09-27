extends SceneTree
## Audit shipped BSP entities through the real mapper and authoritative collection.
const Reader=preload("res://addons/bsp_importer/bsp_reader.gd")
const Runtime=preload("res://deathmatch/maps/runtime.gd")
var game
var failures: Array=[]
var checks:=0
var audit: Array=[]
var unavailable: Array=[]

func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)

func exercise(p: Dictionary,label: String) -> void:
	game.clock=1000.0
	var state: Dictionary=game.players[1]
	state.dead=false;state.spectator=false;state.hp=1;state.armor=0
	state.owned=[2];state.ammo=[0,0,0,0]
	game.fighters[1].position=p.position
	game._collect(1)
	if game.match_mode.defusal.enabled():
		check(p.available and p.respawn==0,label+": DE does not automatically collect arena supplies")
		return
	if game.match_mode.fixed_loadout():
		check(p.available and p.respawn==0,label+": fixed loadout cannot consume map supplies")
		return
	var delay:=30.0 if p.kind!="weapon" or game.match_mode.kind=="tdm" else 5.0
	check(not p.available and is_equal_approx(p.respawn,1000.0+delay),label+": collection deadline")
	var after: Array=[state.hp,state.armor,state.ammo.duplicate(),state.owned.duplicate()]
	game._collect(1)
	check(after==[state.hp,state.armor,state.ammo,state.owned],label+": unavailable pickup cannot be claimed twice")
	game.clock=1000.0+delay-.01;game._respawn_pickups()
	check(not p.available,label+": no early respawn")
	game.clock=1000.0+delay;game._respawn_pickups()
	check(p.available,label+": respawns at exact deadline")

func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false)
	game.active=true;game.spawn_points=[Vector3(1000,10,1000)];game.spawn_yaws=[0.0]
	game._add_player(1,"Timer audit")
	var runtime=Runtime.new();runtime.game=game
	var reader=Reader.new()
	var manifest: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json"))
	for row in manifest:
		var path: String=row.path
		if not FileAccess.file_exists(path):
			for folder in ["optional-librequake/maps/","optional-community/maps/","optional-map-pack/","optional-tf-map-pack/"]:
				var candidate: String="res://"+folder+path.get_file()
				if FileAccess.file_exists(candidate):path=candidate;break
		if not FileAccess.file_exists(path):
			unavailable.append(row.id)
			check(row.get("distribution","")!="base",row.id+": base BSP exists")
			continue
		var file:=FileAccess.open(path,FileAccess.READ)
		file.seek(4);var offset:=file.get_32();var length:=file.get_32();file.seek(offset)
		var entities: Array=reader.parse_entity_string(file.get_buffer(length).get_string_from_ascii())
		var weapons:=0;var slot8:=0;var overrides: Array=[]
		for entity in entities:
			if int(entity.get("spawnflags",0))&2048:continue
			var classname: String=entity.get("classname","")
			if classname.begins_with("weapon_"):
				weapons+=1
				if classname=="weapon_lightning":slot8+=1
				if entity.has("wait") or entity.has("random"):overrides.append(entity)
			if not classname.begins_with("weapon_") and not classname.begins_with("item_"):continue
			for mode in row.modes:
				game.match_mode.kind=mode
				for preset in (["cs16"] if mode=="de" else ["ut99"] if mode=="as" else ["quake"] if mode in ["tf","tb"] else ["doom","quake","ut99"]):
					game.armory.select(preset);game.pickups.clear()
					runtime.add_pickup(entity,Vector3.ZERO)
					if game.pickups.is_empty():continue
					exercise(game.pickups[0],row.id+"/"+mode+"/"+preset+"/"+classname)
		audit.append({"map":row.id,"path":path,"sha256":FileAccess.get_sha256(path),"modes":row.modes,"weapons":weapons,"slot8":slot8,"timer_overrides":overrides})
		print("MAP_WEAPON_AUDIT ",JSON.stringify(audit.back()))
	# Check mode distinctions even when their optional map packs are absent.
	for mode in ["dm","tdm","ctf","koth","ft","as","ig","if","cc"]:
		game.match_mode.kind=mode
		for preset in ["doom","quake","ut99"]:
			game.armory.select(preset)
			for item in [3,8]:
				game.pickups=[{"kind":"weapon","item":item,"position":Vector3.ZERO,"available":true,"respawn":0.0,"node":null}]
				exercise(game.pickups[0],mode+"/"+preset+"/slot"+str(item))
	check(game.pickup_respawn_delay({"kind":"weapon","item":8,"dropped":true})==INF,"Death drops never acquire a map respawn timer")
	check(not audit.is_empty(),"At least one implemented map was audited")
	reader.free();runtime.free();game.active=false;game.free()
	print("WEAPON_RESPAWNS_RESULT ",JSON.stringify({"checks":checks,"maps":audit.size(),"unavailable":unavailable,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
