extends "res://deathmatch/tests/defusal_vr.gd"
const Cutters=preload("res://deathmatch/pickups/cutter_model.gd")
func events() -> int:return g.demos.events.filter(func(e):return e[0]=="_de_tool_snip").size()
func run():
	var model:=Cutters.new();root.add_child(model)
	check(model.arms.size()==2 and model.arms.all(func(arm):return is_instance_valid(arm)),"Imported cutters have two articulated arms")
	var rest: Array=model.arms.map(func(arm):return arm.transform)
	var hinge: Node3D=model.find_child("DE_CutterHinge",true,false);var fixed:=hinge.transform
	model.snip();model._process(.05)
	var tips: Array=[]
	for i in 2:
		var arm: Node3D=model.arms[i]
		tips.append(arm.transform*Vector3(.002 if i==0 else -.002,0,-.069))
		check(arm.position.is_equal_approx(rest[i].origin) and not arm.transform.is_equal_approx(rest[i]),"Whole handle/jaw arm pivots without detaching: "+str(i))
	check(tips[0].distance_to(tips[1])<.0001 and tips[0].distance_to(Vector3(0,0,-.18))<.001,"Closed jaw tips meet at the authoritative wire contact")
	check(hinge.transform==fixed,"Hinge stays fixed while snipping")
	model._process(.2)
	check(model.arms[0].transform.is_equal_approx(rest[0]) and model.arms[1].transform.is_equal_approx(rest[1]) and not model.is_processing(),"Snip returns open and stops idle animation processing")
	model.snip();model._process(.04);model.snip();model._process(.3)
	check(model.arms[0].transform.is_equal_approx(rest[0]),"Repeated squeeze safely restarts animation")
	var sound: AudioStream=load("res://deathmatch/audio/cs16/snip.res")
	check(sound.get_length()>.15 and sound.get_length()<.3,"Compact native snip sound loads")
	model.free()
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("Snipping",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false);de=g.match_mode.defusal
	await physics_frame;await physics_frame;de.tick(0);de.account(-1).kit=true
	var pose:=pose_at(Transform3D.IDENTITY,true);pose.weapon.origin=Contact.holster(pose);pose.left=pose.weapon
	g.demos.events.clear();g.demos.recording=true
	send(-1,pose,true);send(-1,pose,true,false,true)
	check(de.account(-1).tool and events()==1 and de.cut_mask==0,"Fresh trigger dry-snips equipped cutters during preparation")
	for i in 4:send(-1,pose,true,false,true)
	check(events()==1,"Held trigger cannot repeat sound or animation")
	send(-1,pose,true);send(-1,pose,true,false,true)
	check(events()==2,"Release and squeeze creates a new snip")
	send(-1,pose,false);send(-1,pose,false,false,true)
	check(events()==2,"Stowed cutters cannot snip")
	send(-1,pose);send(-1,pose,true);send(-1,pose,true,false,true,true)
	check(events()==2 and not de.account(-1).tool,"Blocked input stows cutters without snipping")
	send(-1,pose,true,false,true)
	check(events()==2,"Returning focus with held buttons cannot snip")
	send(-1,pose);send(-1,pose,true)
	g.clock+=1;g.players[-1].de_trigger=true;de.sample_player(-1)
	check(events()==2 and not de.account(-1).tool,"Stale pose cannot snip")
	de.phase="live";de.phase_end=g.clock+300;de.planted=true;de.carrier=0
	de.bomb_position=g.fighters[-1].position+Vector3(0,1.2,-.5);de.bomb_basis=Basis.IDENTITY;de.fuse_end=g.clock+45
	send(-1,pose);send(-1,pose,true)
	var tip: Vector3=de.base_pose(-1).affine_inverse()*de.bomb_pose()*Contact.WIRES[0]
	pose.weapon=Transform3D(Basis.IDENTITY,tip+Vector3.BACK*.18);pose.left=pose.weapon
	send(-1,pose,true,false,true)
	check(de.cut_mask==1 and events()==3,"VR wire cut emits exactly one synchronized snip")
	g.players[-1].vr_device=false;g.clock+=.2
	check(de.cut(-1,1) and events()==4,"Accepted desktop wire cut also emits one snip")
	var before:=events()
	g._de_tool_snip(g.map_epoch-1,-1,g.players[-1].serial)
	g._de_tool_snip(g.map_epoch,-1,g.players[-1].serial-1)
	g._de_tool_snip(g.map_epoch,98765,1)
	check(events()==before,"Stale map/life and unknown-player feedback are discarded")
	g.demos.recording=false
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/cs16/snip/snip.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DEFUSAL_SNIP_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
