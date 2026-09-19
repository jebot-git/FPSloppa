extends SceneTree
const OUT="res://test-results/titanball/balance-2026-09/layout-r2/"
var game
var camera: Camera3D
func _initialize():run.call_deferred()
func shot(label: String,position: Vector3,target: Vector3) -> void:
	camera.position=position;camera.look_at(target);camera.make_current()
	for frame in 12:await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT+label+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	assert(DisplayServer.get_name()!="headless")
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.selected_map="tb_ashfall";game.start_host("Ashfall balance preview",0,100,10,true,"tb")
	game.set_physics_process(false);game.set_process(false)
	game.bots.free();game.bots=null
	game.match_mode.fortress.draw()
	for id in game.players:game.players[id].spectator=true;game.fighters[id].hide()
	game.match_mode.titanball.advance_time(60.)
	for layer in game.find_children("*","CanvasLayer",true,false):layer.hide()
	if is_instance_valid(game.viewmodel):game.viewmodel.hide()
	camera=Camera3D.new();camera.fov=80;camera.cull_mask=game.camera.cull_mask;game.add_child(camera)
	var walkers=game.match_mode.fortress.walkers
	var route: Curve3D=walkers.robots.values()[0].path
	for distance in [80.,230.]:
		var approach: Transform3D=walkers.Route.sample(route,distance-18.)
		var checkpoint: Transform3D=walkers.Route.sample(route,distance)
		await shot("checkpoint-%d"%int(distance),approach*Vector3(0,5,0),checkpoint*Vector3(0,6,3))
	var balcony: Transform3D=walkers.Route.sample(route,46.)
	await shot("side-balconies",balcony*Vector3(-5,8,-10),balcony*Vector3(15.4,6,0))
	var bridge: Transform3D=walkers.Route.sample(route,92.)
	await shot("overpass-access",bridge*Vector3(-6,9,-16),bridge*Vector3(14.3,8,0))
	var middle: Transform3D=walkers.Route.sample(route,179.)
	await shot("middle-overpass",middle*Vector3(-5,10,-23),middle*Vector3(0,9,3))
	for side in [-1.,1.]:
		await shot("balcony-link-%d"%int(side),middle*Vector3(side*7,10,23),middle*Vector3(side*14.3,9,7))
	var final: Transform3D=walkers.Route.sample(route,275.)
	await shot("final-approach",final*Vector3(0,20,-15),walkers.Route.sample(route,325.).origin+Vector3.UP*3)
	for distance in [70.,104.,215.,246.]:
		var station: Transform3D=walkers.Route.sample(route,distance)
		var side: float=16. if distance in [70.,215.] else -9.5
		await shot("resupply-%d"%int(distance),station*Vector3(side*.4,5,-8),station*Vector3(side,1,0))
	game.disconnect_game();game.free();print("TB_BALANCE_PREVIEW_PASS");quit()
