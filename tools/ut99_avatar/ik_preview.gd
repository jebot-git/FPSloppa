extends "res://tools/ut99_avatar/preview.gd"
## Deterministic diagnostic poses only. The WiVRn live preview never uses these.
var fixture:="forward"
func _ready() -> void:
	super._ready()
	var args:=OS.get_cmdline_user_args()
	if args.has("--pose"):fixture=args[args.find("--pose")+1]
	DisplayServer.window_set_title("UT99 · constrained IK diagnostic · "+fixture)
func _process(delta:float) -> void:
	for avatar in avatars:
		var pose:=preload("res://deathmatch/vr/poses.gd").neutral()
		pose.head=Transform3D(Basis.from_euler(Vector3(.20,.30,.10)),Vector3(0,1.65,0))
		pose.left.origin=Vector3(-.4,1.2,-.45);pose.right.origin=Vector3(.4,1.3,-.45)
		if fixture=="overhead":pose.left.origin=Vector3(-.3,2.3,-.1);pose.right.origin=Vector3(.3,2.3,-.1)
		if fixture=="cross":pose.left.origin=Vector3(.35,1.4,-.3);pose.right.origin=Vector3(-.35,1.4,-.3)
		pose.weapon=pose.right;avatar.target_xr_pose=pose
	super._process(delta)
