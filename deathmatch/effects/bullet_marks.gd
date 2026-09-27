extends Node3D
## One fixed mesh batch, populated from authoritative static-world contacts.
## Cosmetic work is bounded independently of weapon/fire rate and player count.
const LIMIT:=128
const QUEUE_LIMIT:=32
const PER_FRAME:=4
const LIFETIME:=30.0
const MAX_DISTANCE:=40.0
var pending: Array=[]
var elapsed:=0.0
var cursor:=0
var positions:=PackedVector3Array()
var normals:=PackedVector3Array()
var born:=PackedFloat64Array()
var batch: MultiMesh
var draw: MultiMeshInstance3D
var material: ShaderMaterial
var processed_last_frame:=0
func _ready():
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	positions.resize(LIMIT);normals.resize(LIMIT);born.resize(LIMIT);born.fill(-LIFETIME)
	material=ShaderMaterial.new();material.shader=preload("res://deathmatch/effects/bullet_marks.gdshader")
	batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.use_custom_data=true
	var quad:=QuadMesh.new();quad.size=Vector2.ONE;batch.mesh=quad;batch.instance_count=LIMIT;batch.visible_instance_count=0
	draw=MultiMeshInstance3D.new();draw.multimesh=batch;draw.material_override=material
	draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;draw.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	add_child(draw)
func enqueue(point: Vector3,normal: Vector3):
	if pending.size()>=QUEUE_LIMIT or not point.is_finite() or not normal.is_finite() or absf(normal.length_squared()-1)>.02:return
	var camera:=get_viewport().get_camera_3d()
	if camera and camera.global_position.distance_squared_to(point)>MAX_DISTANCE*MAX_DISTANCE:return
	pending.append([point,normal.normalized()])
func _process(delta: float):
	elapsed+=delta;material.set_shader_parameter("clock_time",elapsed);processed_last_frame=0
	while not pending.is_empty() and processed_last_frame<PER_FRAME:
		var mark: Array=pending.pop_front();processed_last_frame+=1
		place(mark[0],mark[1])
func place(point: Vector3,normal: Vector3) -> bool:
	# Merge nearly coincident hits instead of stacking coplanar polygons.
	for i in LIMIT:
		if elapsed-born[i]<LIFETIME and positions[i].distance_squared_to(point)<.0004 and normals[i].dot(normal)>.95:return false
	var up:=Vector3.UP if absf(normal.y)<.9 else Vector3.RIGHT
	var tangent:=up.cross(normal).normalized()
	var basis:=Basis(tangent,normal.cross(tangent),normal)*Basis(Vector3.BACK,randf()*TAU)
	var diameter:=randf_range(.055,.075)
	# Four corner probes reject ledges/holes and bends. No floating square past
	# a wall edge, no marks stuck to a moving door. At most 16 short rays/frame.
	var space:=get_world_3d().direct_space_state
	var surface: Object=null
	for corner in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]:
		var at: Vector3=point+(basis.x*corner.x+basis.y*corner.y)*diameter
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+normal*.012,at-normal*.012,1))
		if hit.is_empty() or not hit.collider is StaticBody3D or hit.collider is AnimatableBody3D or hit.normal.dot(normal)<.98 or absf((hit.position-at).dot(normal))>.004:return false
		if surface!=null and surface!=hit.collider:return false
		surface=hit.collider
	positions[cursor]=point;normals[cursor]=normal;born[cursor]=elapsed
	batch.set_instance_transform(cursor,Transform3D(basis.scaled(Vector3.ONE*diameter),point+normal*.0015))
	batch.set_instance_custom_data(cursor,Color(elapsed,randf(),0,0))
	batch.visible_instance_count=maxi(batch.visible_instance_count,cursor+1)
	cursor=(cursor+1)%LIMIT
	return true
