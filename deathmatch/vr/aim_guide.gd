extends Node3D
const LENGTH:=.60
const START_OFFSET:=.04
var beam: MeshInstance3D
func _ready() -> void:
	top_level=true
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var mesh:=CylinderMesh.new();mesh.top_radius=.0012;mesh.bottom_radius=.0012;mesh.height=1;mesh.radial_segments=6
	beam=MeshInstance3D.new();beam.mesh=mesh;beam.rotation.x=PI/2
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(.45,.85,1)
	beam.material_override=material;beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(beam);hide()
func update(pose: Transform3D,weapon: int,enabled: bool) -> void:
	visible=enabled and weapon>=2
	if not visible:return
	var art=preload("res://deathmatch/art.gd")
	var start:Vector3=art.held_transform(pose,weapon)*art.muzzle(weapon)
	var direction:Vector3=-pose.basis.z.normalized()
	var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,start+direction*(LENGTH+START_OFFSET),1))
	var length:float=start.distance_to(hit.position) if not hit.is_empty() else LENGTH+START_OFFSET
	if length<=START_OFFSET:hide();return
	start+=direction*START_OFFSET;length-=START_OFFSET
	global_transform=Transform3D(pose.basis.orthonormalized(),start)
	beam.scale.y=maxf(.001,length);beam.position.z=-length*.5
