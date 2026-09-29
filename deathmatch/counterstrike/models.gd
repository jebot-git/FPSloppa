extends RefCounted
## Blender-authored, textured models share the existing arsenal's CC0 finish.
const NAMES=["knife","glock","usp","m3","xm1014","mp5","ak47","m4a1","m249","awp","deagle","p90"]
const LENGTHS=[.40,.32,.36,.95,.90,.63,.92,.86,1.02,1.12,.40,.58]
static var cache: Dictionary={}
static func muzzle(slot: int) -> Vector3:
	return Vector3(0,0,-.44) if slot==0 else Vector3(0,.113 if slot in [1,2,10,11] else .085,-LENGTHS[clampi(slot,0,11)]-.015)
static func grip(slot: int) -> Vector3:
	return Vector3(0,0,-.032) if slot==0 else Vector3(0,.005,-.26) if slot==11 else Vector3(0,-.057,.028)
static func support(slot: int) -> Vector3:
	# Palm contact on the fore-end/handguard, in authored model coordinates.
	return {3:Vector3(0,-.032,-.51),4:Vector3(0,-.032,-.48),5:Vector3(0,-.025,-.45),6:Vector3(0,-.030,-.48),7:Vector3(0,-.020,-.49),8:Vector3(0,-.032,-.54),9:Vector3(0,-.032,-.48),11:Vector3(0,-.030,-.39)}.get(slot,grip(slot))
static func support_pose(model: Transform3D,slot: int,left: bool) -> Transform3D:
	# Palm faces up under the fore-end; fingers wrap inward from either side.
	return Transform3D(model.basis.orthonormalized()*Basis(Vector3.BACK,PI/2 if left else -PI/2),model*support(slot))
static func ammo_basis(_slot: int) -> Basis:
	# Feed end points toward the controller's thumb (-Z), not along its +Y axis.
	return Basis(Vector3.RIGHT,-PI/2)
static func ammo_pose(hand: Transform3D,slot: int,left: bool=false) -> Transform3D:
	# Grip pose axes describe a controller, not the gun's magazine socket.
	# Present cartridges forward and the magazine top above the curled fingers.
	var offset:=Vector3(-.025 if left else .025,-.012,-.075) if slot in [3,4] else Vector3(0,-.025,-.045)
	var basis:=ammo_basis(slot)
	return hand*Transform3D(basis.scaled(Vector3.ONE*(1.0 if slot in [3,4] else .65)),offset)
static func make(slot: int) -> Node3D:
	slot=clampi(slot,0,11)
	if not cache.has(slot):cache[slot]=load("res://deathmatch/weapons/cs16/"+NAMES[slot]+".scn")
	var root: Node3D=cache[slot].instantiate();root.name="WeaponModel"
	root.set_meta("cs16",slot);root.set_meta("muzzle",muzzle(slot))
	for key in ["SightRear","SightFront"]:
		var marker:=root.find_child(key,true,false) as Node3D
		if marker:root.set_meta("sight_rear" if key=="SightRear" else "sight_front",marker.position)
	if slot==9:
		root.set_meta("scope_rear",Vector3(0,.244,-.0265));root.set_meta("scope_front",Vector3(0,.244,-.5155));root.set_meta("scope_radius",.037);root.set_meta("sniper",true)
	var action=preload("res://deathmatch/counterstrike/action.gd").new();root.add_child(action);action.setup(root,slot)
	return root
static func fire(model: Node3D):
	if is_instance_valid(model) and model.has_node("ChamberAction"):model.get_node("ChamberAction").shot()
static func ammunition(slot: int) -> Node3D:
	var root:=Node3D.new();root.name="ReloadAmmunition"
	if slot in [3,4]:
		var body:=MeshInstance3D.new();var shell:=CylinderMesh.new();shell.top_radius=.010;shell.bottom_radius=.010;shell.height=.045;shell.radial_segments=12;body.mesh=shell
		var red:=StandardMaterial3D.new();red.albedo_color=Color("a73829");red.roughness=.7;body.material_override=red;root.add_child(body)
		var base:=MeshInstance3D.new();var brass:=CylinderMesh.new();brass.top_radius=.011;brass.bottom_radius=.011;brass.height=.012;brass.radial_segments=12;base.mesh=brass;base.position.y=-.026
		var gold:=StandardMaterial3D.new();gold.albedo_color=Color("b89145");gold.metallic=.5;gold.roughness=.4;base.material_override=gold;root.add_child(base)
	else:
		var model:=make(slot);var mag:=model.find_child("Magazine",true,false)
		if mag:
			var mesh: Node3D=mag.duplicate();root.add_child(mesh)
			mesh.position-=load("res://deathmatch/counterstrike/reload_state.gd").MAG_POINTS[slot]
		if slot==8:
			var belt:=model.find_child("FeedBelt",true,false) as Node3D
			if belt:
				var attached: Node3D=belt.duplicate();root.add_child(attached)
				attached.position-=load("res://deathmatch/counterstrike/reload_state.gd").MAG_POINTS[slot]
		model.free()
	return root
static func presentation(model: Node3D,suppressed: bool,row: Array=[]):
	if not is_instance_valid(model) or not model.has_meta("cs16"):return
	var node:=model.find_child("Suppressor",true,false)
	if node:node.visible=suppressed
	# The authored suppressor cap extends .186 beyond the bare muzzle marker.
	model.set_meta("muzzle",muzzle(int(model.get_meta("cs16")))+Vector3.FORWARD*(.186 if node and suppressed else 0.0))

	var action:=model.get_node_or_null("ChamberAction")
	if action:action.sync(row)
