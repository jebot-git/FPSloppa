extends RefCounted
var held:=false
var active:=false
var grip_was_down:=false
var hand_side:=false
var held_hand:=-1
var hand_edges:=[true,true]
var model: Node3D
var label: Label3D
var rig_ref: WeakRef
var rig:
	get:return rig_ref.get_ref()
func setup(value) -> void:rig_ref=weakref(value)
func reset() -> void:
	held=false;active=false;grip_was_down=true;held_hand=-1;hand_edges=[true,true]
	if is_instance_valid(model):model.hide()
	if rig.game.voice:rig.game.voice.radio_trigger(false)
func shoulder() -> Vector3:
	return rig.origin.to_local(rig.shoulder_mount(true).origin)
func update(valid: bool) -> void:
	var voice=rig.game.voice
	if not is_instance_valid(model):
		model=Node3D.new();rig.add_child(model)
		var art=preload("res://deathmatch/art.gd")
		art.box(model,Vector3.ZERO,Vector3(.065,.10,.03),art.material(Color("303a30"),.25))
		art.box(model,Vector3(-.02,.08,0),Vector3(.006,.09,.006),art.material(Color("171b17")))
		for y in 4:art.box(model,Vector3(0,.022-y*.012,-.017),Vector3(.045,.004,.003),art.material(Color("0b100c")))
		label=Label3D.new();label.font=preload("res://deathmatch/ui/iron_theme.gd").font_for(rig.game);label.font_size=24;label.pixel_size=.0012;label.position.y=.15;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;model.add_child(label)
	model.visible=valid
	model.global_transform=rig.shoulder_mount(true)
	var mounted_visible:=valid
	valid=valid and voice!=null and voice.team_available() and voice.game.voice_enabled and voice.mode>0
	if rig.get("cq_utility")!=null:
		update_cq(valid,mounted_visible);return
	var grip: bool=rig.game.bindings.vr_pressed(rig,"support")
	if hand_side!=rig.left_handed:reset();hand_side=rig.left_handed
	if not valid:
		reset();grip_was_down=grip;model.visible=mounted_visible;label.hide();return
	var hand: XRController3D=rig.right if rig.left_handed else rig.left
	var near: bool=hand.position.distance_to(shoulder())<.22
	if not grip:held=false
	elif near and not grip_was_down and not rig.physical_actions.busy():held=true
	grip_was_down=grip
	active=held and rig.game.bindings.vr_pressed(rig,"offhand_fire")
	voice.radio_trigger(active)
	model.visible=true
	model.global_transform=rig.attached_hand(true,hand.global_transform) if held else rig.shoulder_mount(true)
	# The grip's forward axis runs toward the fingertips; align the antenna to it.
	if held:model.rotate_object_local(Vector3.RIGHT,-PI/2)
	label.visible=false
	label.text=(("SQUAD RADIO" if voice.radio_mode==1 else "TEAM RADIO") if active else "TRIGGER · SQUAD / DOUBLE · TEAM" if held else "GRAB RADIO") if rig.game.has_method("draw_class_players") else "TEAM RADIO" if active else "HOLD TRIGGER · TEAM" if held else "GRAB RADIO"
	label.modulate=Color("87e8ae") if active else Color("e5d5ad")

func update_cq(valid:bool,mounted_visible:bool)->void:
	var voice=rig.game.voice
	if not valid:reset();model.visible=mounted_visible;label.hide();return
	var controllers:=[rig.left,rig.right];var near:=false
	for i in 2:
		var down:bool=controllers[i].get_float("grip")>.6
		var contact:bool=controllers[i].global_position.distance_to(rig.shoulder_mount(true).origin)<.25
		near=near or contact
		if not held and not rig.cq_utility.held and down and not hand_edges[i] and contact:held_hand=i;held=true
		hand_edges[i]=down
	if held and not hand_edges[held_hand]:held=false;held_hand=-1
	active=held and controllers[held_hand].get_float("trigger")>.6
	voice.radio_trigger(active)
	model.global_transform=controllers[held_hand].global_transform if held else rig.shoulder_mount(true)
	if held:model.rotate_object_local(Vector3.RIGHT,-PI/2)
	model.visible=true;label.visible=false
	label.text=("SQUAD RADIO" if voice.radio_mode==1 else "TEAM RADIO") if active else "TRIGGER · SQUAD / DOUBLE · TEAM" if held else "GRIP · RADIO"
	label.modulate=Color("87e8ae") if active else Color("e5d5ad")
