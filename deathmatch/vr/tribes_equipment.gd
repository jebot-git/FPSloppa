extends RefCounted
const Equipment=preload("res://deathmatch/tribes/equipment.gd")
var owner_ref: WeakRef
var item:=""
var grip_was:=true
var trigger_was:=true
var used:=false
var held_seconds:=0.0
var life:=-1
var epoch:=-1
var motion=preload("res://deathmatch/vr/ability_gesture.gd").new()
var models: Dictionary={}
func setup(actions):owner_ref=weakref(actions)
func reset():
	item="";grip_was=true;trigger_was=true;used=false;held_seconds=0
	motion.samples.clear();motion.velocity=Vector3.ZERO;motion.clock=0
	for node in models.values():if is_instance_valid(node):node.hide()
func activate(pose: Dictionary) -> void:
	if used or pose.is_empty():return
	used=true;owner_ref.get_ref().send("activate",pose)
func use_held_pack() -> bool:
	if item!="pack":return false
	var actions=owner_ref.get_ref();var rig=actions.rig
	# Use must share the checked offhand placement shown by the preview. Consume
	# this edge even when tracking/grip was lost, rather than deploying from the gun.
	if actions.available and rig.context_controls_available() and rig.game.bindings.vr_pressed(rig,"support"):
		activate(rig.sample_pose())
	return true
func update(delta: float,valid: bool,pose: Dictionary,grip: bool,trigger: bool) -> bool:
	var actions=owner_ref.get_ref();var rig=actions.rig;var game=rig.game
	var state: Dictionary=game.local_state()
	valid=valid and game.match_mode.tribes.enabled() and not pose.is_empty()
	if life!=state.get("serial",-1) or epoch!=game.map_epoch:
		reset();life=state.get("serial",-1);epoch=game.map_epoch
	if not valid:
		if not item.is_empty():actions.send("cancel",{})
		reset();return false
	var hand: Transform3D=pose.right if pose.left_handed else pose.left
	# Head-relative history excludes skiing, room-scale translation and turning.
	motion.sample(hand.origin-pose.head.origin,delta,false,false,true)
	var carrying: bool=game.match_mode.st.carried(game.multiplayer.get_unique_id())>=0
	var claimed:=not item.is_empty()
	if claimed:
		held_seconds+=delta
		if held_seconds>=9.5:
			actions.send("cancel",{});item="";grip_was=grip;trigger_was=trigger
	if (grip and not grip_was or trigger and not trigger_was and not grip) and item.is_empty() and not actions.gesture.held and not rig.support_aim.engaged:
		item=Equipment.target(pose,state,carrying);used=false;held_seconds=0
		if trigger and not grip:
			item="ammo" if Equipment.Hip.recovery_contains(pose,hand.origin) and game.match_mode.tribes.amount(game.multiplayer.get_unique_id(),state.weapon)>0 else ""
		if not item.is_empty():actions.send("hold_"+item,pose);claimed=true
	elif not item.is_empty():
		if item=="ammo" and not trigger:
			actions.send("transfer",pose,motion.velocity);item=""
		elif item!="ammo" and not grip:
			var moving: bool=motion.velocity.length()>1.2
			actions.send("throw" if item=="flag" and moving else "transfer" if item=="pack" and not used and moving else "cancel",pose,motion.velocity);item=""
		elif trigger and not trigger_was and not used and item!="flag":
			activate(pose)
	grip_was=grip;trigger_was=trigger
	for key in ["kit","pack","flag","ammo"]:
		var show: bool=(key=="kit" and state.get("tribes_kit",false) or key=="pack" and state.get("tribes_pack","none")!="none" or key=="flag" and carrying or key=="ammo" and item=="ammo")
		if show and not models.has(key):
			models[key]=Equipment.model(key,1-maxi(0,state.get("team",0)));rig.add_child(models[key])
		if not models.has(key):continue
		models[key].visible=show
		if show:models[key].global_transform=rig.global_transform*((Equipment.hand_frame(pose) if key=="pack" else hand)*Transform3D(Basis.IDENTITY,Vector3(0,0,-.04)) if item==key else Equipment.mount(pose,key))
	return claimed
