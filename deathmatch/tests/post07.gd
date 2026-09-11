extends SceneTree
var failures:Array=[]
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
 var jump=preload("res://deathmatch/vr/physical_jump.gd").new()
 for i in 20:jump.sample(1.65,1.0/90,true,true)
 for i in 6:jump.sample(1.65+(i+1)*.012,1.0/90,true,true)
 check(jump.consume(),"A rising physical jump registers within 67 ms")
 for i in 40:jump.sample(1.8,1.0/90,true,true)
 check(not jump.consume(),"Holding raised height cannot retrigger a physical jump")
 for i in 20:jump.sample(1.65,1.0/90,true,true)
 for i in 6:jump.sample(1.65+(i+1)*.012,1.0/90,true,true)
 check(jump.consume(),"Landing rearms the next physical jump without an 800 ms lockout")
 var tracking_pose=preload("res://deathmatch/vr/poses.gd").neutral()
 tracking_pose.head.origin.y=2.7;tracking_pose.left.origin.y=2.1;tracking_pose.right.origin.y=2.1;tracking_pose.weapon=tracking_pose.right
 check(not preload("res://deathmatch/vr/poses.gd").validate(tracking_pose).is_empty(),"Tall and physically jumping headset poses retain tracked arms")
 tracking_pose.head.origin.y=4
 check(preload("res://deathmatch/vr/poses.gd").validate(tracking_pose).is_empty(),"Headset height remains bounded against invalid input")
 var art=preload("res://deathmatch/art.gd")
 var fist=art.weapon(0);check(fist.get_child_count()==0,"Fist weapon retains logic without a visible mesh");fist.free()
 check(preload("res://deathmatch/weapons.gd").DATA[1].range<=1.46,"Chainsaw reach is less than half the previous range")
 var body={"hips":Transform3D.IDENTITY,"left_foot":Transform3D.IDENTITY}
 var solver=preload("res://deathmatch/avatars/pose.gd")
 for angle in [0.0,PI/2,-PI/2,PI]:
  body.hips.basis=Basis(Vector3.UP,angle);body.left_foot.basis=Basis.from_euler(Vector3(.8,angle+PI/2,.7))
  var pole=solver.leg_pole(body,"left",Vector3(0,1,0),Transform3D.IDENTITY)-Vector3(0,1,0)
  check(pole.normalized().dot(-body.hips.basis.z)>.9,"Untracked knee follows pelvis yaw with bounded foot influence %s"%angle)
 var image=Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
 var mat=StandardMaterial3D.new();mat.albedo_texture=ImageTexture.create_from_image(image)
 preload("res://deathmatch/maps/filtering.gd").new().material(mat)
 check(mat.albedo_texture.get_image().has_mipmaps() and mat.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,"Existing cached textures acquire actual mipmaps and anisotropic sampling")
 var guide=preload("res://deathmatch/vr/aim_guide.gd").new();root.add_child(guide)
 var pose=Transform3D(Basis(Vector3.UP,.4),Vector3(0,20,0));guide.update(pose,2,true)
 check(guide.global_position.distance_to(art.held_transform(pose,2)*art.muzzle(2))<.001 and guide.beam.scale.y<=.24,"Aim guide starts at the real muzzle and stays shorter than 25 cm")
 guide.update(pose,1,true);check(not guide.visible,"Melee weapons do not show an aim guide");guide.free()
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.start_host("Demo test",0,100,30,true,"dm")
 var path="res://test-results/post07.fpsdemo"
 if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 g.demos.start_record(path);g.demos.event("_hurt_fx",[1,Vector3.ZERO,Vector3.UP,10,false,false,123,true]);g._send_snapshot();g.demos.stop_record()
 check(g.demos.open_demo(path),"New damage events round-trip through demo record and playback")
 var file=FileAccess.open(path,FileAccess.READ);file.seek(8);var frame=bytes_to_var(file.get_buffer(file.get_32()));file.close()
 frame.events[0][1].resize(7)
 check(g.demos.valid_frame(frame),"Legacy seven-argument damage events remain compatible")
 frame.events[0][1].append("invalid")
 check(not g.demos.valid_frame(frame),"Malformed extended damage events remain rejected")
 frame.events=[["_movement_sound",[0,1,1,"jump",Vector3.ZERO]]]
 check(g.demos.valid_frame(frame),"Recorded jump sound validates for movie playback")
 frame.events[0][1][4]="invalid position"
 check(not g.demos.valid_frame(frame),"Malformed movement sound event is rejected")
 g.demos.stop_playback();g.disconnect_game("Checks complete");g.free()
 print("POST07_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
