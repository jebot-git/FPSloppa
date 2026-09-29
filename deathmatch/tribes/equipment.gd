extends RefCounted
## One set of tracked attachment/reach rules for the client and authority.
const Hip=preload("res://deathmatch/vr/hip_mount.gd")
static func mount(pose: Dictionary,item: String) -> Transform3D:
	if item in ["kit","ammo"]:return Hip.pouch(pose)
	var side:=Hip.offhand_side(pose)
	return Hip.chest(pose)*Transform3D(Basis.IDENTITY,Vector3(side*(.17 if item=="pack" else -.17),-.08,-.24))
static func hand_frame(pose: Dictionary) -> Transform3D:
	# Grip locates the palm; the OpenXR aim pose supplies pointing orientation.
	# Older recordings without an aim pose retain their original grip fallback.
	var grip: Transform3D=pose.right if pose.left_handed else pose.left
	var aim: Transform3D=pose.get("offhand_weapon",grip)
	return Transform3D(aim.basis,grip.origin)
static func target(pose: Dictionary,state: Dictionary,carrying: bool) -> String:
	if pose.is_empty():return ""
	var hand: Vector3=pose.right.origin if pose.left_handed else pose.left.origin
	if (state.get("tribes_pack","none")!="none") and mount(pose,"pack").origin.distance_to(hand)<.16:return "pack"
	if carrying and mount(pose,"flag").origin.distance_to(hand)<.16:return "flag"
	if state.get("tribes_kit",false) and Hip.recovery_contains(pose,hand):return "kit"
	return ""
static func model(item: String,team: int=0) -> Node3D:
	var root:=Node3D.new();var art=preload("res://deathmatch/art.gd")
	var metal:=art.material(Color("334652"),.55)
	var accent:=art.material(Color("6ed5ab") if item=="kit" else Color("eb8d55") if item=="pack" else Color("e45e51") if team==0 else Color("67a5ed"),.2)
	# Compact native geometry: no textures, springs or extra imported skeleton.
	art.box(root,Vector3.ZERO,Vector3(.105,.15,.052),metal)
	art.box(root,Vector3(0,0,-.030),Vector3(.082,.12,.012),accent)
	if item=="kit":
		var white:=art.material(Color("e8efe8"))
		art.box(root,Vector3(0,0,-.039),Vector3(.052,.015,.007),white)
		art.box(root,Vector3(0,0,-.039),Vector3(.015,.052,.007),white)
	elif item=="flag":
		var gold:=art.material(Color("eed38a"),.4)
		art.box(root,Vector3(-.028,0,-.039),Vector3(.008,.09,.008),gold)
		art.box(root,Vector3(-.003,.020,-.041),Vector3(.05,.036,.006),gold)
	else:
		for y in [-.035,0,.035]:art.box(root,Vector3(0,y,-.041),Vector3(.058,.01,.01),metal)
	return root
