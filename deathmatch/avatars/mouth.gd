extends Node
## Resolve VRM expression animations to their declared mesh binds (VRM 0 and 1).
const NAMES=[["aa","a"],["ih","i"],["ou","u"],["ee","e"],["oh","o"]]
var binds: Array=[[],[],[],[],[]]
var weights:=PackedFloat32Array([0,0,0,0,0])
var target:=PackedFloat32Array([0,0,0,0,0])
var remaining:=0.0
var external_mixer:=false
var mixer: Callable
func setup(model: Node) -> void:
	for node in model.find_children("*","AnimationPlayer",true,false):
		var base: Node=node.get_node(node.root_node)
		for anim_name in node.get_animation_list():
			var name_here: String=String(anim_name).get_slice("/",String(anim_name).count("/")).to_lower()
			var index:=-1
			for i in range(5):
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
func speak(value: PackedFloat32Array) -> void:
	if value.size()!=5: return
	target=value.duplicate(); remaining=.12
func _process(delta: float) -> void:
	if remaining<=0 and weights==PackedFloat32Array([0,0,0,0,0]): return
	remaining-=delta
	if remaining<=0: target=PackedFloat32Array([0,0,0,0,0])
	var totals: Dictionary={}
	for i in range(5):
		weights[i]=lerpf(weights[i],target[i],1-exp(-delta*(28 if target[i]>weights[i] else 16)))
		if target[i]==0 and weights[i]<.001: weights[i]=0
		for bind in binds[i]:
			if not is_instance_valid(bind[0]): continue
			var mesh: MeshInstance3D=bind[0]
			if not totals.has(mesh): totals[mesh]={}
			totals[mesh][bind[1]]=float(totals[mesh].get(bind[1],0))+weights[i]*bind[2]
	if external_mixer:
		if mixer.is_valid():mixer.call()
		return
	for mesh in totals:
		for shape in totals[mesh]: mesh.set_blend_shape_value(shape,clampf(totals[mesh][shape],0,.999))
