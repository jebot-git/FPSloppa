extends SceneTree
const Contact=preload("res://deathmatch/counterstrike/bomb_interaction.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var g
var de
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func armed():
	de.clear_bomb();de.carrier=1;de.held=true;de.armed_until=g.clock+5;de.arm_index=4
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Surfaces",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	await physics_frame;await physics_frame
	de=g.match_mode.defusal;de.tick(0);g.clock=de.phase_end;de.tick(0)
	var s: Dictionary=g.players[1];s.yaw=0.0;s.pitch=0.0
	for site in 2:
		armed();g.fighters[1].position=de.sites[site]+Vector3(0,0,.8)
		var candidate: Dictionary=de.placement(1)
		check(not candidate.is_empty() and candidate.site==site and candidate.pose.basis.z.dot(Vector3.UP)>.99,"Floor surface attaches face-up in site "+str(site))
		check(de.plant(1,site),"Floor placement accepted at "+str(site))
		var center: Vector3=de.bomb_position;var normal: Vector3=de.bomb_basis.z
		check(not de.ray_surface(center,center-normal*.12).is_empty(),"Bomb backing rests on real collision")
	armed();var wall: Dictionary=de.ray_surface(de.sites[0]+Vector3.UP,de.sites[0]+Vector3.UP+Vector3.FORWARD*5)
	g.fighters[1].position=wall.position+Vector3(0,-1,.8)
	var mounting: Dictionary=de.placement(1)
	check(not mounting.is_empty() and mounting.pose.basis.z.dot(wall.normal)>.99,"Desktop aim finds crate wall with outward keypad")
	check(de.use(1) and de.planted and de.bomb_basis.z.dot(Vector3.BACK)>.99,"Use plants on aimed wall instead of a pedestal")
	var wall_snapshot: Dictionary=de.snapshot();de.bomb_basis=Basis.IDENTITY;de.receive(wall_snapshot)
	check(de.bomb_position==wall_snapshot.position and de.bomb_basis==wall_snapshot.basis,"Wall transform survives objective replication")
	# B's recessed doorway has a wall on only one half of its boundary.
	armed();var rim: Dictionary=de.ray_surface(de.sites[1]+Vector3.UP,de.sites[1]+Vector3.UP+Vector3.FORWARD*25)
	g.fighters[1].position=rim.position+Vector3(0,-1,.8)
	check(de.placement(1).is_empty(),"Bomb cannot straddle the edge of a doorway")
	# A thin crate rim is smaller than the four supporting feet.
	armed();var edge: Vector3=wall.position+Vector3(.01,1.7,0)
	g.fighters[1].position=edge+Vector3(0,-1,.8)
	check(de.surface_mount(1,{"position":edge,"normal":wall.normal},Vector3.UP).is_empty(),"Unsupported floating surface cannot hold the bomb")
	g.fighters[1].position=de.starts[0][0];s.xr={}
	check(de.placement(1).is_empty() and not de.plant(1),"Outside-site floor and walls cannot plant")
	# A validated held pose must bring the physical back of the bomb to a wall.
	armed();g.fighters[1].position=wall.position+Vector3(0,-1,.8)
	var target:=Transform3D(Basis.IDENTITY,wall.position+Vector3.BACK*.12)
	var pose: Dictionary=Poses.neutral();pose.weapon=de.base_pose(1).affine_inverse()*target*Contact.HOLD.affine_inverse();pose.right=pose.weapon
	pose.offhand_weapon=pose.left;s.vr_device=true;s.xr=Poses.validate(pose);s.de_grip=true;s.input_blocked=false;s.last_input=g.clock
	check(not s.xr.is_empty(),"Wall-mount pose is inside real tracking bounds")
	de.sample_player(1);check(de.planted and de.bomb_basis.z.dot(wall.normal)>.99,"VR physical wall contact plants with aligned normal")
	armed();pose.weapon.origin+=Vector3.BACK*.5;pose.right=pose.weapon;s.xr=Poses.validate(pose)
	check(not de.plant(1),"Armed VR bomb cannot plant from a distance")
	s.xr={};check(not de.plant(1),"Lost VR tracking cannot fall back to remote desktop planting")
	for left in [false,true]:
		pose=Poses.neutral();pose.left_handed=left
		var carried:=Contact.carried(pose)
		check(carried.origin.z<-.1 and carried.origin.y>1.1 and carried.basis.z.normalized().dot(Vector3.FORWARD)>.99 and is_equal_approx(carried.basis.get_scale().x,Contact.CARRIED_SCALE),"Chest bomb is centered, forward and outward for "+("left" if left else "right")+" handed carrier")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/defusal/surfaces.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DEFUSAL_SURFACE_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
