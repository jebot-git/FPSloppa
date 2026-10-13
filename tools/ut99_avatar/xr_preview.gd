extends Node3D
## A separate desktop mirror with real OpenXR head and controller poses only.
const Poses=preload("res://deathmatch/vr/poses.gd")
var library:Node
var preview:Window
var stage:Node3D
var avatar:Node3D
var head:XRCamera3D
var left:XRController3D
var right:XRController3D
var selection:OptionButton
var animation:OptionButton
var status:Label
var calibrated:=false
var correction:=Transform3D.IDENTITY
var timer:=0.0
var samples:=0
var tracked_samples:=0
var previous:Vector3=Vector3.INF
var changed_samples:=0
var capture_timer:=0.0
var captured:=false
var reported_trackers:=false
func _ready() -> void:
	get_tree().root.gui_embed_subwindows=false
	DisplayServer.window_set_title("UT99 · WiVRn-Pro XR mirror")
	var xr:=XRServer.find_interface("OpenXR")
	if xr==null or (not xr.is_initialized() and not xr.initialize()):
		push_error("OpenXR initialization failed; live preview requires the connected WiVRn-Pro runtime")
		get_tree().quit(1);return
	get_viewport().use_xr=true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var origin:=XROrigin3D.new();add_child(origin)
	head=XRCamera3D.new();origin.add_child(head)
	left=XRController3D.new();left.tracker="left_hand";left.pose="grip";origin.add_child(left)
	right=XRController3D.new();right.tracker="right_hand";right.pose="grip";origin.add_child(right)
	library=preload("res://deathmatch/avatars/library.gd").new();add_child(library)
	preview=Window.new();preview.title="UT99 · live tracked head and arms · WiVRn-Pro";preview.size=Vector2i(1000,850);preview.position=Vector2i(120,80);preview.own_world_3d=true;add_child(preview)
	preview.close_requested.connect(func():get_tree().quit());preview.show()
	stage=Node3D.new();preview.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("182522");stage.add_child(env)
	var camera:=Camera3D.new();camera.position=Vector3(0,1.05,-3.7);stage.add_child(camera);camera.look_at(Vector3(0,1.22,0));camera.fov=44;camera.current=true
	var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("3e5140");floor_mesh.material_override=mat;stage.add_child(floor_mesh)
	var layer:=CanvasLayer.new();preview.add_child(layer)
	var bar:=VBoxContainer.new();bar.position=Vector2(16,16);layer.add_child(bar)
	var title:=Label.new();title.text="UT99 MODELS · LIVE HEAD + CONTROLLERS · 170 cm";bar.add_child(title)
	selection=OptionButton.new();bar.add_child(selection)
	for hash in library.entries:
		selection.add_item(library.entries[hash].title);selection.set_item_metadata(selection.item_count-1,hash)
	selection.item_selected.connect(func(_i):rebuild())
	animation=OptionButton.new();bar.add_child(animation);animation.item_selected.connect(func(_i):avatar.selected_sequence=animation.get_item_text(animation.selected))
	var recenter:=Button.new();recenter.text="Recenter headset / standing height";bar.add_child(recenter);recenter.pressed.connect(func():calibrated=false)
	status=Label.new();bar.add_child(status)
	var note:=Label.new();note.text="Headset drives head rotation and position. Controllers drive arms.\nOriginal vertex animation drives the rest of the model.";bar.add_child(note)
	rebuild()
	var panel:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(2.2,1.87);panel.mesh=quad;panel.position=Vector3(0,0,-2.5)
	var panel_mat:=StandardMaterial3D.new();panel_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;panel_mat.albedo_texture=preview.get_texture();panel_mat.cull_mode=BaseMaterial3D.CULL_DISABLED;panel.material_override=panel_mat;head.add_child(panel)
	print("UT99_XR_PREVIEW runtime=",xr.get_system_info())
func rebuild() -> void:
	if is_instance_valid(avatar):avatar.free()
	avatar=library.create_avatar(str(selection.get_item_metadata(selection.selected)));stage.add_child(avatar);avatar.unarmed=true;avatar.preview_mode=0
	animation.clear()
	for clip in avatar.clips:
		if clip.name=="All":continue
		animation.add_item(clip.name)
		if clip.name=="Breath1":animation.select(animation.item_count-1)
	avatar.selected_sequence=animation.get_item_text(animation.selected)
func normalized_pose(raw:Transform3D) -> Transform3D:return correction*raw
func _process(delta:float) -> void:
	if not is_instance_valid(avatar):return
	var tracker=XRServer.get_tracker("head")
	var head_live:bool=tracker!=null and tracker.get_pose("default").has_tracking_data
	var left_live:=left.get_has_tracking_data()
	var right_live:=right.get_has_tracking_data()
	if head_live and not calibrated:
		var raw:=head.transform
		var yaw:=atan2(raw.basis.z.x,raw.basis.z.z)
		var basis:=Basis(Vector3.UP,-yaw)
		correction=Transform3D(basis,-(basis*Vector3(raw.origin.x,0,raw.origin.z))+Vector3(0,1.65-raw.origin.y,0));calibrated=true
	var pose:Dictionary={}
	if head_live and calibrated:
		var h:=normalized_pose(head.transform)
		pose={"head":h}
		if left_live and right_live:
			var validated:=Poses.validate({"head":h,"left":normalized_pose(left.transform),"right":normalized_pose(right.transform),"weapon":normalized_pose(right.transform),"left_handed":false})
			if not validated.is_empty():pose=validated
		if previous!=Vector3.INF and previous.distance_to(h.origin)>.00001:changed_samples+=1
		previous=h.origin
	avatar.target_xr_pose=pose
	samples+=1
	if pose.has("left"):tracked_samples+=1
	status.text="Head: %s   Left: %s   Right: %s\nArms: %s   Samples: %d   Pose changes: %d"%["LIVE" if head_live else "LOST","LIVE" if left_live else "LOST","LIVE" if right_live else "LOST","LIVE" if pose.has("left") else "waiting / recenter",tracked_samples,changed_samples]
	timer+=delta;capture_timer+=delta
	if timer>=1:
		timer=0
		if not reported_trackers:
			reported_trackers=true
			for name in XRServer.get_trackers(XRServer.TRACKER_ANY):
				var t=XRServer.get_tracker(name)
				print("XR_TRACKER ",name," ",t.type)
				if t is XRPositionalTracker:
					for pname in ["default","grip","aim","grip_pose","aim_pose"]:
						if t.has_pose(pname):print("XR_POSE ",pname," ",t.get_pose(pname).has_tracking_data," ",t.get_pose(pname).transform)
		var file:=FileAccess.open("res://test-results/ut99/xr-preview-live.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"source":"OpenXR / active WiVRn-Pro runtime","head_tracked":head_live,"left_tracked":left_live,"right_tracked":right_live,"validated_arms":pose.has("left"),"frames":samples,"tracked_samples":tracked_samples,"head_position_changes":changed_samples,"head_position":str(head.transform.origin),"left_position":str(left.transform.origin),"right_position":str(right.transform.origin),"model":selection.get_item_text(selection.selected),"unix_time":Time.get_unix_time_from_system()},"  "))
	if not captured and capture_timer>8:
		captured=true
		await RenderingServer.frame_post_draw
		preview.get_texture().get_image().save_png("res://test-results/ut99/xr-preview.png")
