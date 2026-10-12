extends Node
## One bounded background simplification job. Source ArrayMeshes stay shared by
## the decoded-scene cache and every instance; all rendering mutations stay here.
const MAX_VERTICES:=100000
const MAX_TRIANGLES:=100000
const MAX_SURFACES:=128
const MAX_PENDING:=16
const MAX_MORPH_VERTICES:=1000000
var pending: Array[ArrayMesh]=[]
var job: Dictionary={}
var task: int=-1
var completed:=0
static func request(rig: Node) -> void:
	var tree:=rig.get_tree()
	var service:=tree.root.get_node_or_null("AvatarMeshLOD")
	if service==null:
		service=load("res://deathmatch/avatars/mesh_lod.gd").new()
		service.name="AvatarMeshLOD";tree.root.add_child(service)
	for instance in rig.visual_meshes:
		if instance.mesh is ArrayMesh:service.enqueue(instance.mesh)
func enqueue(mesh: ArrayMesh) -> void:
	if mesh.has_meta("cq_mesh_lod") or pending.size()>=MAX_PENDING:return
	if mesh.get_surface_count()>MAX_SURFACES or mesh.get_blend_shape_count()>64:
		mesh.set_meta("cq_mesh_lod","budget_exceeded");return
	mesh.set_meta("cq_mesh_lod","queued");pending.append(mesh)
func _process(_delta: float) -> void:
	if task>=0:
		if not WorkerThreadPool.is_task_completed(task):return
		WorkerThreadPool.wait_for_task_completion(task);task=-1
		install(job.source,job.copy);completed+=1;job={}
		return # Never finish one and prepare another on the same frame.
	if pending.is_empty():return
	var mesh: ArrayMesh=pending.pop_front()
	var vertices:=0;var triangles:=0
	for index in mesh.get_surface_count():
		vertices+=mesh.surface_get_array_len(index);triangles+=mesh.surface_get_array_index_len(index)/3
	if vertices>MAX_VERTICES or triangles>MAX_TRIANGLES or vertices*(1+mesh.get_blend_shape_count())>MAX_MORPH_VERTICES:
		mesh.set_meta("cq_mesh_lod","budget_exceeded");return
	var copy:=ImporterMesh.new();copy.set_blend_shape_mode(mesh.blend_shape_mode)
	for index in mesh.get_blend_shape_count():copy.add_blend_shape(mesh.get_blend_shape_name(index))
	for index in mesh.get_surface_count():
		copy.add_surface(mesh.surface_get_primitive_type(index),mesh.surface_get_arrays(index),mesh.surface_get_blend_shape_arrays(index),{},mesh.surface_get_material(index),mesh.surface_get_name(index),mesh.surface_get_format(index)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	job={"source":mesh,"copy":copy}
	task=WorkerThreadPool.add_task(func():copy.generate_lods(60,25,[]),false,"Avatar mesh LOD")
func install(mesh: ArrayMesh,copy: ImporterMesh) -> void:
	# Preserve the original packed normals/tangents, skin and morph data exactly.
	# Re-encoding decoded surfaces adds another quantization pass. The serialized
	# _surfaces property is pinned to Godot 4.7 and covered by byte-equality tests.
	var original: Array=mesh.get("_surfaces")
	var generated:=copy.get_mesh()
	var packed: Array=generated.get("_surfaces")
	var count:=0
	for index in original.size():
		var row: Dictionary=original[index]
		var index_count: int=row.get("index_count",0)
		if index_count==0:continue
		var stride: int=row.index_data.size()/index_count
		var minimum:=maxi(48,ceili(index_count*.15))*stride
		var levels: Array=packed[index].get("lods",[])
		var retained: Array=[]
		for lod in range(0,levels.size(),2):
			# Avoid collapsing hair strips/facial details to the generator's minimum.
			if levels[lod+1].size()>=minimum:
				retained.append(levels[lod]);retained.append(levels[lod+1]);count+=1
		if not retained.is_empty():row.lods=retained
	if count>0:mesh.set("_surfaces",original)
	mesh.set_meta("cq_mesh_lod","ready");mesh.set_meta("cq_mesh_lod_levels",count)
func _exit_tree() -> void:
	if task>=0:WorkerThreadPool.wait_for_task_completion(task)
