extends Node3D
## Local handheld PDA and wrist-mounted remote camera display.
## Mount +Z faces out; +Y points toward the fingers. Cases are baked Blender assets.
const LOCAL_LAYER:=1<<19 # Same first-person-only layer excluded by scope cameras.
const PDA_SIZE:=Vector2(.26,.18)
const CAMERA_SIZE:=Vector2(.26,.14625)
const SIDE_ANGLE:=PI/3.0
const CASE_LIFT:=.04
const Pose=preload("res://deathmatch/avatars/pose.gd")
const CASE_PATHS={"pda":"res://deathmatch/tribes/wrist/pda.scn","camera":"res://deathmatch/tribes/wrist/camera.scn"}
static var cases: Dictionary={}
var screen: MeshInstance3D
var casing: Node3D
var plate: Node3D
var handheld:=false

func setup(texture: Texture2D,kind: String):
	handheld=kind=="pda"
	var size: Vector2=PDA_SIZE if kind=="pda" else CAMERA_SIZE
	name="WristDisplay";physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not cases.has(kind):cases[kind]=load(CASE_PATHS[kind])
	casing=cases[kind].instantiate();casing.name="CaseAndCuff";add_child(casing)
	plate=Node3D.new();plate.name="Tablet";add_child(plate)
	casing.find_child("Case",true,false).reparent(plate,true)
	if handheld:casing.free();casing=null
	screen=MeshInstance3D.new();screen.name="Screen";var quad:=QuadMesh.new();quad.size=size;screen.mesh=quad
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_texture=texture
	mat.cull_mode=BaseMaterial3D.CULL_BACK;mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	screen.material_override=mat;plate.add_child(screen)
	for part in find_children("*","MeshInstance3D",true,false):
		part.layers=LOCAL_LAYER;part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()

static func grip_pose(left_hand: bool,handheld: bool=false) -> Transform3D:
	# Use the avatar's calibrated OpenXR grip mapping: grip -Z is NOT the
	# finger axis. The anatomical wrist is +6 cm on grip Y.
	var hand:=Pose.controller_hand_basis(left_hand)
	# Keep the complete back of the tablet ahead of the wrist and above the
	# palm. Its screen normal follows the palm, without a sideways tilt.
	if handheld:return Transform3D(hand,Vector3.UP*.06+hand.y*.115+hand.z*.08)
	return Transform3D(Basis(-hand.x,hand.y,-hand.z),Vector3.UP*.06-hand.y*.095-hand.z*.068)

func mount(rig) -> bool:
	var left_hand: bool=not rig.left_handed
	var hand: XRController3D=rig.left if left_hand else rig.right
	if get_parent()!=hand:reparent(hand,false)
	transform=grip_pose(left_hand,handheld)
	# Remote display cuffs stay forearm-aligned; the handheld PDA has no cuff.
	plate.transform=Transform3D.IDENTITY if handheld else Transform3D(Basis(Vector3.BACK,SIDE_ANGLE if left_hand else -SIDE_ANGLE),Vector3(0,0,CASE_LIFT))
	visible=rig.focused and not rig.scores and not rig.blackout.visible and (rig.simulated or rig.head_tracked() and hand.get_has_tracking_data())
	return visible
