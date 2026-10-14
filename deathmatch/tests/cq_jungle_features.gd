extends SceneTree
const Base=preload("res://tools/voxel_battle/class_arena.gd")
const Lighting=preload("res://tools/voxel_battle/baked_lighting.gd")
class TestArena extends Base:
	func _load_map(_id:String)->bool:
		spawn_points=[Vector3(0,1,0)];spawn_yaws=[0];current_map="voxel_jungle";return true
class Interface extends Node:
	var menu_pages=preload("res://deathmatch/ui/menu_pages.gd").new()
	func _ready():
		add_child(menu_pages);menu_pages.add_page("home","CQ");menu_pages.add_page("player","PLAYER")
	func button(parent,title,action):
		var result:=Button.new();result.text=title;parent.add_child(result);result.pressed.connect(action);return result
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.start_host("Features",0,100,10,false)
	var hud:=Interface.new();root.add_child(hud)
	var menu=preload("res://deathmatch/conquest/classes/loadout_menu.gd").new();root.add_child(menu);menu.setup(game,hud)
	for role in game.classes.CLASSES:
		menu.choose_class(role)
		check(hud.menu_pages.current=="cq_loadout" and game.classes.states[1].next==role,role+" class opens its loadout and requests next-spawn class")
		var visible:=[]
		for row in menu.buttons:
			if row.button.visible:visible.append(row)
		check(visible.size()==(6 if role in ["scout","shocktroop","medic","technician"] else 5) and visible.filter(func(row):return row.slot=="UTILITY").size()==(2 if role in ["scout","shocktroop","medic","technician"] else 1),role+" shows weapons and available utility tiers")
		check(visible.filter(func(row):return row.tier==2).all(func(row):return row.button.disabled),role+" tier-two gear remains XP locked")
		var utility:String=game.classes.UTILITIES[role][0].id
		menu.select(role,"UTILITY",utility);game._spawn(1)
		check(game.classes.states[1].equipped_utility==utility,role+" chosen utility kit equipped on spawn")
		check(not game.classes.choose_utility(1,role,"invalid") and not game.classes.choose_utility(99,role,utility),role+" authority rejects invalid utility and unknown player")
	game.classes.award(1,5000);menu.refresh()
	check(menu.buttons.filter(func(row):return row.role=="technician" and row.tier==2 and row.slot!="UTILITY").all(func(row):return not row.button.disabled),"Menu unlocks T2 weapons after authoritative XP award")
	check(menu.buttons.filter(func(row):return row.role=="technician" and row.tier==2 and row.slot=="UTILITY").all(func(row):return row.button.disabled),"Technician T2 utility remains locked below level 15")
	game.classes.award(1,2500);menu.refresh()
	check(menu.buttons.filter(func(row):return row.role=="technician" and row.tier==2).all(func(row):return not row.button.disabled),"Menu unlocks all technician T2 equipment at level 15")
	menu.select("technician","PRIMARY",11);menu.select("technician","SECONDARY",0)
	check(game.players[1].weapon!=11,"Selecting a loadout does not refill the current life")
	game._spawn(1);check(game.players[1].owned.slice(0,2)==[11,0],"Selected primary and secondary apply together on respawn")
	check(game.match_mode.snapshot()["cp:1"].state.utility_choices.technician=="engineering","Utility selection included in player snapshot")
	var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Lighting.ROOT+"bake.json"))
	check(metadata.source_sha256==Lighting.source_fingerprint(),"Bake matches authoritative geometry sources")
	check(metadata.meshes.size()==11 and metadata.lamps.size()==384,"All eleven sites and 384 static fixture sources are baked")
	var fixtures=Base.BattleMap.Architecture.Fixtures
	var authored:Array=fixtures.rows(Base.BattleMap.Architecture.specifications())
	check(authored.size()==metadata.lamps.size(),"Bake and fixture geometry share one source layout")
	var outdoor:=0
	for row in authored:
		if row.type not in ["lamppost","floodlight"]:continue
		outdoor+=1
		var p:Vector3=row.local
		var side:float=row.get("side",1.0)
		var foot:=p+(Vector3(side*.9,0,0) if row.type=="lamppost" else Vector3(0,0,side*.9))
		for building in Base.BattleMap.Architecture.specifications():
			if building.kind!=row.kind:continue
			check(absf(foot.x-building.center.x)>building.size.x/2+.08 or absf(foot.z-building.center.z)>building.size.y/2+.08,"Outdoor post clear of building: %s %s"%[row.kind,p])
	check(outdoor==92,"Every POI has eight outdoor fixtures plus four dock lamps")
	var total:=0
	for levels in metadata.meshes:
		for path in levels:
			var mesh:ArrayMesh=load(path);var arrays:Array=mesh.surface_get_arrays(0)
			total+=arrays[Mesh.ARRAY_VERTEX].size()
			check(arrays[Mesh.ARRAY_CUSTOM0].size()==arrays[Mesh.ARRAY_VERTEX].size()*4,"Day/night irradiance present: "+path.get_file())
			check(arrays[Mesh.ARRAY_CUSTOM1].size()==arrays[Mesh.ARRAY_VERTEX].size()*4,"Dawn irradiance present: "+path.get_file())
	var sky:=Image.load_from_file(Lighting.ROOT+"skybox.png")
	check(sky.get_width()==4096 and sky.get_height()==1024 and sky.get_pixel(512,32).b>sky.get_pixel(512,32).r,"Sky atlas contains eight usable image layers and a blue daytime sky")
	check(total==metadata.baked_vertices,"Every structure LOD vertex carries baked lighting")
	check(Lighting.day_weight(0)==1 and Lighting.day_weight(600)==0 and Lighting.day_weight(1200)==1 and absf(Lighting.day_weight(372)-.5)<.0001,"Twenty-minute day/night cycle has smooth transitions and wraps")
	var atlas:=Image.load_from_file(Lighting.ROOT+"irradiance.png")
	for kind in 11:
		var row:Dictionary=metadata.lamps.filter(func(lamp):return int(lamp.kind)==kind and lamp.type=="lamppost")[0]
		var uv:=Vector2(row.position[0],row.position[2])/Base.BattleMap.Landscape.EXTENT+Vector2(.5,.5)
		check(atlas.get_pixel(int(uv.x*atlas.get_width()),int(uv.y*atlas.get_height())).g>.15,"POI %d has a baked outdoor light pool"%kind)
	var p:=Vector2(-1000,-300)/Base.BattleMap.Landscape.EXTENT+Vector2(.5,.5)
	check(atlas.get_pixel(int(p.x*atlas.get_width()),int(p.y*atlas.get_height())).g==0,"Forest has no baked night fixture illumination")
	var holder:=Node3D.new();holder.set_script(Base.BattleMap);game.battle_map=holder;game.add_child(holder)
	var grass=preload("res://tools/voxel_battle/grass.gd").new();holder.add_child(grass);holder.grass=grass
	var audio=preload("res://tools/voxel_battle/grass_audio.gd").new();holder.add_child(audio);audio.game=game
	var point:=Vector3(-1000,3,-300);var coord:Vector2i=audio.Landscape.bin_key(Vector2(point.x,point.z))
	grass.tiles[coord]={"rows":PackedVector4Array([Vector4(point.x,point.y,point.z,1)])}
	check(audio.contains(point) and not audio.contains(point+Vector3.RIGHT*5),"Rustling follows grass coverage, not bare road space")
	grass.enabled=false;check(audio.contains(point),"Rustling survives render culling and grass display toggles")
	for i in 3:check(load("res://deathmatch/audio/jungle/rustle_%d.wav"%i).get_length()>.4,"Rustle clip imports: "+str(i))
	check(audio.RADIUS==12 and audio.VOICES==8,"Rustling uses bounded voices and a twelve-metre audible radius")
	game.battle_map=null;holder.free();hud.free();menu.free();game.disconnect_game();game.free()
	print("CQ_JUNGLE_FEATURES_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
