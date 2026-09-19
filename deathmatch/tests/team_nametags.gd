extends SceneTree
const Fighter=preload("res://deathmatch/fighter.gd")
const Mode=preload("res://deathmatch/modes/match.gd")
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	root.size=Vector2i(1100,650)
	var stage:=Node3D.new();root.add_child(stage)
	var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("17232d");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.8;stage.add_child(world)
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,1.7,5);camera.fov=60;camera.make_current()
	for team in 2:
		var actor:=Fighter.new();actor.setup(team+2,"PLAYER",Mode.COLORS[team]);stage.add_child(actor);actor.position.x=-1 if team==0 else 1
		actor.set_process(false)
		if not actor.label:actor.label=Label3D.new();actor.add_child(actor.label)
		actor.set_nametag("RED PLAYER" if team==0 else "BLUE PLAYER",team,Mode.COLORS[team]);actor.show_alive(true,false)
		check(actor.label.text.begins_with("◆ " if team==0 else "● "),"Team "+str(team)+" has a distinct colour and shape icon beside name")
		check(not actor.label.no_depth_test,"Nametag remains occluded by world geometry")
		actor.show_alive(false,false);check(not actor.label.visible,"Dead player's team icon is hidden with name")
		actor.show_alive(true,true);check(not actor.label.visible,"Local player does not see their own icon")
		actor.show_alive(true,false)
		if actor.avatar:
			actor.set_cloak_visual(true,false,Mode.COLORS[team],1.0)
			check(not actor.label.visible,"Enemy cloak hides name and team icon together")
			actor.set_cloak_visual(false,false,Mode.COLORS[team],1.0);actor.show_alive(true,false)
		actor.set_nametag("FFA PLAYER",-1,Color.WHITE)
		check(actor.label.text=="FFA PLAYER","Free-for-all has no team icon")
		actor.set_nametag("RED PLAYER" if team==0 else "BLUE PLAYER",team,Mode.COLORS[team])
	for frame in 8:await process_frame
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw(false)
		DirAccess.make_dir_recursive_absolute("res://test-results/tf-audit")
		root.get_texture().get_image().save_png("res://test-results/tf-audit/team-nametags.png")
	print("TEAM_NAMETAGS_RESULT ",JSON.stringify(failures));stage.free();quit(0 if failures.is_empty() else 1)
