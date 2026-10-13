extends SceneTree
var failures:Array=[]
func check(ok:bool,label:String)->void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("17232e");world.add_child(environment)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5;camera.position=Vector3(0,3,7);world.add_child(camera);camera.look_at(Vector3.ZERO);camera.current=true
	var fx=preload("res://deathmatch/conquest/classes/visuals.gd").new();world.add_child(fx)
	for n in 20:await process_frame
	for team in 2:
		var color:=Color("ff3c39") if team==0 else Color("3b8dff")
		for kind in ["energy","ordnance"]:
			var d:Dictionary={"kind":"pulse" if kind=="energy" else "rocket","cq_effect":kind,"color":color}
			var node:Node3D=fx.projectile("ut99",d);world.add_child(node);node.position=Vector3(-1.4+team*2.8,1,0 if kind=="energy" else -1.1);node.rotation.y=PI/2
			check(node.get_meta("color").is_equal_approx(color),kind+" uses its firing team's color")
			fx.burst("ut99",Vector3(-1.4+team*2.8,0,0 if kind=="energy" else -1.4),4 if kind=="energy" else 5,d.kind,d)
		fx.impacts("ut99",Vector3(-1.7+team*2.8,0,1.5),PackedVector3Array([Vector3(-.9+team*2.8,0,1.5)]),9 if team else 2,{"kind":"sniper" if team else "hitscan"})
	check(fx.pool_stats.straight_tracers==2,"Both pistols use the standard CS bullet tracer")
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/weapon-sources/effects.png")
	print("CQ_EFFECTS_RESULT ",JSON.stringify(failures));world.free();quit(0 if failures.is_empty() else 1)
