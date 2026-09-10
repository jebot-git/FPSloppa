extends SceneTree
const Poses=preload("res://deathmatch/vr/poses.gd")
var failures: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	game.voice.set_mode(0);game.headless=false;game.active=true;game.lobby.build()
	game.camera=Camera3D.new();game.add_child(game.camera);game.camera.current=true
	game.camera.position=Vector3(6.5,1.7,-5);game.camera.look_at(Vector3(6.5,1.25,-11.3))
	var actor=preload("res://deathmatch/fighter.gd").new();actor.setup(1,"Mirror test",Color.WHITE);game.add_child(actor);actor.set_process(false)
	game.fighters[1]=actor;game.players[1]=game._new_state("Mirror test",1)
	actor.set_avatar(game.avatars.library.create_avatar(game.avatars.library.selected),game.avatars.library.selected);actor.show_alive(true,true)
	actor.xr_pose=Poses.neutral();actor.xr_pose.body={"hips":Transform3D(Basis.IDENTITY,Vector3(0,.85,0)),"left_foot":Transform3D(Basis.IDENTITY,Vector3(-.15,.3,-.2))}
	var mirror=game.get_node("Map/WaitingRoom/TrackingMirror")
	mirror._process(.04);await process_frame;await process_frame
	check(is_instance_valid(mirror.avatar),"Lobby mirror instantiates the local player's full avatar")
	check(mirror.viewport.own_world_3d and mirror.viewport.find_world_3d()!=game.get_world_3d(),"Mirror camera is isolated from gameplay, avoiding recursive rendering")
	check(mirror.avatar.target_xr_pose==actor.xr_pose,"Mirror receives the same tracking inputs as the player body")
	mirror.avatar._process(.033);mirror.avatar.solver._process_modification_with_delta(.033)
	var sk: Skeleton3D=mirror.avatar.skeleton
	var foot: Vector3=sk.to_global(sk.get_bone_global_pose(sk.find_bone("LeftFoot")).origin)
	check(foot.distance_to(mirror.preview_root.to_global(Vector3(-.15,.3,-.2)))<.08,"Mirror IK reproduces a lifted tracked foot")
	check(not mirror.avatar.first_person and mirror.avatar.visual_meshes.any(func(m):return m.visible and m.get_meta("arena_third_person") and not m.get_meta("arena_first_person")),"Mirror retains full head and body meshes")
	check(not mirror.avatar.gun.visible,"Tracking mirror has no weapon obstructing body reference")
	game.voice.set_mouth_pose(1,PackedFloat32Array([.65,.1,0,0,0]));mirror._process(.04)
	check(mirror.avatar.mouth.target[0]>.6,"Mirror receives the local speech expression independently of hidden first-person meshes")
	game.clock+=.2;mirror._process(.04)
	check(mirror.avatar.mouth.target==PackedFloat32Array([0,0,0,0,0]),"Mirror mouth closes when speech stops")
	actor.xr_pose.face={"look":Vector2.ZERO,"blink":Vector2(.85,.7),"gaze":false,"lids":true}
	mirror._process(.04);mirror.avatar._process(.033);mirror.avatar.eyes._process_modification_with_delta(.1)
	check(mirror.avatar.eyes.blink.x>.8 and mirror.avatar.eyes.blink.y>.65,"Mirror receives measured eyelid closure through the avatar pose")
	actor.xr_pose.erase("face");mirror._process(.04);mirror.avatar._process(.033);mirror.avatar.eyes._process_modification_with_delta(.2)
	check(mirror.avatar.eyes.blink.length()<.001,"Mirror eyelids return to rest after tracking disappears")
	if DisplayServer.get_name()!="headless":
		for i in 20:await process_frame
		await RenderingServer.frame_post_draw
		mirror.viewport.get_texture().get_image().save_png("res://test-results/lobby-mirror-preview.png")
	game.music.set_process(false)
	for player in game.music.players:player.stop();player.stream=null
	await create_timer(.1).timeout
	game.active=false;game.queue_free();await process_frame;await process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	print("LOBBY_MIRROR_RESULT ",failures);quit(0 if failures.is_empty() else 1)
