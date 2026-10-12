extends MeshInstance3D
## Collision, when added, must keep LOD0; these levels affect visuals only.
var levels: Array=[]
var lod:=0
var bounds: AABB
var proxy_material: ShaderMaterial
var triangles:=0
func setup() -> void:
	for variant in ["culled","medium","proxy"]:levels.append(load("res://tools/voxelspace/assets/factory_"+variant+".res"))
	bounds=levels[0].get_aabb();mesh=levels[0];cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	proxy_material=ShaderMaterial.new();proxy_material.shader=preload("res://tools/voxelspace/factory_proxy.gdshader")
func update(camera: Camera3D) -> void:
	var p:=camera.global_position;var end:=bounds.end
	var nearest:=Vector3(clampf(p.x,bounds.position.x,end.x),clampf(p.y,bounds.position.y,end.y),clampf(p.z,bounds.position.z,end.z))
	var distance:=p.distance_to(nearest);var target:=lod
	if distance>160:target=2
	elif distance<70:target=0
	elif lod==0 and distance>90:target=1
	elif lod==2 and distance<140:target=1
	if target!=lod:lod=target;mesh=levels[lod];material_override=proxy_material if lod==2 else null
	triangles=mesh.surface_get_array_index_len(0)/3
