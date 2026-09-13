extends RefCounted
const W = preload("res://deathmatch/weapons.gd")

static func material(color: Color, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.48
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var ob := MeshInstance3D.new()
	ob.mesh = mesh
	ob.material_override = m
	ob.position = pos
	parent.add_child(ob)
	return ob

static func barrel(parent: Node3D, pos: Vector3, radius: float, length: float, m: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	var ob := MeshInstance3D.new()
	ob.mesh = mesh
	ob.material_override = m
	ob.rotation.x = PI/2
	ob.position = pos
	parent.add_child(ob)
	return ob

static var weapon_scenes: Dictionary = {}
const WEAPON_ASSETS = ["fist","afps_1","afps_2","afps_4","afps_4","afps_3","afps_6","afps_5","afps_9","afps_8"]
const WEAPON_LENGTHS = [.22,.90,.55,1.05,1.05,1.05,1.10,.90,1.05,1.2]
const VR_SCALE := .65
const SNIPER_GRIP := Vector3(0,-.01,.025) # Center between the source pistol-grip faces.
# Model-space palm anchors. Exported meshes are centered on their bounds,
# rather than on their handles; never use that origin as a controller grip.
const GRIPS = [Vector3.ZERO,Vector3(0,0,.10),Vector3(0,-.10,.11),Vector3(0,-.035,.04),Vector3(0,-.035,.04),Vector3(0,-.11,-.22),Vector3(0,-.14,.06),Vector3(0,-.11,-.13),Vector3(0,-.10,.02),Vector3(0,-.10,.12)]

static func model_id(id: int,rules: String) -> int:
	if rules=="quake":return [0,0,3,4,6,5,6,7,8,9][clampi(id,0,9)]
	if rules=="ut99":return [0,7,2,9,4,5,6,7,8,9,7,2][clampi(id,0,11)]
	return clampi(id,0,9)

static func muzzle(id: int,rules: String="doom") -> Vector3:
	if rules=="sentry":return Vector3(0,0,-.855534)
	if rules=="tf_sniper" or (rules=="ut99" and id==9):return Vector3(0,.10827,-1.039774)
	if rules=="tf_flame":return Vector3(0,.035,-.785)
	if rules=="ut99" and id==0:return Vector3(0,0,-.65)
	if rules=="quake" and id in [0,1]:return Vector3(0,.411368,-.521071)
	if rules=="ut99" and id==11:return Vector3(0,.08,-.45)
	id=model_id(id,rules)
	return Vector3(0,.05,.22-WEAPON_LENGTHS[id])

static func held_transform(pose: Transform3D, id: int, size: float = VR_SCALE,rules: String="doom") -> Transform3D:
	var grip: Vector3=Vector3(0,-.055,.06) if rules=="tf_flame" else Vector3(0,-.17,.09) if rules=="ut99" and id==0 else GRIPS[model_id(id,rules)]
	if rules=="tf_sniper" or (rules=="ut99" and id==9):grip=SNIPER_GRIP
	return Transform3D(pose.basis.scaled(Vector3.ONE*size),pose.origin-pose.basis*(grip*size))

static func clip_saw(model: Node3D) -> void:
	# Retract the rendered saw at walls, preserving the controller/hand pose.
	var grip: Vector3=model.to_global(GRIPS[1])
	var tip: Vector3=model.to_global(muzzle(1))
	var hit:=model.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(grip,tip,1))
	if not hit.is_empty():model.global_position+=(grip-tip).normalized()*(tip.distance_to(hit.position)+.025)

static func desktop_hand(left: bool, pitch: float, recoil: float, dual_pistols: bool=false) -> Vector3:
	var grip := Vector3(.10 if left else .13,1.15,-.46 if left else -.30)
	if left and dual_pistols: grip=Vector3(-.13,1.15,-.30)
	var pivot := Vector3(0,1.3,0)
	return pivot+Basis(Vector3.RIGHT,pitch)*(grip-pivot)+Vector3(0,0,recoil*.035)

static func weapon(id: int,filter_mode: int=2,rules: String="doom") -> Node3D:
	var slot:=id
	id=model_id(id,rules)
	var root := Node3D.new()
	root.name = "WeaponModel"
	root.set_meta("muzzle",muzzle(slot,rules))
	if rules in ["sentry","tf_sniper"] or (rules=="ut99" and slot==9):
		var key:="sentry_gatling" if rules=="sentry" else "sniper"
		if not weapon_scenes.has(key):weapon_scenes[key]=load("res://deathmatch/weapons/experimental/"+key+".scn")
		root.add_child(weapon_scenes[key].instantiate());root.set_meta(key,true)
		if key=="sniper":
			root.set_meta("scope_rear",Vector3(0,.17939,-.0609))
			root.set_meta("scope_front",Vector3(0,.17939,-.31491))
			root.set_meta("scope_radius",.019)
		if DisplayServer.get_name()!="headless":load("res://deathmatch/maps/filtering.gd").new().apply(root,filter_mode)
		return root
	if rules=="tf_flame":
		if not weapon_scenes.has(rules):weapon_scenes[rules]=load("res://deathmatch/weapons/experimental/tf_flamethrower.scn")
		root.add_child(weapon_scenes[rules].instantiate());root.set_meta("tf_flamethrower",true)
		if DisplayServer.get_name()!="headless":load("res://deathmatch/maps/filtering.gd").new().apply(root,filter_mode)
		return root
	if id==0:
		if rules!="doom":
			var key:="axe" if rules=="quake" else "impact_hammer"
			if not weapon_scenes.has(key):weapon_scenes[key]=load("res://deathmatch/weapons/experimental/"+key+".scn")
			root.add_child(weapon_scenes[key].instantiate())
		if DisplayServer.get_name()!="headless":load("res://deathmatch/maps/filtering.gd").new().apply(root,filter_mode)
		return root
	var asset: String = WEAPON_ASSETS[clampi(id,0,W.DATA.size()-1)]
	if not weapon_scenes.has(asset): weapon_scenes[asset] = load("res://deathmatch/weapons/"+asset+".glb")
	var model: Node3D = weapon_scenes[asset].instantiate()
	model.name = "TexturedWeapon"
	root.add_child(model)
	if id==0:
		model.rotation_degrees = Vector3(0,90,0)
		model.position=Vector3(.08,0,-.05)
	elif id==4 and rules=="doom":
		# Restore the original textured CC0 mesh and its paired-bore variant.
		model.scale.x=1.30
		var steel:=material(Color("667079"),.8)
		for x in [-.065,.065]:
			barrel(root,Vector3(x,.05,-.56),.053,.52,steel)
			barrel(root,Vector3(x,.05,-.826),.039,.008,material(Color("101315")))
	elif id==8 and rules=="doom":
		model.scale=Vector3(1.25,1.1,1.0)
		for x in [-.16,.16]:
			barrel(root,Vector3(x,.05,-.57),.045,.25,material(Color("6cdf58"),.25,1.8))
	root.set_meta("muzzle",muzzle(slot,rules))
	if rules!="doom":variant_details(root,model,slot,rules)
	if DisplayServer.get_name()!="headless":load("res://deathmatch/maps/filtering.gd").new().apply(root,filter_mode)
	return root

static func marine(color: Color) -> Node3D:
	var root = load("res://deathmatch/avatars/fallback.gd").new()
	var upper:=Node3D.new();upper.name="Upper";upper.position.y=.78;root.add_child(upper)
	var armor := material(color,0.35)
	var dark := material(Color("1d2529"))
	var visor := material(Color("f2bc61"),0.7,0.3)
	box(upper,Vector3(0,.24,0),Vector3(.55,.58,.32),armor)
	var head:=Node3D.new();head.name="Head";head.position.y=.70;upper.add_child(head)
	box(head,Vector3.ZERO,Vector3(.35,.34,.34),armor)
	box(head,Vector3(0,.01,-.18),Vector3(.29,.11,.03),visor)
	for x in [-.18,.18]:
		var side:="Left" if x<0 else "Right"
		for part in ["Thigh","Shin"]:box(root,Vector3.ZERO,Vector3(.21,1,.24),dark).name=side+part
		box(root,Vector3(x,.09,-.05),Vector3(.24,.18,.37),dark).name=side+"Boot"
	for x in [-.38,.38]:
		var side:="Left" if x<0 else "Right"
		var arm:=box(upper,Vector3(x,.32,0),Vector3(.22,1,.30),armor);arm.name=side+"Arm";arm.scale.y=.36
		var forearm:=box(upper,Vector3(x,.12,-.16),Vector3(.16,1,.37),dark);forearm.name=side+"Forearm";forearm.scale.y=.23
	var gun := weapon(3)
	gun.position = Vector3(.20,.13,-.22)
	gun.scale = Vector3.ONE*.65
	upper.add_child(gun)
	root.animate(0,Vector3.ZERO,"stand",1.65,true,{},false)
	return root

static func sound(kind: int) -> AudioStreamWAV:
	return load("res://deathmatch/audio/weapon_%d.wav"%kind)

static func legacy_synth_sound(kind: int) -> AudioStreamWAV:
	var length := 0.24 if kind < 6 else 0.42
	if kind==8: length = .8
	var rate := 22050
	var bytes := PackedByteArray()
	bytes.resize(int(length*rate)*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 765+kind
	var phase := 0.0
	var low := 0.0
	for i in range(bytes.size()/2):
		var t := float(i)/rate
		var envelope := exp(-t*(18 if kind < 6 else 9)) * minf(t*1500,1)
		phase += TAU * (95.0 + kind*23.0) * exp(-t*5.0) / rate
		low = lerpf(low,rng.randf_range(-1,1),.3)
		var value := (low*.75+sin(phase)*.4)*envelope
		if kind>=7: value = (sin(phase*4)*.45+sin(phase*7)*.12+low*.15)*envelope
		bytes.encode_s16(i*2,int(clampf(value,-1,1)*23000))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	return wav

static func tint_model(node: Node,color: Color) -> void:
	# Duplicate materials: cached source meshes and the Doom models stay intact.
	if node is MeshInstance3D and node.mesh:
		for surface in node.mesh.get_surface_count():
			var original=node.get_active_material(surface)
			if original is StandardMaterial3D:
				var copy: StandardMaterial3D=original.duplicate();copy.albedo_color*=color
				node.set_surface_override_material(surface,copy)
	for child in node.get_children():tint_model(child,color)

static func fitting(root: Node3D,key: String,pos: Vector3,size: Vector3,m: Material) -> Node3D:
	if not weapon_scenes.has(key):weapon_scenes[key]=load("res://deathmatch/weapons/experimental/"+key+".scn")
	var node: Node3D=weapon_scenes[key].instantiate();root.add_child(node)
	node.position=pos;node.scale=size
	set_fitting_material(node,m)
	return node

static func set_fitting_material(node: Node,m: Material) -> void:
	if node is MeshInstance3D:node.material_override=m
	for child in node.get_children():set_fitting_material(child,m)

static func variant_barrel(root: Node3D,pos: Vector3,radius: float,length: float,m: Material) -> Node3D:
	var mount:=Node3D.new();root.add_child(mount);mount.position=pos;mount.rotation.x=PI/2
	var tube:=fitting(mount,"barrel_sleeve",Vector3.ZERO,Vector3(radius,radius,length),m)
	tube.rotation.x=-PI/2
	return mount

static func variant_details(root: Node3D,model: Node3D,slot: int,rules: String) -> void:
	var quake=["888888","888888","b9a17f","b87a4e","c3ac69","7c8b75","c06b49","9b7561","748fb4","728c75"]
	var ut=["888888","91e85d","acbdc9","bc75ed","ffd253","c6a165","ef795b","67c9aa","c5c8d1","748795","5fbdcf","729aef"]
	var color:=Color((quake if rules=="quake" else ut)[slot]);tint_model(model,color)
	var accent:=material(color,.65,.18)
	var dark:=material(color.darkened(.18),.7)
	for x in [-.11,.11]:box(root,Vector3(x,.08,-.3),Vector3(.045,.09,.30),accent)
	if rules=="quake":
		match slot:
			3:
				for x in [-.07,.07]:variant_barrel(root,Vector3(x,.07,-.59),.064,.45,dark)
				box(root,Vector3(0,.13,-.32),Vector3(.21,.05,.22),accent)
			4:
				var drum:=variant_barrel(root,Vector3(0,-.02,-.30),.18,.32,accent);drum.rotation=Vector3(0,0,PI/2)
				for x in [-.17,.17]:box(root,Vector3(x,0,-.30),Vector3(.025,.13,.12),dark)
			5:box(root,Vector3(.14,-.09,-.15),Vector3(.12,.24,.21),accent)
			7:
				for x in [-.095,.095]:variant_barrel(root,Vector3(x,.1,-.48),.06,.34,dark)
				box(root,Vector3(0,.18,-.25),Vector3(.25,.08,.25),accent)
			8:
				for x in [-.20,.20]:
					variant_barrel(root,Vector3(x,.05,-.57),.06,.3,dark)
					for z in [-.46,-.54,-.62]:variant_barrel(root,Vector3(x,.05,z),.075,.025,material(Color("81a9ef"),.5,.7))
	elif rules=="ut99":
		match slot:
			1:
				for x in [-.17,.17]:
					var tank:=variant_barrel(root,Vector3(x,.11,-.25),.085,.30,material(Color("91ee3c"),.15,.5));tank.rotation.x=0
			3:
				for x in [-.11,.11]:
					variant_barrel(root,Vector3(x,.06,-.72),.035,.34,accent)
					variant_barrel(root,Vector3(x,.06,-.85),.045,.025,material(Color("cf80ff"),.2,1))
			4:
				box(root,Vector3(0,.14,-.25),Vector3(.30,.14,.28),accent)
				for x in [-.17,.17]:box(root,Vector3(x,.04,-.5),Vector3(.05,.16,.30),accent)
			6:
				for i in 6:
					var v:=Vector2.from_angle(i*TAU/6)*.12
					variant_barrel(root,Vector3(v.x,.05+v.y,-.75),.053,.20,dark)
			7:
				for x in [-.14,.14]:
					for z in [-.30,-.37,-.44]:variant_barrel(root,Vector3(x,.1,z),.065,.025,material(Color("59dfbf"),.5,.6))
			9:
				for z in [-.06,-.29]:
					box(root,Vector3(0,.175,z),Vector3(.075,.27,.065),dark)
				fitting(root,"scope_housing",Vector3(0,.34,-.18),Vector3(.055,.055,.40),dark)
				root.set_meta("scope_rear",Vector3(0,.34,.021))
				root.set_meta("scope_front",Vector3(0,.34,-.381))
				root.set_meta("scope_radius",.046)
			10:
				var blade:=variant_barrel(root,Vector3(0,.21,-.36),.23,.025,material(Color("bdc9ce"),.85));blade.rotation.x=0
				for i in 12:
					var angle:=i*TAU/12;var tooth:=box(root,Vector3(sin(angle)*.23,.21,-.36+cos(angle)*.23),Vector3(.055,.026,.045),accent);tooth.rotation.y=angle
			11:
				model.scale=Vector3(.72,.8,.50)
				var disc:=variant_barrel(root,Vector3(0,.08,-.23),.19,.055,accent);disc.rotation.x=0
				var core:=variant_barrel(root,Vector3(0,.115,-.23),.11,.02,material(Color("98baff"),.2,1));core.rotation.x=0
