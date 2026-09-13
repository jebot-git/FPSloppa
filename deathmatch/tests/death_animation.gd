extends SceneTree
const Death=preload("res://deathmatch/avatars/death_pose.gd")
var failures:Array=[]
var reports:Array=[]
var world:Node3D
var library
class LobbyStub:
	extends RefCounted
	func active()->bool:return false
class GameFixture:
	extends Node3D
	var lobby=LobbyStub.new()
	func is_vr()->bool:return false
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	if not ok:failures.append(label);print("FAIL ",label)
func point(avatar,bone:String)->Vector3:
	return avatar.to_local(avatar.skeleton.to_global(avatar.skeleton.get_bone_global_pose(avatar.skeleton.find_bone(bone)).origin))
func tick(avatar,delta:float):
	avatar._process(delta);avatar.solver._process_modification_with_delta(delta)
func tracked_pose()->Dictionary:
	return {"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left":Transform3D(Basis.IDENTITY,Vector3(-.4,1.2,-.3)),"right":Transform3D(Basis.IDENTITY,Vector3(.4,1.2,-.3)),"weapon":Transform3D.IDENTITY,"left_handed":false,"body":{"hips":Transform3D(Basis.IDENTITY,Vector3(0,.92,0)),"chest":Transform3D.IDENTITY,"left_foot":Transform3D(Basis.IDENTITY,Vector3(-.13,.08,0)),"right_foot":Transform3D(Basis.IDENTITY,Vector3(.13,.08,0))}}
func fixture(hash:String):
	var actor:=Node3D.new();world.add_child(actor)
	var avatar=library.create_avatar(hash);actor.add_child(avatar);avatar.process_mode=Node.PROCESS_MODE_DISABLED
	return avatar
