extends Node
## Cosmetic only. Sources expire, follow rendered projectiles, and never own lights.
const TreeData=preload("res://deathmatch/lighting/solid_tree.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const MAX_SOURCES:=64
# Shared desktop/XR budget; keep in sync with the two shader source slots.
const MAX_EFFECTS:=2
var sources: Array=[]
var receivers: Array=[]
var brushes: Array=[]
var world=TreeData.new()
var local_tree=TreeData.new()
var available:=false
var map_origin:=Vector3.ZERO
var selected_count:=0
func configure(level: Node,path: String) -> void:
	clear();brushes.clear();receivers.clear()
	map_origin=level.global_position
	available=world.open(path)
	if not available:return
	var data:=FileAccess.get_file_as_bytes(path);var offset:=data.decode_u32(116);var count:=data.decode_u32(120)/64
	var materials: Dictionary={}
	for node in level.find_children("*","Node3D",true,false):
		if node is MeshInstance3D and node.mesh:
			for i in node.mesh.get_surface_count():
				var mat: Material=node.get_active_material(i)
				if mat is ShaderMaterial and mat.shader in [Filtering.BAKED,Filtering.QUAKE]:materials[mat]=true
		if node is PhysicsBody3D and "attributes" in node:
			var model: String=node.attributes.get("model","")
			if not model.begins_with("*"):continue
			var index:=int(model.substr(1))
			if index<=0 or index>=count:continue
			var head:=data.decode_s32(offset+index*64+36)
			if head<0 or head>=world.planes.size():continue
			# BSP vertices/planes share coordinates; importer applies this same
			# inverse authored rotation to mesh and triangle collision children.
			var bounds:=AABB();var first:=true;var local:=Transform3D.IDENTITY
			for child in node.get_children():
				if child is CollisionShape3D and child.shape is ConcavePolygonShape3D:
					local=child.transform
					for point in child.shape.get_faces():
						bounds=AABB(point,Vector3.ZERO) if first else bounds.expand(point);first=false
			if not first:brushes.append({"node":node,"head":head,"local":local,"bounds":bounds})
	receivers=materials.keys();clear()
func clear() -> void:
	sources.clear();selected_count=0
	for material in receivers:material.set_shader_parameter("weapon_count",0)
func _exit_tree() -> void:clear()
func emit_source(a: Vector3,b: Vector3,recipe: Dictionary,key: int=0) -> void:
	if not available or recipe.is_empty() or not a.is_finite() or not b.is_finite():return
	var radius: float=recipe.get("radius",0);var energy: float=recipe.get("energy",0);var life: float=recipe.get("life",.08)
	if radius<=0 or energy<=0 or life<=0:return
	var item:={"a":a,"b":b,"radius":minf(radius,5),"energy":minf(energy,1.3),"color":recipe.color,"life":minf(life,.5),"total":minf(life,.5),"key":key}
	if key!=0:
		for i in sources.size():
			if sources[i].key==key:sources[i]=item;return
	if sources.size()>=MAX_SOURCES:sources.pop_front()
	sources.append(item)
func remove_source(key: int) -> void:
	sources=sources.filter(func(item):return item.key!=key)
func _process(delta: float) -> void:
	for i in range(sources.size()-1,-1,-1):
		sources[i].life-=delta
		if sources[i].life<=0:sources.remove_at(i)
	update_receivers()
func update_receivers() -> void:
	var camera:=get_viewport().get_camera_3d()
	var eye: Vector3=camera.global_position if camera else Vector3.ZERO
	var candidates:=sources.filter(func(s):return Geometry3D.get_closest_point_to_segment(eye,s.a,s.b).distance_squared_to(eye)<3600)
	candidates.sort_custom(func(a,b):return score(a,eye)>score(b,eye))
	selected_count=mini(MAX_EFFECTS,candidates.size())
	if selected_count==0:
		for material in receivers:material.set_shader_parameter("weapon_count",0)
		return
	var starts:=PackedVector4Array();var ends:=PackedVector4Array();var colors:=PackedVector4Array();var heads:=PackedInt32Array()
	starts.resize(MAX_EFFECTS);ends.resize(MAX_EFFECTS);colors.resize(MAX_EFFECTS);heads.resize(MAX_EFFECTS)
	local_tree.planes.clear();local_tree.children.clear()
	var combined:=AABB()
	for i in selected_count:
		var s: Dictionary=candidates[i];var a: Vector3=s.a;var b: Vector3=s.b;var c: Color=s.color
		starts[i]=Vector4(a.x,a.y,a.z,s.radius);ends[i]=Vector4(b.x,b.y,b.z,s.energy*s.life/s.total);colors[i]=Vector4(c.r,c.g,c.b,1)
		var bounds:=AABB(a,Vector3.ZERO).expand(b).grow(s.radius+.004)
		combined=bounds if i==0 else combined.merge(bounds)
		var first_plane: int=local_tree.planes.size()
		heads[i]=world.prune_into(local_tree,world.head,AABB(bounds.position-map_origin,bounds.size))
		for index in range(first_plane,local_tree.planes.size()):local_tree.planes[index].d+=local_tree.planes[index].normal.dot(map_origin)
	var brush_heads:=PackedInt32Array();var transforms: Array[Transform3D]=[]
	for brush in brushes:
		if not is_instance_valid(brush.node) or brush.node.collision_layer&1==0:continue
		var transform: Transform3D=brush.node.global_transform*brush.local
		if not (transform*brush.bounds).intersects(combined):continue
		if transforms.size()>=4:
			# Busy moving geometry fails dark instead of omitting a blocker.
			selected_count=0;break
		brush_heads.append(world.prune_into(local_tree,brush.head,transform.affine_inverse()*combined));transforms.append(transform)
	local_tree.pack()
	for material in receivers:
		local_tree.apply(material,true,brush_heads,transforms)
		material.set_shader_parameter("weapon_occlusion_local",true);material.set_shader_parameter("weapon_occlusion_local_heads",heads)
		material.set_shader_parameter("weapon_start",starts);material.set_shader_parameter("weapon_end",ends);material.set_shader_parameter("weapon_color",colors)
		material.set_shader_parameter("weapon_count",selected_count)
func score(item: Dictionary,eye: Vector3) -> float:
	var nearest: Vector3=Geometry3D.get_closest_point_to_segment(eye,item.a,item.b)
	return item.energy*item.radius*(item.life/item.total)/(1+eye.distance_squared_to(nearest)*.08)
