extends RefCounted
var held:=false
var active:=false
var grip_was_down:=false
var hand_side:=false
var model: Node3D
var label: Label3D
var rig_ref: WeakRef
var rig:
	get:return rig_ref.get_ref()
func setup(value) -> void:rig_ref=weakref(value)
func reset() -> void:
	held=false;active=false;grip_was_down=true
	if is_instance_valid(model):model.hide()
	if rig.game.voice:rig.game.voice.set_radio(false)
func shoulder() -> Vector3:
	var yaw:=Basis(Vector3.UP,rig.head.rotation.y)
	return rig.head.position+yaw*Vector3(.23 if rig.left_handed else -.23,-.25,.04)
func update(valid: bool) -> void:
	var voice=rig.game.voice
	valid=valid and voice!=null and voice.team_available() and voice.game.voice_enabled and voice.mode>0
	var grip: bool=rig.game.bindings.vr_pressed(rig,"support")
	if hand_side!=rig.left_handed:reset();hand_side=rig.left_handed
	if not valid:reset();grip_was_down=grip;return
	var hand: XRController3D=rig.right if rig.left_handed else rig.left
	var near: bool=hand.position.distance_to(shoulder())<.22
	if not grip:held=false
	elif near and not grip_was_down and not rig.physical_actions.busy():held=true
	grip_was_down=grip
	active=held and rig.game.bindings.vr_pressed(rig,"offhand_fire")
	voice.set_radio(active)
	if not is_instance_valid(model):
		model=Node3D.new();rig.add_child(model)
		var art=preload("res://deathmatch/art.gd")
		art.box(model,Vector3.ZERO,Vector3(.065,.10,.03),art.material(Color("303a30"),.25))
		art.box(model,Vector3(-.02,.08,0),Vector3(.006,.09,.006),art.material(Color("171b17")))
		for y in 4:art.box(model,Vector3(0,.022-y*.012,-.017),Vector3(.045,.004,.003),art.material(Color("0b100c")))
		label=Label3D.new();label.font_size=24;label.pixel_size=.0012;label.position.y=.15;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;model.add_child(label)
	model.visible=true
	model.global_transform=hand.global_transform if held else Transform3D(rig.head.global_basis.orthonormalized(),rig.origin.to_global(shoulder()))
	# The grip's forward axis runs toward the fingertips; align the antenna to it.
	if held:model.rotate_object_local(Vector3.RIGHT,-PI/2)
	label.visible=held or near
	label.text="TEAM RADIO" if active else "HOLD TRIGGER · TEAM" if held else "GRAB RADIO"
	label.modulate=Color("87e8ae") if active else Color("e5d5ad")