func run():
	world=Node3D.new();root.add_child(world)
	library=preload("res://deathmatch/avatars/library.gd").new();world.add_child(library)
	var models:Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/avatars/models/manifest.json"))
	for entry in models:
		for stance in ["stand","prone","tracked"]:
			var avatar=fixture(entry.hash)
			avatar.stance="prone" if stance=="prone" else "stand";avatar.collider_height=.65 if stance=="prone" else 1.65
			if stance=="tracked":avatar.target_xr_pose=tracked_pose()
			for i in 60:tick(avatar,1.0/60)
			var live_head:=point(avatar,"Head")
			avatar.dead=true
			for i in 60:
				tick(avatar,1.0/60)
				for bone in ["Hips","Head","LeftHand","RightHand","LeftFoot","RightFoot"]:
					check(point(avatar,bone).is_finite(),entry.title+" finite death "+bone)
			var head:=point(avatar,"Head");var hip:=point(avatar,"Hips")
			check(head.y<.65 and head.z>hip.z+.30,entry.title+" "+stance+" falls backward, head low")
			check(not avatar.gun.visible and (not avatar.offhand_gun or not avatar.offhand_gun.visible),"Dead weapons hidden")
			check(not avatar.motion.is_playing() and avatar.xr_pose.is_empty(),"Live animation/tracking suspended")
			check(not avatar.solver.death_cache.is_empty(),"Settled pose cached")
			var hand:=point(avatar,"RightHand")
			var world_hand:Vector3=avatar.to_global(hand)
			avatar.get_parent().rotation.y+=.8
			avatar.target_xr_pose=tracked_pose();avatar.target_xr_pose.head.origin=Vector3(3,4,5);avatar.target_xr_pose.right.origin=Vector3(-3,5,-4)
			var start:=Time.get_ticks_usec()
			for i in 120:tick(avatar,1.0/60)
			var cost:=float(Time.get_ticks_usec()-start)/120.0
			check(hand.distance_to(point(avatar,"RightHand"))<.0001 and head.distance_to(point(avatar,"Head"))<.0001,"Tracking cannot move corpse")
			check(world_hand.distance_to(avatar.to_global(point(avatar,"RightHand")))<.0001,"Dead look/yaw cannot spin corpse")
			check(is_equal_approx(avatar.death_time,Death.VISIBLE_TIME),"Bounded death lifetime")
			check(avatar.find_children("*","PhysicsBody3D",true,false).is_empty(),"No ragdoll physics bodies")
			reports.append({"model":entry.title,"entry":stance,"head":str(head),"live_head":str(live_head),"settled_update_us":cost})
			avatar.dead=false;avatar.target_xr_pose={};avatar.stance="stand";avatar.collider_height=1.65
			for i in 60:tick(avatar,1.0/60)
			check(point(avatar,"Head").y>1.2 and avatar.death_time==0 and avatar.motion.is_playing(),"Respawn restores live pose")
			check(avatar.solver.death_cache.is_empty(),"Respawn clears corpse cache")
			avatar.get_parent().free()
	var fallback=preload("res://deathmatch/art.gd").marine(Color("6485a3"));world.add_child(fallback)
	for stance in ["stand","prone"]:
		for i in 60:fallback.animate(1.0/60,Vector3.ZERO,stance,.65 if stance=="prone" else 1.65,true,{},false)
		fallback.dead=true
		for i in 65:fallback.animate(1.0/60,Vector3(8,0,0),"prone",.45,true,tracked_pose().body,true)
		var head:Vector3=fallback.to_local(fallback.get_node("Upper/Head").global_position)
		check(head.y<.65 and head.z>.4,"Fallback backward collapse from "+stance)
		check(not fallback.get_node("Upper/WeaponModel").visible,"Fallback weapon hidden")
		fallback.dead=false;fallback.animate(.016,Vector3.ZERO,"stand",1.65,true,{},false)
		check(fallback.get_node("Upper").rotation.is_zero_approx() and fallback.death_time==0,"Fallback respawn resets")
	fallback.free()
	# Exercise the production fighter visibility/lifetime and special-state gates.
	for use_fallback in [false,true]:
		var game:=GameFixture.new();world.add_child(game)
		var fighter=preload("res://deathmatch/fighter.gd").new();game.add_child(fighter);fighter.setup(99,"Death fixture",Color.WHITE);fighter.set_process(false)
		fighter.set_avatar(preload("res://deathmatch/art.gd").marine(Color.WHITE) if use_fallback else library.create_avatar(models[0].hash),"" if use_fallback else models[0].hash)
		fighter.avatar.process_mode=Node.PROCESS_MODE_DISABLED
		fighter.show_alive(false,false);fighter._process(.1)
		check(fighter.avatar.visible and fighter.avatar.dead,"Remote corpse visible, including fallback")
		fighter.avatar.death_time=1.2;fighter.show_alive(false,false)
		check(is_equal_approx(fighter.avatar.death_time,1.2),"Repeated dead snapshots do not restart animation")
		fighter.avatar.death_time=Death.VISIBLE_TIME;fighter._process(.01)
		check(not fighter.avatar.visible,"Corpse disappears at lifetime")
		fighter.show_alive(true,false);fighter._process(.01)
		check(fighter.avatar.visible and not fighter.avatar.dead,"Fighter respawn visibility")
		fighter.set_frozen(true);var time:float=fighter.avatar.death_time;fighter._process(.1)
		check(not fighter.avatar.dead and fighter.avatar.death_time==time,"Freeze Tag does not start collapse")
		fighter.set_frozen(false);fighter.gibbed=true;fighter._process(.01)
		check(not fighter.avatar.visible,"Gibs suppress corpse")
		fighter.gibbed=false;fighter.show_alive(false,true);fighter._process(.01)
		check(not fighter.avatar.visible,"Local death body stays hidden")
		fighter.spectator=true;fighter.show_alive(false,false);fighter._process(.01)
		check(not fighter.avatar.visible,"Spectator body stays hidden")
		game.free()
	FileAccess.open("res://test-results/death-animation/results.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"models":reports},"  "))
	if OS.get_cmdline_user_args().has("--preview") or OS.get_cmdline_user_args().has("--clip"):await preview(models[0].hash)
	print("DEATH_ANIMATION_RESULT ",JSON.stringify({"failures":failures,"models":reports}))
	world.free();quit(0 if failures.is_empty() else 1)

func preview(hash:String):
	var clip:=OS.get_cmdline_user_args().has("--clip")
	var moving:Array=[]
	root.size=Vector2i(1600,850);root.content_scale_size=root.size
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("202832");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;world.add_child(env)
	var light:=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-50,-25,0)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,6,8);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=11;camera.look_at(Vector3(0,.2,0))
	var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();floor_mesh.mesh.size=Vector2(14,10);world.add_child(floor_mesh)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("455260");floor_mesh.material_override=mat
	var phases:Array=[["LIVE PRONE",-1.0],["BUCKLE 0.18s",.18],["COLLAPSE 0.45s",.45],["DEAD 0.90s",.90]]
	if clip:phases=[["LIVE PRONE",-1.0],["DEATH → RESPAWN",0.0]];camera.size=7
	for row in 2:
		for i in phases.size():
			var phase:Array=phases[i]
			var avatar=fixture(hash) if row==0 else preload("res://deathmatch/art.gd").marine(Color("6485a3"))
			if row==1:
				var actor:=Node3D.new();world.add_child(actor);actor.add_child(avatar)
			avatar.get_parent().position=Vector3((i-(phases.size()-1)*.5)*2.6,0,(row-.5)*3.3)
			if row==0:
				avatar.stance="prone" if phase[1]<0 else "stand";avatar.collider_height=.65 if phase[1]<0 else 1.65
				for j in 60:tick(avatar,1.0/60)
				if phase[1]>=0:
					avatar.dead=true
					for j in int(phase[1]*100):tick(avatar,.01)
				avatar.gun.hide();avatar.offhand_gun.hide()
			else:
				for j in 60:avatar.animate(1.0/60,Vector3.ZERO,"prone" if phase[1]<0 else "stand",.65 if phase[1]<0 else 1.65,true,{},false)
				if phase[1]>=0:
					avatar.dead=true
					for j in int(phase[1]*100):avatar.animate(.01,Vector3.ZERO,"stand",1.65,true,{},false)
			var label:=Label3D.new();world.add_child(label);label.text=phase[0];label.font_size=30;label.pixel_size=.006;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=avatar.get_parent().position+Vector3(0,1.9,0)
			if clip and phase[1]>=0:moving.append([avatar,row])
	for i in 5:await process_frame
	if clip:
		DirAccess.make_dir_recursive_absolute("res://test-results/death-animation/frames")
		for frame in 120:
			for entry in moving:
				var avatar=entry[0]
				avatar.dead=frame>=15 and frame<99
				if entry[1]==0:tick(avatar,1.0/30)
				else:avatar.animate(1.0/30,Vector3.ZERO,"stand",1.65,true,{},false)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/death-animation/frames/%04d.png"%frame)
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/death-animation/comparison.png")
