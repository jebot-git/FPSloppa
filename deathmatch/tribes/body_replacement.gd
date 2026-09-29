extends Node3D
## Bind the replacement VRM armour body to the player's own animated humanoid.
## Original head meshes and morphs remain on the original skeleton.
const Models=preload("res://deathmatch/tribes/models.gd")
const Mask=preload("res://deathmatch/avatars/first_person_mask.gd")
const Original=preload("res://deathmatch/tribes/head_mesh.gd")
var actor
var avatar: Node3D
var body: MeshInstance3D
var source_root: Node3D
var source_sk: Skeleton3D
var fallback:=false
var originals: Array=[]
var key:=""
var team:=-99
var last_first:=false
var hidden_hand:=""
var original_hands: Array=[]
static var mesh_cache: Dictionary={}
func clear():
	if is_instance_valid(avatar) and not fallback:avatar.visual_meshes.erase(body)
	if is_instance_valid(body) and not fallback:body.free()
	if is_instance_valid(source_root):source_root.free()
	for entry in originals:
		if not is_instance_valid(entry.node):continue
		if entry.get("fallback",false):entry.node.visible=entry.visible
		else:
			entry.node.remove_meta("tribes_head_only")
			entry.node.remove_meta("tribes_original_hands")
			entry.node.visible=bool(entry.node.get_meta("arena_first_person" if avatar.first_person else "arena_third_person",true))
			Mask.apply(entry.node,avatar.skeleton,avatar.first_person,avatar.keypad_glove)
	originals.clear();original_hands.clear();body=null;source_root=null;source_sk=null;key=""
func _exit_tree():clear()
func build(value):
	clear();actor=value;avatar=actor.avatar;fallback=actor.avatar_hash.is_empty();key=actor.tribes_state.armour
	source_root=Models.model("body_"+key);add_child(source_root)
	source_sk=source_root.find_children("*","Skeleton3D",true,false)[0]
	body=source_root.find_children("*","MeshInstance3D",true,false)[0]
	if fallback:
		for m in avatar.find_children("*","MeshInstance3D",true,false):
			if m.get_parent().name=="Head" or is_weapon(m):continue
			originals.append({"node":m,"visible":m.visible,"fallback":true});m.hide()
	else:
		for hand in ["LeftHand","RightHand"]:
			for m in avatar.visual_meshes:
				if Original.has_hand(m.get_meta("full_body_mesh",m.mesh),m.skin,avatar.skeleton,hand):original_hands.append(hand);break
		for m in avatar.visual_meshes:
			originals.append({"node":m});m.set_meta("tribes_head_only",true);m.set_meta("tribes_original_hands",original_hands.duplicate());Mask.apply(m,avatar.skeleton,avatar.first_person,avatar.keypad_glove)
		var result:=retarget(body,source_sk,avatar.skeleton,actor.avatar_hash+":"+key+":"+str(original_hands),original_hands)
		var replacement:=MeshInstance3D.new();replacement.name="TribesBody";replacement.mesh=result.mesh;replacement.skin=result.skin
		avatar.skeleton.add_child(replacement);replacement.skeleton=NodePath("..");source_root.free();source_root=null;source_sk=null;body=replacement
	body.set_meta("tribes_body",true);team=-99;last_first=false
	if not fallback:avatar.register_visual_mesh(body,true,true)
func is_weapon(node: Node) -> bool:
	while node!=avatar and node!=null:
		if node.name=="WeaponModel":return true
		node=node.get_parent()
	return false
