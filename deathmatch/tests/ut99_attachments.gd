extends SceneTree
const Library=preload("res://deathmatch/avatars/library.gd")
const Art=preload("res://deathmatch/art.gd")
const Tpose=preload("res://deathmatch/vr/t_pose.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var library:=Library.new();root.add_child(library)
	for model in ["soldier","commando","sgirl","fcommando","boss"]:
		var hash:=library.register_file("res://deathmatch/avatars/models/base/"+model+".utavatar",false)
		var rig=library.create_avatar(hash);root.add_child(rig);rig.set_process(false);rig.distance_ik_enabled=false
		rig.set_weapon(1,"cq_shocktroop");rig.set_equipment("jetpack")
		for stance in ["stand","prone"]:
			rig.stance=stance;rig.target_xr_pose={};rig._process(.2)
			for frame in range(0,rig.arm_profile.sockets.size(),17):
				rig.animation_frames=Vector3(frame,mini(frame+1,rig.arm_profile.sockets.size()-1),.5)
				var hand:Transform3D=rig.hand_pose()
				check(hand.origin.distance_to(rig.visual.transform*rig.sample_attachment("right"))<.00001,model+" native hand follows animation / "+stance)
				var back:Transform3D=rig.back_socket()
				check((back*Vector3(0,0,-.10)).distance_to(rig.visual.transform*rig.sample_attachment("back"))<.00001,model+" backpack front contacts animated back / "+stance)
			rig._process(.02)
			check(rig.gun.position.distance_to(rig.hand_pose().origin)<.00001 and rig.gun.visible,model+" weapon stays attached while prone/incapacitated")
		for handed in [false,true]:
			rig.stance="stand";rig.target_xr_pose={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left":Transform3D(Basis.IDENTITY,Vector3(-1.4,2,-.8)),"right":Transform3D(Basis.IDENTITY,Vector3(1.4,2,-.8)),"weapon":Transform3D(Basis.IDENTITY,Vector3(1.4,2,-.8)),"left_handed":handed}
			rig._process(.2)
			var side:="left" if handed else "right"
			var solved:Dictionary=rig.solved_arms[side]
			var anchor:Dictionary=rig.arm_profile.attachments[side]
			check(rig.gun.position.distance_to(solved.fore*anchor.reference)<.00001,model+" gun follows shader-constrained hand, both handedness")
			check(solved.hand.distance_to(solved.shoulder)<=solved.upper_length+solved.fore_length+.00001,model+" controller cannot change arm length")
			check(rig.equipment_socket(true).origin.x<0 if handed else rig.equipment_socket(true).origin.x>0,model+" radio on mainhand shoulder")
			check(rig.equipment_socket(false).origin.x>0 if handed else rig.equipment_socket(false).origin.x<0,model+" utility on offhand shoulder")
			rig.target_xr_pose={};rig._process(.02)
			check(rig.left_handed==handed and rig.gun.position.distance_to(rig.hand_pose().origin)<.00001,model+" incapacitation preserves weapon handedness when tracking is cleared")
		rig.queue_free()
	var detector:=Tpose.new();var h:=Transform3D(Basis.IDENTITY,Vector3(0,1.65,0));var l:=Vector3(-.7,1.35,0);var r:=Vector3(.7,1.35,0);var count:=0
	for i in 150:
		if detector.sample(h,l,r,.02,true):count+=1
	check(count==1,"Held T-pose calibrates once without repeatedly changing scale")
	for i in 160:detector.sample(h,Vector3(-.2,.8,0),Vector3(.2,.8,0),.02,true)
	for i in 70:
		if detector.sample(h,l,r,.02,true):count+=1
	check(count==2,"Releasing pose and cooldown allows deliberate recenter")
	for i in 70:check(not detector.sample(h,l,r,.02,false),"Blocked calibration cannot recenter")
	print("UT99_ATTACHMENTS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
