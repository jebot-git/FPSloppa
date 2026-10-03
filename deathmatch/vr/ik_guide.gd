extends Node3D
## Local calibration overlay, sampled after IK and all skeleton modifiers.
const LAYER:=1<<18
const BONES=["Hips","Spine","Chest","UpperChest","Neck","Head","LeftShoulder","LeftUpperArm","LeftLowerArm","LeftHand","RightShoulder","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","LeftToes","RightUpperLeg","RightLowerLeg","RightFoot","RightToes"]
var skeleton: Skeleton3D
var actor
var preview: Node3D
var preview_anchor: Node3D
var preview_hash:=""
var joints: Dictionary={}
var links: Array=[]
var material: StandardMaterial3D
var sphere: SphereMesh
var cylinder: CylinderMesh
func _ready():
	name="LocalIKGuide";top_level=true;transform=Transform3D.IDENTITY
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color=Color(.3,.9,1,.45)
	material.no_depth_test=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	sphere=SphereMesh.new();sphere.radius=.018;sphere.height=.036;sphere.radial_segments=12;sphere.rings=6
	cylinder=CylinderMesh.new();cylinder.top_radius=.009;cylinder.bottom_radius=.009;cylinder.height=1;cylinder.radial_segments=8
	hide()
func marker(mesh: Mesh) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=material;node.layers=LAYER
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);return node
func bind(value: Skeleton3D):
	if skeleton==value:return
	if is_instance_valid(skeleton) and skeleton.skeleton_updated.is_connected(update_pose):skeleton.skeleton_updated.disconnect(update_pose)
	for node in joints.values():node.free()
	for link in links:link[2].free()
	joints.clear();links.clear();skeleton=value
	if not is_instance_valid(skeleton):return
	for bone in BONES:
		var index:=skeleton.find_bone(bone)
		if index>=0:joints[index]=marker(sphere)
	for index in joints:
		var parent:=skeleton.get_bone_parent(index)
		while parent>=0 and not joints.has(parent):parent=skeleton.get_bone_parent(parent)
		if parent>=0:links.append([parent,index,marker(cylinder)])
	skeleton.skeleton_updated.connect(update_pose)
func clear_preview():
	if is_instance_valid(preview_anchor):preview_anchor.free()
	preview=null;preview_anchor=null;preview_hash=""
func present(rig,value):
	var settings=rig.game.hud.settings_panel if rig.game.hud else null
	var active: bool=rig.enabled and not rig.game.quitting and rig.focused and settings!=null and settings.is_visible_in_tree() and settings.section=="tracking"
	if is_instance_valid(actor) and (actor!=value or not active):actor.set_local_ik_guide(false)
	actor=value
	if not active:
		hide();bind(null);clear_preview();return
	var pose: Dictionary=rig.sample_pose()
	if pose.is_empty():
		if is_instance_valid(actor):actor.set_local_ik_guide(false)
		hide();bind(null);clear_preview();return
	if is_instance_valid(actor) and actor.alive_state and not actor.gibbed and not actor.spectator and not actor.avatar_hash.is_empty():
		clear_preview();actor.set_local_ik_guide(true);bind(actor.avatar.skeleton)
	else:
		if is_instance_valid(actor):actor.set_local_ik_guide(false)
		var library=rig.game.avatars.library
		if not is_instance_valid(preview) or preview_hash!=library.selected:
			bind(null);clear_preview();preview=library.create_avatar(library.selected)
			if not is_instance_valid(preview):hide();return
			preview_hash=library.selected;preview_anchor=Node3D.new();rig.add_child(preview_anchor);preview_anchor.add_child(preview)
			preview.set_first_person(true);preview.unarmed=true;preview.hide()
		preview_anchor.global_transform=rig.global_transform
		preview.target_xr_pose=pose;preview.collider_height=rig.crouch_height;preview.stance="stand" if rig.crouch_height>=1.6 else "crouch"
		bind(preview.skeleton)
	show()
func update_pose():
	if not visible or not is_instance_valid(skeleton):return
	for index in joints:joints[index].position=skeleton.to_global(skeleton.get_bone_global_pose(index).origin)
	for link in links:
		var a: Vector3=joints[link[0]].position;var b: Vector3=joints[link[1]].position
		var delta:=b-a;var length:=delta.length();var node: MeshInstance3D=link[2]
		node.visible=length>.0001
		if node.visible:node.transform=Transform3D(Basis(Quaternion(Vector3.UP,delta/length)).scaled_local(Vector3(1,length,1)),(a+b)*.5)
func _exit_tree():
	if is_instance_valid(actor):actor.set_local_ik_guide(false)
	if is_instance_valid(skeleton) and skeleton.skeleton_updated.is_connected(update_pose):skeleton.skeleton_updated.disconnect(update_pose)
	clear_preview()
