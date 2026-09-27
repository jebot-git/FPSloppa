extends Node3D
## A continuous linked belt from the box mouth to the held leader/feed tray.
## Two instanced meshes keep the articulated ammunition inexpensive to draw.
const COUNT:=14
const START:=Vector3(-.130,-.004,-.30)
const SEATED:=Vector3(-.059,.173,-.30)
var rounds: MultiMeshInstance3D
var links: MultiMeshInstance3D
func setup():
	name="ArticulatedFeedBelt"
	# Controller endpoints update on render frames; physics interpolation would
	# add a second smoothing pass and make the belt lag behind the offhand.
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var brass:=StandardMaterial3D.new();brass.albedo_color=Color.WHITE;brass.metallic=.65;brass.roughness=.45
	brass.albedo_texture=load("res://deathmatch/weapons/cs16/finish.res");brass.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Runtime primitive UVs use the PNG's top-left origin (GLTF flips Blender UVs).
	brass.uv1_scale=Vector3(.22,.44,1);brass.uv1_offset=Vector3(.265,.03,0)
	var steel:=brass.duplicate() as StandardMaterial3D;steel.metallic=.8
	steel.uv1_offset=Vector3(.015,.53,0)
	var round_mesh:=CylinderMesh.new();round_mesh.top_radius=.004;round_mesh.bottom_radius=.008;round_mesh.height=.083;round_mesh.radial_segments=10;round_mesh.material=brass
	rounds=instances(round_mesh,COUNT)
	var link_mesh:=BoxMesh.new();link_mesh.size=Vector3(.010,1,.048);link_mesh.material=steel
	links=instances(link_mesh,COUNT-1)
func instances(mesh: Mesh,count: int) -> MultiMeshInstance3D:
	var node:=MultiMeshInstance3D.new();node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=mesh;node.multimesh.instance_count=count;add_child(node);return node
func update_belt(end: Vector3):
	var control:=Vector3(minf(-.21,end.x-.07),minf(.10,end.y-.025),lerpf(START.z,end.z,.5))
	var previous:=START
	for i in COUNT:
		var t:=float(i)/(COUNT-1)
		var point: Vector3=(1-t)*(1-t)*START+2*(1-t)*t*control+t*t*end
		rounds.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.RIGHT,PI/2),point))
		if i>0:
			var delta:=point-previous
			var basis:=Basis(Quaternion(Vector3.UP,delta.normalized())).scaled_local(Vector3(1,maxf(.001,delta.length()),1))
			links.multimesh.set_instance_transform(i-1,Transform3D(basis,(previous+point)*.5))
		previous=point
