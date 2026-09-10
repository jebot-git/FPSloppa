extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var failures: Array=[]
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(preload("res://deathmatch/avatars/library.gd").MAX_BYTES==25_000_000,"VRM cap exactly 25 MB")
	var neutral:=Poses.neutral()
	check(not Poses.validate(neutral).is_empty(),"Tracked pose accepted")
	var bad:=neutral.duplicate(true)
	bad.weapon.origin.x=50
	check(Poses.validate(bad).is_empty(),"Remote weapon reach rejected")
	bad=neutral.duplicate(true)
	bad.head.basis=Basis.from_scale(Vector3.ONE*2)
	check(Poses.validate(bad).is_empty(),"Pose scaling rejected")
	bad=neutral.duplicate(true)
	bad.right.origin.x=NAN
	check(Poses.validate(bad).is_empty(),"Nonfinite pose rejected")
	var map=load("res://deathmatch/vr/actions.tres")
	check(map.find_interaction_profile("/interaction_profiles/oculus/touch_controller")!=null,"Touch binding profile")
	check(map.find_interaction_profile("/interaction_profiles/valve/index_controller")!=null,"Index binding profile")
	var game=load("res://deathmatch/arena.tscn").instantiate()
	root.add_child(game)
	Fixture.setup(game)
	game.start_host("VR test",0,20,10,true)
	check(game._new_state("test",42).owned==[2],"Normal spawn inventory is pistol only")
	game.bots.free();game.bots=null
	game.set_physics_process(false)
	game.fighters[1].position=Vector3(0,10,0)
	game.players[1].yaw=0
	game.players[1].xr=neutral
	var initial: Vector3=game._shot_origin(1)
	game.players[1].xr.weapon.origin+=Vector3(.1,.1,0)
	check(game._shot_origin(1).distance_to(initial+Vector3(.1,.1,0))<.001,"Muzzle tracks weapon translation")
	game.players[1].xr.weapon.basis=Basis(Vector3.UP,PI/2)
	check((-game._weapon_transform(1).basis.z).distance_to(Vector3.LEFT)<.001,"Hand rotation controls aim independently of body")
	game.fighters[1].position=Fixture.point()
	game.fighters[-1].position=Fixture.point(0,-2.7)
	game.players[-1].invulnerable=0
	game.players[1].yaw=PI/2
	game.players[1].weapon=2
	game.players[1].ammo=[50,0,0,0]
	game.players[1].xr=Poses.neutral()
	game.players[1].xr.right.origin=Vector3(.3,1.45,0)
	game.players[1].xr.weapon=Transform3D(Basis(Vector3.UP,-PI/2),Vector3(.3,1.45,0))
	game.players[1].cooldown=0 # This aim test starts after the spawn weapon delay.
	game._fire(1)
	check(game.players[-1].hp<100 and game.players[1].ammo[0]==49,"Authoritative VR shot uses hand aim, not body facing")
	var wall:=StaticBody3D.new()
	wall.position=game.fighters[1].position+Vector3(0,1.2,-.25)
	var collider:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(2,2,.08)
	collider.shape=box
	wall.add_child(collider)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	check(game._weapon_blocked(1),"Weapon behind wall is blocked")
	game._fire(1)
	check(game.players[1].ammo[0]==49,"Blocked VR shot is rejected")
	wall.queue_free()
	var xr_script=load("res://deathmatch/vr/rig.gd")
	check(xr_script!=null and xr_script.can_instantiate(),"XR rig compiles")
	game.disconnect_game()
	game.queue_free()
	print("VR_TEST_RESULT ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