static func retarget(mesh: MeshInstance3D,src: Skeleton3D,dst: Skeleton3D,cache_key: String,hands: Array=[]) -> Dictionary:
	if mesh_cache.has(cache_key):return mesh_cache[cache_key]
	var source: Mesh=mesh.mesh;var out:=ArrayMesh.new();var skin:=Skin.new();var transforms: Array[Transform3D]=[]
	var src_height:=src.get_bone_global_rest(src.find_bone("Head")).origin.y-src.get_bone_global_rest(src.find_bone("Hips")).origin.y
	var dst_height:=dst.get_bone_global_rest(dst.find_bone("Head")).origin.y-dst.get_bone_global_rest(dst.find_bone("Hips")).origin.y
	var unit: float=dst_height/src_height
	for bind in mesh.skin.get_bind_count():
		var src_index:=src.find_bone(mesh.skin.get_bind_name(bind)) if mesh.skin.get_bind_name(bind)!=&"" else mesh.skin.get_bind_bone(bind)
		var bone_name:=src.get_bone_name(src_index);var target:=dst.find_bone(bone_name)
		if target<0:target=dst.find_bone("Chest") if bone_name in ["UpperChest","Neck"] else dst.find_bone("Hips")
		var target_rest:=dst.get_bone_global_rest(target);var length_scale:=unit
		var src_children:=src.get_bone_children(src_index)
		for child in src_children:
			var dst_child:=dst.find_bone(src.get_bone_name(child))
			if dst_child<0:continue
			var a:=src.get_bone_global_rest(child).origin.distance_to(src.get_bone_global_rest(src_index).origin)
			var b:=dst.get_bone_global_rest(dst_child).origin.distance_to(target_rest.origin)
			if a>.01:length_scale=b/a;break
		var scale:=Vector3(unit,length_scale,unit)
		transforms.append(Transform3D(target_rest.basis.scaled_local(scale),target_rest.origin)*mesh.skin.get_bind_pose(bind))
		skin.add_named_bind(bone_name if dst.find_bone(bone_name)>=0 else dst.get_bone_name(target),target_rest.affine_inverse())
	for surface in source.get_surface_count():
		var arrays: Array=source.surface_get_arrays(surface).duplicate(true);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride: int=bones.size()/vertices.size()
		for v in vertices.size():
			var point:=Vector3.ZERO;var normal:=Vector3.ZERO
			for j in stride:
				var weight:=weights[v*stride+j]
				if weight<=0:continue
				var transform: Transform3D=transforms[bones[v*stride+j]]
				point+=(transform*vertices[v])*weight;normal+=(transform.basis.inverse().transposed()*normals[v])*weight
			vertices[v]=point;normals[v]=normal.normalized()
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TANGENT]=null
		if not hands.is_empty():
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array(range(vertices.size()))
			var kept:=PackedInt32Array()
			for i in range(0,indices.size()-2,3):
				var omit:=false
				for vertex in indices.slice(i,i+3):
					for j in stride:
						if weights[vertex*stride+j]>.15 and skin.get_bind_name(bones[vertex*stride+j]) in hands:omit=true
				if not omit:kept.append_array(indices.slice(i,i+3))
			if kept.is_empty():continue
			arrays[Mesh.ARRAY_INDEX]=kept
		# Generated gloves were removed using their authored weights above.
		# Pin the surviving cuff to the tracked wrist and blend the sleeve into
		# it. A forearm-only cuff cannot follow the IK wrist's reach correction.
		for hand in hands:
			var wrist:=dst.find_bone(hand);var elbow:=dst.find_bone(hand.trim_suffix("Hand")+"LowerArm")
			var hand_bind:=-1;var arm_bind:=-1
			for bind in skin.get_bind_count():
				if skin.get_bind_name(bind)==hand:hand_bind=bind
				if skin.get_bind_name(bind)==hand.trim_suffix("Hand")+"LowerArm":arm_bind=bind
			if wrist<0 or elbow<0 or hand_bind<0 or arm_bind<0:continue
			var start:=dst.get_bone_global_rest(elbow).origin
			var axis:=dst.get_bone_global_rest(wrist).origin-start
			if axis.length_squared()<.0001:continue
			for v in vertices.size():
				var along: float=(vertices[v]-start).dot(axis)/axis.length_squared()
				var follow:=smoothstep(.45,.87,along)
				if follow<=0:continue
				var slot:=-1
				for j in stride:
					if bones[v*stride+j]==hand_bind and weights[v*stride+j]>0:slot=v*stride+j;break
				if slot<0:
					for j in stride:
						if weights[v*stride+j]<=0:slot=v*stride+j;break
				if slot<0:continue
				for j in stride:
					var index:=v*stride+j
					if bones[index]!=arm_bind or weights[index]<=0:continue
					var transferred:=weights[index]*follow
					weights[index]-=transferred;bones[slot]=hand_bind;weights[slot]+=transferred
		arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);out.surface_set_material(out.get_surface_count()-1,source.surface_get_material(surface))
	out.set_meta("transplanted_hands",hands.duplicate())
	var result:={"mesh":out,"skin":skin}
	if mesh_cache.size()>32:mesh_cache.erase(mesh_cache.keys()[0])
	mesh_cache[cache_key]=result;return result
