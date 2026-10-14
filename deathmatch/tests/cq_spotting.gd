extends SceneTree
const Base=preload("res://tools/voxel_battle/class_arena.gd")
class TestArena extends Base:
	func _load_map(_id:String)->bool:
		spawn_points=[Vector3(0,1,0),Vector3(8,1,0)];spawn_yaws=[0,PI];current_map="voxel_jungle";return true
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,title:String)->void:
	print("PASS " if ok else "FAIL ",title)
	if not ok:failures.append(title)
func scan(game)->void:
	game.clock+=.11;game.spotting.tick(game)
func run()->void:
	var game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();game.set_script(TestArena);root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.start_host("Spotter",0,100,10,false)
	for id in [2,3,4]:game._add_player(id,"Player %d"%id)
	for id in game.players:game.players[id].team=0;game._spawn(id);game.fighters[id].position=Vector3(0,1,0)
	game.players[3].team=1;game.fighters[3].position=Vector3(75.1,1,0)
	game.fighters[2].position=Vector3(-100,1,0);game.fighters[4].position=Vector3(-200,1,0)
	var spotting=game.spotting
	check(spotting.visible(game,1,2),"Allied name/icon visible at 100 metres without LOS requirement")
	game.fighters[2].position.x=-100.01
	check(not spotting.visible(game,1,2),"Allied name/icon hidden beyond 100 metres")
	scan(game);check(not spotting.visible(game,1,3),"Ordinary spotter cannot reveal enemy beyond 75 metres")
	game.fighters[3].position.x=75;scan(game)
	check(spotting.visible(game,1,3) and spotting.visible(game,2,3),"LOS at 75 metres reveals enemy to the entire team")
	game.fighters[3].position.x=500;var until:float=spotting.spotted[3][0]
	game.clock=until-.001;spotting.tick(game);check(spotting.visible(game,1,3),"Enemy label persists for almost ten seconds after contact loss")
	game.clock=until;check(not spotting.visible(game,1,3),"Enemy label expires exactly ten seconds after last LOS")
	game.classes.choose(4,"scout");game._spawn(4);game.fighters[4].position=Vector3.ZERO;game.fighters[1].position=Vector3(-200,1,0);game.fighters[3].position=Vector3(150,0,0)
	scan(game);check(spotting.visible(game,1,3),"Scout LOS at 150 metres shares enemy label with distant allies")
	spotting.spotted.clear();game.fighters[3].position.x=150.01;scan(game)
	check(not spotting.visible(game,1,3),"Scout cannot spot beyond 150 metres")
	game.fighters[3].position.x=40
	var wall:=StaticBody3D.new();wall.collision_layer=1;wall.position=Vector3(20,1,0)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1,10,10);shape.shape=box;wall.add_child(shape);game.add_child(wall)
	await physics_frame;scan(game)
	check(not spotting.visible(game,1,3),"Solid cover blocks initial spotting at both head and chest")
	wall.free();await physics_frame;scan(game)
	check(spotting.visible(game,1,3),"Removing cover allows spotting on the next scan")
	game.classes.choose(3,"scout");game._spawn(3);game.fighters[3].position=Vector3(40,0,0);game.classes.cloak(3);scan(game)
	check(not spotting.visible(game,1,3) and not spotting.spotted.has(3),"Cloak hides name/icon and cannot generate new spotting")
	game.classes.weapon_used(3);game.players[4].dead=true;scan(game)
	check(not spotting.visible(game,1,3),"Dead spotters cannot reveal enemies")
	game.players[4].dead=false;game.classes.downed[4]={"remaining":10};scan(game)
	check(not spotting.visible(game,1,3),"Incapacitated spotters cannot reveal enemies")
	game.classes.downed.erase(4);scan(game)
	var snapshot:Dictionary=game.match_mode.snapshot()
	check(snapshot["cp:3"].spot[0]>game.clock,"Team spotting deadlines included in player snapshots")
	game.match_mode.reset();check(spotting.spotted.is_empty(),"Round reset clears prior sightings")
	for role in spotting.ICONS:
		check(spotting.font().has_char(spotting.ICONS[role].unicode_at(0)),"Bundled icon font renders "+role+" class icon")
	if not game.headless:
		game.fighters[2].position=game.fighters[1].position+Vector3(10,0,0)
		game.draw_class_players()
		check(game.fighters[2].label.visible and game.fighters[2].label.fixed_size and game.fighters[2].label.text.begins_with(spotting.ICONS[game.classes.role(2)]),"Rendered allied name includes its class icon")
		check(not game.fighters[3].label.visible,"Rendered unspotted enemy label is hidden")
		spotting.spotted[3]=[game.clock+10,0.0];game.draw_class_players()
		check(game.fighters[3].label.visible,"Rendered spotted enemy name/icon is visible")
		game.clock+=10;game.draw_class_players()
		check(not game.fighters[3].label.visible,"Rendered enemy label disappears after spotting expires")
	print("CQ_SPOTTING_RESULT ",JSON.stringify(failures));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
