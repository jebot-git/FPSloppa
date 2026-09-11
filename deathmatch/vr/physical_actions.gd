extends RefCounted
var rig_ref: WeakRef
var rig:
	get:return rig_ref.get_ref()
var gesture=preload("res://deathmatch/vr/ability_gesture.gd").new()
var sequence: int=Time.get_ticks_usec()
var grenade: Node3D
var hint: Label3D
var available:=false
func setup(value) -> void:rig_ref=weakref(value)
func reset() -> void:
	gesture.held=false;gesture.latched=true;gesture.busy=true;gesture.samples.clear();available=false
	if is_instance_valid(grenade):grenade.hide()
func busy() -> bool:return available and rig.game.match_mode.kind=="tf" and gesture.busy
func reply(seq: int,kind: String,accepted: bool) -> void:
	if seq!=sequence:return
	if not accepted:gesture.held=false
	if accepted and kind in ["arm","throw","ability"]:rig.feedback(.4,.08,true)
func send(kind: String,pose: Dictionary,velocity:=Vector3.ZERO) -> void:
	sequence+=1;rig.game.match_mode.fortress.physical.submit(kind,pose,velocity,sequence)
func update(delta: float,valid: bool) -> void:
	var game=rig.game
	available=valid and game.active and not game.map_loading and game.bindings.physical_interactions and game.match_mode.kind in ["tf","as"] and not game.lobby.active() and game.intermission<=0 and not game.match_mode.special.blocked(game.multiplayer.get_unique_id()) and not rig.blackout.visible
	var support: XRController3D=rig.right if rig.left_handed else rig.left
	var grip: bool=game.bindings.vr_pressed(rig,"support")
	var trigger: bool=game.bindings.vr_pressed(rig,"offhand_fire")
	var pose: Dictionary=rig.sample_pose() if available else {}
	var result: String=gesture.sample(support.position-rig.head.position,delta,grip,trigger,available and game.match_mode.kind=="tf" and not pose.is_empty())
	if result=="arm":
		var role: String=game.local_state().get("tf_class","")
		var pipe: bool=game.match_mode.fortress.charges.has(game.multiplayer.get_unique_id())
		if not role in ["soldier","demoman","pyro"] or pipe:
			gesture.held=false;send("ability",pose)
		else:send("arm",pose)
	elif result in ["throw","cancel"]:send(result,pose,gesture.velocity)
	if gesture.held:
		if not is_instance_valid(grenade):
			grenade=Node3D.new();rig.add_child(grenade)
			var mesh:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.065;sphere.height=.13;mesh.mesh=sphere
			mesh.material_override=preload("res://deathmatch/art.gd").material(Color("d4aa52"),.25,.4);grenade.add_child(mesh)
			var pin:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.012;ring.outer_radius=.020;pin.mesh=ring;pin.position.y=.09;pin.rotation.x=PI/2;pin.material_override=preload("res://deathmatch/art.gd").material(Color("bbbbbb"));grenade.add_child(pin)
			hint=Label3D.new();hint.text="RELEASE GRIP TO THROW";hint.font_size=24;hint.pixel_size=.0015;hint.position.y=.16;hint.billboard=BaseMaterial3D.BILLBOARD_ENABLED;grenade.add_child(hint)
		grenade.global_transform=support.global_transform;grenade.visible=true
	elif is_instance_valid(grenade):grenade.hide()