func update(value):
	if not is_instance_valid(value.avatar):return
	if avatar!=value.avatar or key!=value.tribes_state.armour or not is_instance_valid(body):build(value)
	var state: Dictionary=value.get_parent().players.get(value.peer_id,{})
	var next_team: int=state.get("team",-1)
	var first: bool=value.local_player and value.local_body_visible if fallback else avatar.first_person
	var hand: String=avatar.get("keypad_glove") if not fallback else ""
	if next_team!=team:
		team=next_team
		var full: Mesh=body.get_meta("full_body_mesh",body.mesh)
		var overrides: Array=[]
		for i in full.get_surface_count():
			var material=full.surface_get_material(i)
			var copy: Material=null
			if material is StandardMaterial3D and material.resource_name.begins_with("Tribes Team Panels"):
				copy=material.duplicate();copy.albedo_color=Color("ff7764") if team==0 else Color("72acff") if team==1 else Color("c6c4ab")
			overrides.append(copy)
		body.set_meta("full_body_mesh",full);body.set_meta("full_body_overrides",overrides)
		Mask.apply(body,source_sk if fallback else avatar.skeleton,first,hand)
	# VRM meshes are updated immediately by the owning avatar. The procedural
	# fallback has no avatar rig, so retain its local visibility handling here.
	if fallback and (first!=last_first or hand!=hidden_hand):
		Mask.apply(body,source_sk if fallback else avatar.skeleton,first,hand);last_first=first;hidden_hand=hand
	body.visible=(not value.local_player or value.local_body_visible) and not value.spectator and not value.gibbed and (value.alive_state or avatar.death_time<preload("res://deathmatch/avatars/death_pose.gd").VISIBLE_TIME)
	if fallback:update_fallback()
func update_fallback():
	# Reuse the fallback avatar's gait/stance endpoints, retaining its original head.
	source_root.transform=avatar.transform
	var upper: Transform3D=avatar.get_node("Upper").transform
	var facing: Basis=upper.basis*Basis(Vector3.UP,PI)
	for bone in source_sk.get_bone_count():
		var name_here:=source_sk.get_bone_name(bone);var rest:=source_sk.get_bone_global_rest(bone)
		var at: Vector3=upper*Vector3(0,rest.origin.y-.86,0);var basis_here: Basis=facing*rest.basis
		var side: String="Left" if name_here.begins_with("Left") else "Right"
		var part: Node3D=null
		if name_here.ends_with("UpperArm"):part=avatar.get_node("Upper/"+side+"Arm")
		elif name_here.ends_with("LowerArm") or name_here.ends_with("Hand"):part=avatar.get_node("Upper/"+side+"Forearm")
		elif name_here.ends_with("UpperLeg"):part=avatar.get_node(side+"Thigh")
		elif name_here.ends_with("LowerLeg"):part=avatar.get_node(side+"Shin")
		elif name_here.ends_with("Foot"):part=avatar.get_node(side+"Boot")
		if part:
			var pose: Transform3D=avatar.global_transform.affine_inverse()*part.global_transform
			var axis:=pose.basis.y.normalized()
			var length: float=pose.basis.y.length()
			if name_here.ends_with("Foot"):
				at=pose.origin+Vector3(0,.01,.05);basis_here=facing*rest.basis
			else:
				var direction: Vector3=axis if name_here.contains("Leg") or avatar.dead else -axis
				at=pose.origin-direction*length*.5
				basis_here=Basis(Quaternion((facing*rest.basis.y).normalized(),direction))*facing*rest.basis
				if name_here.ends_with("Hand"):at=pose.origin+direction*length*.5
				else:basis_here=basis_here.scaled_local(Vector3(1,length/(.37 if name_here.contains("Leg") else .28 if name_here.ends_with("UpperArm") else .25),1))
		source_sk.set_bone_global_pose_override(bone,Transform3D(basis_here,at),1,true)
