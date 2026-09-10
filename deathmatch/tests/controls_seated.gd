extends SceneTree
const Rig=preload("res://deathmatch/vr/rig.gd")
const Preferences=preload("res://deathmatch/vr/preferences.gd")
class CommandGame extends Node:
	var menu_open:=false
	var active:=false
	var desired_weapon:=2
	var local_yaw:=0.0
	func local_state() -> Dictionary:return {}
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run() -> void:
	var rig=Rig.new();root.add_child(rig);rig.set_process(false)
	rig.origin=XROrigin3D.new();rig.add_child(rig.origin);rig.head=XRCamera3D.new();rig.origin.add_child(rig.head);rig.setup_controllers()
	rig.tracking=preload("res://deathmatch/vr/tracking.gd").new();rig.add_child(rig.tracking)
	rig.enabled=true;rig.simulated=true;rig.seated=true;rig.head.position=Vector3(0,1.05,0);XRServer.world_scale=1.0;rig.recenter();rig.update_seated({})
	check(is_equal_approx(rig.origin_offset.y,.6),"Seated eye height adds translation to standing height")
	check(XRServer.world_scale==1.0,"Seated mode preserves metric reach")
	rig.update_seated({"hips":Transform3D.IDENTITY});check(not rig.seated_active and rig.origin_offset.y==0.0,"Body pose suspends seated translation")
	rig.update_seated({});check(rig.seated_active and is_equal_approx(rig.origin_offset.y,.6),"Tracking loss restores seated preference")
	rig.left_controls=true;rig.left_handed=false
	check(rig.movement_hand()==rig.right and rig.turning_hand()==rig.left and not rig.left_handed,"Left controls independent from weapon hand")
	rig.left_controls=false;check(rig.movement_hand()==rig.left and rig.turning_hand()==rig.right,"Default controls remain right-handed")
	rig.game=CommandGame.new();rig.add_child(rig.game);rig.tracking=null
	rig.blackout=MeshInstance3D.new();rig.add_child(rig.blackout);rig.blackout.hide()
	rig.left.position=Vector3(-.25,1,-.4);rig.right.position=Vector3(.25,1,-.4);rig.left_aim.transform=rig.left.transform;rig.right_aim.transform=rig.right.transform
	var trackers: Array=[]
	for side in ["left_hand","right_hand"]:
		var tracker:=XRControllerTracker.new();tracker.name=side;XRServer.add_tracker(tracker);trackers.append(tracker)
	trackers[0].set_input("primary",Vector2(.25,0));trackers[1].set_input("primary",Vector2(.8,0))
	trackers[0].set_input("ax_button",true);trackers[1].set_input("primary_click",true)
	await process_frame
	rig.left_controls=true
	var command:=rig.command(1)
	check(command.move.x>.75 and command.jump and command.slow,"Mirrored input uses right movement/click and left jump")
	rig.left_controls=false;command=rig.command(2)
	check(is_equal_approx(command.move.x,.25) and not command.jump and not command.slow,"Switching restores original input mapping")
	for tracker in trackers:XRServer.remove_tracker(tracker)
	var path:="user://test-controls-seated.cfg";var values:=Preferences.DEFAULTS.duplicate();values.left_controls=true;values.seated=true
	check(Preferences.save_settings(values,path)==OK,"Save controls preferences")
	var saved:=Preferences.read_settings(path);check(saved.left_controls and saved.seated and saved.smooth_turn,"Restore handedness, seated and smooth turning")
	DirAccess.remove_absolute(path);rig.free();print("CONTROLS_SEATED_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
