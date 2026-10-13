extends Node3D
var library:Node
var avatars:Array=[]
var fixture:=0
var capture_frames:=0
func _ready() -> void:
	get_tree().root.size=Vector2i(1600,1000)
	DisplayServer.window_set_title("UT99 · five base models · constrained head/neck/arms IK")
	library=preload("res://deathmatch/avatars/library.gd").new();add_child(library)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("182522");add_child(env)
	var camera:=Camera3D.new();camera.position=Vector3(0,1.55,-8.3);add_child(camera);camera.look_at(Vector3(0,1.0,0));camera.fov=47;camera.current=true
	var templates:Dictionary=library.base_templates();var i:=0
	for model in ["Soldier","Commando","SGirl","FCommando","Boss"]:
		var avatar=library.create_avatar(templates[model]);add_child(avatar);avatar.position=Vector3((i-2)*1.55,0,0);avatar.unarmed=true;avatar.preview_mode=0;avatars.append(avatar)
		var label:=Label3D.new();label.text=model;label.position=Vector3((i-2)*1.55,2.05,0);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.font_size=36;label.pixel_size=.003;add_child(label);i+=1
	var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(10,4);floor_mesh.mesh=plane;var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("3e5140");floor_mesh.material_override=mat;add_child(floor_mesh)
	var layer:=CanvasLayer.new();add_child(layer);var box:=VBoxContainer.new();box.position=Vector2(20,20);layer.add_child(box)
	var title:=Label.new();title.text="UT99 BASE MODELS · HEAD / NECK / ARMS IK · ORIGINAL BODY ANIMATION";box.add_child(title)
	var pose_select:=OptionButton.new();box.add_child(pose_select)
	for name in ["Forward reach","Overhead reach","Crossed arms","Original animation, IK off"]:pose_select.add_item(name)
	pose_select.item_selected.connect(func(value):fixture=value)
	var anim:=OptionButton.new();box.add_child(anim)
	for name in ["Idle","Walk","Run"]:anim.add_item(name)
	anim.item_selected.connect(func(value):
		for avatar in avatars:avatar.preview_mode=value)
	var args:=OS.get_cmdline_user_args()
	if args.has("--capture"):capture_frames=180
	if args.has("--pose"):fixture=int(args[args.find("--pose")+1]);pose_select.select(fixture)
func _process(_delta:float) -> void:
	for avatar in avatars:
		var pose:=preload("res://deathmatch/vr/poses.gd").neutral()
		pose.head=Transform3D(Basis.from_euler(Vector3(.2,.3,.1)),Vector3(0,1.65,0))
		pose.left.origin=Vector3(-.4,1.2,-.45);pose.right.origin=Vector3(.4,1.3,-.45)
		if fixture==1:pose.left.origin=Vector3(-.3,2.3,-.1);pose.right.origin=Vector3(.3,2.3,-.1)
		elif fixture==2:pose.left.origin=Vector3(.35,1.4,-.3);pose.right.origin=Vector3(-.35,1.4,-.3)
		pose.weapon=pose.right;avatar.target_xr_pose={} if fixture==3 else pose
	if capture_frames>0:
		capture_frames-=1
		if capture_frames==0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://test-results/ut99/base/gallery-"+str(fixture)+".png");get_tree().quit()
