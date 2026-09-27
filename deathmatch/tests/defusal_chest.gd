extends "res://deathmatch/tests/defusal_vr.gd"
const Hip=preload("res://deathmatch/vr/hip_mount.gd")
const Codec=preload("res://deathmatch/network/codec.gd")
func run():
	for left in [false,true]:
		var pose:=Poses.neutral();pose.left_handed=left
		pose.body={"hips":Transform3D(Basis(Vector3.UP,.6),Vector3(.08,.98,.04))}
		var bomb:=Contact.carried(pose);var tool:=Contact.tool_carried(pose);var bag:=Hip.pouch(pose)
		check(is_equal_approx((Hip.chest(pose).affine_inverse()*bomb.origin).y,-.115) and is_equal_approx((Hip.chest(pose).affine_inverse()*tool.origin).y,-.01),"Both chest mounts sit eight centimetres lower in the tracked torso frame")
		pose.head.basis=Basis(Vector3.UP,-1.1)
		check(Contact.carried(pose).is_equal_approx(bomb) and Contact.tool_carried(pose).is_equal_approx(tool),"Tracked hip heading isolates chest gear from head turning, left="+str(left))
		pose.head.origin.z-=.2
		check(Contact.carried(pose).origin.z<bomb.origin.z-.05 and Hip.pouch(pose).is_equal_approx(bag),"Chest gear follows torso lean while belt remains at measured hips")
		check(is_equal_approx(bomb.basis.get_scale().x,.4),"Chest bomb uses forty-percent linear scale")
		check((Hip.chest(pose).affine_inverse()*Contact.holster(pose)).x<0 if left else (Hip.chest(pose).affine_inverse()*Contact.holster(pose)).x>0,"Tweezers mount on the gun-hand chest side")
		for digit in 10:
			var at: Vector3=Contact.held(pose)*Contact.key_point(digit)
			check(at.distance_to(Contact.primary(pose).origin)>.10,"Held keypad clears gripping controller: %s/%d"%[left,digit])
	for digit in 10:
		var at:=Contact.key_point(digit)
		check(Contact.press(at+Vector3.BACK*.05,at)==digit,"Front fingertip contact identifies exact key "+str(digit))
		check(Contact.press(at-Vector3.BACK*.04,at)==-1,"Back contact cannot type "+str(digit))
	check(Contact.press(Vector3(-.2,0,.084),Vector3(.2,0,.084))==-1,"Lateral brushing cannot type")
	check(Contact.press(Vector3(0,0,.6),Contact.key_point(5))==-1,"Tracking jump cannot type")
	var pose:=Poses.neutral();pose.offhand_weapon=pose.left;pose.index_tip=pose.left*Vector3(0,0,-.10)
	check(not Poses.validate(pose).is_empty(),"Visible fingertip fits validated controller reach")
	check(Codec.unpack(Codec.pack(pose)).index_tip.is_equal_approx(pose.index_tip),"Fingertip survives production input codec")
	pose.index_tip+=Vector3.LEFT
	check(Poses.validate(pose).is_empty(),"Forged distant fingertip is rejected")
	pose.index_tip=Vector3(NAN,0,0)
	check(Poses.validate(pose).is_empty(),"Nonfinite fingertip is rejected")
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Chest equipment",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false);de=g.match_mode.defusal
	await physics_frame;await physics_frame
	de.tick(0)
	check(de.buy(-1,102) and de.account(-1).kit,"Purchased tweezers occupy chest equipment slot")
	var ct:=pose_at(Transform3D.IDENTITY,true);ct.weapon.origin=Contact.holster(ct);ct.left=ct.weapon
	send(-1,ct,true)
	check(de.account(-1).tool,"Gun-hand grip draws tweezers during preparation")
	send(-1,ct,false)
	check(not de.account(-1).tool and de.account(-1).kit,"Grip release reattaches tweezers to chest")
	de.phase="live";de.phase_end=g.clock+300;de.carrier=1
	pose=pose_at(Transform3D.IDENTITY);pose.weapon.origin=Contact.carried(pose).origin;pose.right=pose.weapon
	var gun: int=g.players[1].weapon
	send(1,pose,true)
	check(de.held and de.gun_holstered(1) and g.players[1].weapon==gun,"Gun-hand grip stashes equipped gun without changing its slot")
	send(1,pose,false)
	check(de.carrier==1 and not de.held and not de.gun_holstered(1),"Releasing bomb returns it to chest and restores gun")
	send(1,pose,true)
	check(de.use(1) and de.carrier==0 and not de.held,"Explicit Use drops the held VR bomb")
	send(1,pose,true)
	check(de.carrier==0,"Still-held grip cannot immediately recover dropped bomb")
	check(de.use(1) and de.carrier==1 and not de.held,"Explicit recovery attaches bomb to chest without hiding gun")
	send(1,pose,false);send(1,pose,true)
	var digit: int=de.arm_code[0];touch(1,pose,digit,true);send(1,pose,true)
	check(de.arm_index==1,"First deliberate fingertip press enters one digit")
	for i in 3:send(1,pose,true,true)
	check(de.arm_index==1,"Holding contact and squeezing trigger cannot repeat a key")
	var other: int=de.arm_code[1];var mount: Transform3D=de.base_pose(1).affine_inverse()*de.bomb_pose()
	pose.index_tip=mount*Contact.key_point(other);pose.offhand_weapon.origin=pose.index_tip+Vector3.BACK*.08;pose.left=pose.offhand_weapon
	send(1,pose,true)
	check(de.arm_index==1,"Sliding to another key while depressed cannot type")
	touch(1,pose,other,true);send(1,pose,true)
	check(de.arm_index==2,"Retracting and pressing enters the next key")
	send(1,pose,false)
	check(de.arm_index==0 and de.armed_until==0,"Stowing bomb clears incomplete arming")
	de.planted=true;de.carrier=0;de.bomb_position=g.fighters[-1].position+Vector3(0,1.2,-.5);de.bomb_basis=Basis.IDENTITY;de.fuse_end=g.clock+45
	send(-1,ct,true,false,true)
	check(de.account(-1).tool and de.gun_holstered(-1),"Drawn chest tweezers stash CT gun")
	var tip: Vector3=de.base_pose(-1).affine_inverse()*de.bomb_pose()*Contact.WIRES[0]
	ct.weapon=Transform3D(Basis.IDENTITY,tip+Vector3.BACK*.18);ct.left=ct.weapon
	send(-1,ct,true,false,true)
	check(de.cut_mask==0,"Trigger held before wire contact cannot cut")
	send(-1,ct,true,false,false)
	check(de.cut_mask==0,"Touching wire without trigger cannot cut")
	send(-1,ct,true,false,true)
	check(de.cut_mask==1,"Fresh trigger press at tweezer-tip contact cuts one wire")
	send(-1,ct,false)
	check(not de.account(-1).tool and de.account(-1).kit and not de.gun_holstered(-1),"Release stows tweezers, ends defusal and restores CT gun")
	print("DE_CHEST_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
