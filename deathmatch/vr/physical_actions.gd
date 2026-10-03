extends RefCounted
var rig_ref: WeakRef
var rig:
	get:return rig_ref.get_ref()
var gesture=preload("res://deathmatch/vr/ability_gesture.gd").new()
var equipment=preload("res://deathmatch/vr/tribes_equipment.gd").new()
var sequence: int=Time.get_ticks_usec()
var grenade: Node3D
var hint: Label3D
var available:=false
var guide: MeshInstance3D
var guide_elapsed:=0.0
func setup(value) -> void:rig_ref=weakref(value);equipment.setup(self)
func reset() -> void:
	equipment.reset()
	gesture.held=false;gesture.latched=true;gesture.busy=true;gesture.samples.clear();available=false
	if is_instance_valid(grenade):grenade.hide()
	if is_instance_valid(guide):guide.hide()
func busy() -> bool:return available and (rig.game.match_mode.fortress.enabled() or rig.game.match_mode.defusal.enabled() or rig.game.match_mode.tribes.enabled()) and (gesture.busy or not equipment.item.is_empty())
func reply(seq: int,kind: String,accepted: bool) -> void:
	if seq!=sequence:return
	if not accepted:
		# A rejected placement keeps the pack in the same hand. Releasing and
		# pressing trigger retries after moving to a legal surface.
		if kind=="activate" and equipment.item=="pack":equipment.used=false
		else:gesture.held=false;equipment.item=""
	if accepted and kind!="cancel":rig.feedback(.4,.08,true)
func send(kind: String,pose: Dictionary,velocity:=Vector3.ZERO) -> void:
	sequence+=1;rig.game.match_mode.fortress.physical.submit(kind,pose,velocity,sequence)
func update(delta: float,valid: bool) -> void:
	var game=rig.game
	available=valid and game.active and not game.map_loading and game.bindings.physical_interactions and (game.match_mode.kind in ["tf","tb","as","de"] or game.match_mode.tribes.enabled()) and not game.lobby.active() and game.intermission<=0 and not game.match_mode.special.blocked(game.multiplayer.get_unique_id()) and not rig.blackout.visible
	var de: bool=game.match_mode.defusal.enabled()
	var tribes: bool=game.match_mode.tribes.enabled()
	var support: XRController3D=rig.right if rig.left_handed else rig.left
	var grip: bool=game.bindings.vr_pressed(rig,"support")
	var trigger: bool=game.bindings.vr_pressed(rig,"offhand_fire")
	var pose: Dictionary=rig.sample_pose() if available else {}
	var equipment_busy:=equipment.update(delta,available,pose,grip,trigger)
	var candidate:=true
	if (de or tribes) and not gesture.held:
		var relative: Vector3=rig.head.transform.affine_inverse()*support.position
		candidate=relative.y>-.30 and relative.z>-.20 and absf(relative.x)>.12
		# An intentional shoulder grab takes priority over an existing pump or
		# support grip; weapon_pose has already released those local latches.
		candidate=candidate and (rig.shoulder_equipment_claims_hand() or not rig.support_aim.engaged and not rig.physical_reload.busy())
	var result:=""
	if not equipment_busy and (candidate or gesture.held):
		result=gesture.sample(support.position-rig.head.position,delta,grip,trigger,available and (game.match_mode.fortress.enabled() or tribes or de and game.match_mode.defusal.phase=="live") and not pose.is_empty())
	else:gesture.busy=false;gesture.latched=false;gesture.samples.clear()
	if result=="arm":
		var role: String=game.local_state().get("tf_class","")
		var pipe: bool=game.match_mode.fortress.charges.has(game.multiplayer.get_unique_id())
		if de or tribes:send("arm",pose)
		elif game.match_mode.fortress.walkers.mounted(game.multiplayer.get_unique_id()) or not role in ["soldier","demoman","pyro"] or pipe:
			gesture.held=false;send("ability",pose)
		else:send("arm",pose)
	elif result in ["throw","cancel"]:send(result,pose,gesture.velocity)
	if gesture.held:
		var item: int=game.local_state().get("tribes_grenade",9) if tribes else game.match_mode.defusal.utility.selected(game.multiplayer.get_unique_id()) if de else -1
		if de and item<0:
			item=game.match_mode.defusal.utility.shoulder_selected(game.multiplayer.get_unique_id())
		if is_instance_valid(grenade) and grenade.get_meta("kind",-1)!=item:grenade.free();grenade=null
		if not is_instance_valid(grenade):
			grenade=Node3D.new();rig.add_child(grenade)
			grenade.set_meta("kind",item)
			var mesh:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.065;sphere.height=.13;mesh.mesh=sphere
			mesh.material_override=preload("res://deathmatch/art.gd").material(Color("d4aa52"),.25,.4);grenade.add_child(mesh)
			var pin:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.012;ring.outer_radius=.020;pin.mesh=ring;pin.position.y=.09;pin.rotation.x=PI/2;pin.material_override=preload("res://deathmatch/art.gd").material(Color("bbbbbb"));grenade.add_child(pin)
			hint=Label3D.new();hint.text="SWING + RELEASE GRIP TO THROW";hint.font_size=24;hint.pixel_size=.0015;hint.position.y=.16;hint.billboard=BaseMaterial3D.BILLBOARD_ENABLED;grenade.add_child(hint);hint.visible=not (de or tribes)
			if tribes:
				mesh.free();pin.free();grenade.add_child(preload("res://deathmatch/tribes/models.gd").make(item))
			if de and item>=0:
				mesh.free();pin.free();grenade.add_child(load("res://deathmatch/counterstrike/grenade_visuals.gd").model(item))
		grenade.global_transform=preload("res://deathmatch/counterstrike/grenade_visuals.gd").held_pose(support.global_transform,support==rig.left) if de else support.global_transform;grenade.visible=true
		update_guide(delta)
	else:
		if is_instance_valid(grenade):grenade.hide()
		if is_instance_valid(guide):guide.hide()

func update_guide(delta: float) -> void:
	guide_elapsed-=delta
	if guide_elapsed>0 and is_instance_valid(guide) and guide.visible:return
	guide_elapsed=.1
	if not is_instance_valid(guide):
		guide=MeshInstance3D.new();guide.mesh=ImmediateMesh.new();rig.add_child(guide);guide.top_level=true;guide.global_transform=Transform3D.IDENTITY
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("e8c46c");guide.material_override=material;guide.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh: ImmediateMesh=guide.mesh;mesh.clear_surfaces();guide.visible=true
	var pose: Dictionary=rig.sample_pose()
	if not pose.has("weapon"):guide.hide();return
	# Only the aiming hand draws a guide. The grenade hand supplies power;
	# drawing a second arc there obscures the grenade and duplicates the aid.
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var aim: Transform3D=rig.global_transform*pose.weapon
	mesh.surface_add_vertex(aim.origin);mesh.surface_add_vertex(aim.origin-aim.basis.z*1.2)
	mesh.surface_end()
