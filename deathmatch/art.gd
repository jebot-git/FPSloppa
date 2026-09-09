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
const WEAPON_ASSETS = ["fist","afps_1","afps_2","afps_4","afps_4","afps_3","afps_6","afps_5","afps_9"]
const WEAPON_LENGTHS = [.22,.90,.55,1.05,1.05,1.05,1.10,.90,1.05]
const VR_SCALE := .65
# Model-space palm anchors. Exported meshes are centered on their bounds,
# rather than on their handles; never use that origin as a controller grip.
const GRIPS = [Vector3.ZERO,Vector3(0,0,.10),Vector3(0,-.10,.11),Vector3(0,-.035,.04),Vector3(0,-.035,.04),Vector3(0,-.11,-.22),Vector3(0,-.14,.06),Vector3(0,-.11,-.13),Vector3(0,-.10,.02)]

static func muzzle(id: int) -> Vector3:
	return Vector3(0,.05,.22-WEAPON_LENGTHS[id])

static func held_transform(pose: Transform3D, id: int, size: float = VR_SCALE) -> Transform3D:
	return Transform3D(pose.basis.scaled(Vector3.ONE*size),pose.origin-pose.basis*(GRIPS[id]*size))

static func desktop_hand(left: bool, pitch: float, recoil: float, dual_pistols: bool=false) -> Vector3:
	var grip := Vector3(.10 if left else .13,1.15,-.46 if left else -.30)
	if left and dual_pistols: grip=Vector3(-.13,1.15,-.30)
	var pivot := Vector3(0,1.3,0)
	return pivot+Basis(Vector3.RIGHT,pitch)*(grip-pivot)+Vector3(0,0,recoil*.035)

static func weapon(id: int) -> Node3D:
	var root := Node3D.new()
	root.name = "WeaponModel"
	var asset: String = WEAPON_ASSETS[clampi(id,0,8)]
	if not weapon_scenes.has(asset): weapon_scenes[asset] = load("res://deathmatch/weapons/"+asset+".glb")
	var model: Node3D = weapon_scenes[asset].instantiate()
	model.name = "TexturedWeapon"
	root.add_child(model)
	if id==0:
		model.rotation_degrees = Vector3(0,90,0)
		model.position=Vector3(.08,0,-.05)
	elif id==4:
		# Restore the original textured CC0 mesh and its paired-bore variant.
		model.scale.x=1.30
		var steel:=material(Color("667079"),.8)
		for x in [-.065,.065]:
			barrel(root,Vector3(x,.05,-.56),.053,.52,steel)
			barrel(root,Vector3(x,.05,-.826),.039,.008,material(Color("101315")))
	elif id==8:
		model.scale=Vector3(1.25,1.1,1.0)
		for x in [-.16,.16]:
			barrel(root,Vector3(x,.05,-.57),.045,.25,material(Color("6cdf58"),.25,1.8))
	root.set_meta("muzzle",muzzle(id))
	return root

static func marine(color: Color) -> Node3D:
	var root := Node3D.new()
	var armor := material(color,0.35)
	var dark := material(Color("1d2529"))
	var visor := material(Color("f2bc61"),0.7,0.3)
	box(root,Vector3(0,1.02,0),Vector3(.55,.58,.32),armor)
	box(root,Vector3(0,1.48,0),Vector3(.35,.34,.34),armor)
	box(root,Vector3(0,1.49,-.18),Vector3(.29,.11,.03),visor)
	for x in [-.18,.18]:
		box(root,Vector3(x,.41,0),Vector3(.21,.72,.24),dark)
		box(root,Vector3(x,.09,-.05),Vector3(.24,.18,.37),dark)
	for x in [-.38,.38]:
		box(root,Vector3(x,1.1,0),Vector3(.22,.36,.30),armor)
		box(root,Vector3(x,.9,-.16),Vector3(.16,.23,.37),dark)
	var gun := weapon(3)
	gun.position = Vector3(.20,.91,-.22)
	gun.scale = Vector3.ONE*.65
	root.add_child(gun)
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
