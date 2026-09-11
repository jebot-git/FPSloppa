extends SkeletonModifier3D
## Conservative cosmetic eye rotation; never translates eye bones.
const NAMES=[["lookleft"],["lookright"],["lookup"],["lookdown"],["blinkleft","blink_l"],["blinkright","blink_r"],["blink"],["happy","joy"],["angry"],["sad","sorrow"],["relaxed","fun"],["surprised"]]
var binds: Array=[[],[],[],[],[],[],[],[],[],[],[],[]]
var morph_weights: Array[float]=[0,0,0,0,0,0,0,0,0,0,0,0]
var expression_weights:=PackedFloat32Array([0,0,0,0,0])
var rig
var look:=Vector2.ZERO
var blink:=Vector2.ZERO
var eye_bones: Array[int]=[]
func setup(model: Node) -> void:
	for node in model.find_children("*","AnimationPlayer",true,false):
		var base: Node=node.get_node(node.root_node)
		for anim_name in node.get_animation_list():
			var name_here: String=String(anim_name).get_slice("/",String(anim_name).count("/")).to_lower()
			var index:=-1
			for i in range(NAMES.size()):
				if name_here in NAMES[i]: index=i
			if index<0: continue
			var anim: Animation=node.get_animation(anim_name)
			for track in range(anim.get_track_count()):
				if anim.track_get_type(track)!=Animation.TYPE_BLEND_SHAPE or anim.track_get_key_count(track)==0: continue
				var path: NodePath=anim.track_get_path(track)
				var mesh=base.get_node_or_null(NodePath(path.get_concatenated_names()))
				if not mesh is MeshInstance3D or not mesh.mesh: continue
				var shape: int=mesh.find_blend_shape_by_name(path.get_subname(0))
				if shape<0: continue
				var amount:=0.0
				for key in range(anim.track_get_key_count(track)): amount=maxf(amount,float(anim.track_get_key_value(track,key)))
				binds[index].append([mesh,shape,clampf(amount,0,1)])
	var sk: Skeleton3D=rig.skeleton
	for name_here in ["LeftEye","RightEye"]:
		var bone:=sk.find_bone(name_here)
		if bone>=0: eye_bones.append(bone)
func _process_modification_with_delta(delta: float) -> void:
	if not rig: return
	var data: Dictionary=rig.xr_pose.get("face",{}) if not rig.dead else {}
	var desired: Vector2=data.get("look",Vector2.ZERO) if data.get("gaze",false) else Vector2.ZERO
	var lids: Vector2=data.get("blink",Vector2.ZERO) if data.get("lids",false) else Vector2.ZERO
	look=look.lerp(desired.clamp(Vector2(-.20944,-.139626),Vector2(.20944,.139626)),1-exp(-delta*24))
	blink=blink.lerp(lids.clamp(Vector2.ZERO,Vector2(.9,.9)),1-exp(-delta*40))
	# Eyelid closure reduces eye deflection to avoid clipping at extreme poses.
	var safe_look:=look*(1-.8*maxf(blink.x,blink.y))
	var weights: Array[float]=[0,0,0,0,blink.x,blink.y,0]
	var expressions: PackedFloat32Array=data.get("expression",PackedFloat32Array([0,0,0,0,0]))
	for i in 5:
		var desired_weight: float=clampf(expressions[i],0,1)*.65 if expressions.size()==5 else 0.0
		expression_weights[i]=lerpf(expression_weights[i],desired_weight,1-exp(-delta*10))
		if desired_weight==0 and expression_weights[i]<.001:expression_weights[i]=0
		weights.append(expression_weights[i])
	if eye_bones.size()==2:
		var sk: Skeleton3D=rig.skeleton
		var head:=sk.find_bone("Head")
		var head_rest:=sk.get_bone_global_rest(head).basis.orthonormalized()
		var offset:=head_rest*Basis(Vector3.UP,safe_look.x)*Basis(Vector3.RIGHT,-safe_look.y)*head_rest.inverse()
		for bone in eye_bones:
			var parent:=sk.get_bone_parent(bone)
			var parent_rest:=sk.get_bone_global_rest(parent).basis.orthonormalized() if parent>=0 else Basis.IDENTITY
			sk.set_bone_pose_rotation(bone,(parent_rest.inverse()*offset*parent_rest*sk.get_bone_rest(bone).basis.orthonormalized()).get_rotation_quaternion())
	else:
		weights[0]=maxf(0,safe_look.x/.20944)*.3
		weights[1]=maxf(0,-safe_look.x/.20944)*.3
		weights[2]=maxf(0,safe_look.y/.139626)*.3
		weights[3]=maxf(0,-safe_look.y/.139626)*.3
	if binds[4].is_empty() or binds[5].is_empty():
		weights[4]=0;weights[5]=0;weights[6]=maxf(blink.x,blink.y)
	morph_weights=weights
	apply_morphs()
func apply_morphs() -> void:
	var totals: Dictionary={}
	var eye_limits: Dictionary={}
	for i in range(NAMES.size()):
		for bind in binds[i]:
			if not is_instance_valid(bind[0]): continue
			if not totals.has(bind[0]): totals[bind[0]]={}
			if i<7:
				if not eye_limits.has(bind[0]):eye_limits[bind[0]]={}
				eye_limits[bind[0]][bind[1]]=.9
			totals[bind[0]][bind[1]]=float(totals[bind[0]].get(bind[1],0))+morph_weights[i]*bind[2]
	# One writer composes expressions, measured eyelids/gaze and speech. This avoids
	# an expression track overwriting a shared mouth or blink morph every frame.
	if rig.mouth:
		for i in 5:
			for bind in rig.mouth.binds[i]:
				if not is_instance_valid(bind[0]):continue
				if not totals.has(bind[0]):totals[bind[0]]={}
				totals[bind[0]][bind[1]]=float(totals[bind[0]].get(bind[1],0))+rig.mouth.weights[i]*bind[2]
	for mesh in totals:
		for shape in totals[mesh]: mesh.set_blend_shape_value(shape,clampf(totals[mesh][shape],0,eye_limits.get(mesh,{}).get(shape,.999)))
