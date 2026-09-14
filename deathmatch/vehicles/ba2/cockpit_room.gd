extends RefCounted
## Shared presentation from the original BA-2 remote cockpit laboratory.
var room: Node3D
var console: Node3D
var sticks: Array[Node3D]=[]
var buttons: Array[StandardMaterial3D]=[]
var grips: Array[Vector3]=[]
func material(color: Color,glow: float=0.0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.72
	if glow>0:m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=glow
	return m
func box(parent: Node3D,pos: Vector3,size: Vector3,color: Color,solid: bool=false) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=size;mesh.mesh=shape;mesh.material_override=material(color);parent.add_child(mesh);mesh.position=pos
	if solid:
		var body:=StaticBody3D.new();parent.add_child(body);body.position=pos
		var col:=CollisionShape3D.new();var b:=BoxShape3D.new();b.size=size;col.shape=b;body.add_child(col)
	return mesh
func label3(parent: Node3D,text: String,pos: Vector3,size: int=32) -> void:
	var label:=Label3D.new();parent.add_child(label);label.text=text;label.position=pos;label.font_size=size;label.pixel_size=.0014;label.modulate=Color("80e9df");label.no_depth_test=false
func build(parent: Node3D, automatic: bool=false) -> void:
	room=parent
	console=Node3D.new();console.name="AdjustableControls";room.add_child(console)
	box(room,Vector3(0,-.12,-.5),Vector3(4,.2,5),Color("111b25"))
	box(room,Vector3(0,2.0,-2.6),Vector3(4.2,4,.2),Color("152432"))
	for side in [-1,1]:
		box(room,Vector3(side*1.95,1.5,-.45),Vector3(.16,3.2,4.4),Color("15202b"))
		box(console,Vector3(side*.57,.62,-.44),Vector3(.40,.28,.8),Color("263a49"))
		box(console,Vector3(side*1.63,1.48,-2.22),Vector3(.035,2,.05),Color("55ded5")).material_override=material(Color("55ded5"),1)
		var stick:=Node3D.new();console.add_child(stick);stick.position=Vector3(side*.42,.79,-.43);sticks.append(stick)
		box(stick,Vector3.ZERO,Vector3(.21,.045,.23),Color("080e15"))
		var pivot:=Node3D.new();stick.add_child(pivot);pivot.name="Pivot"
		box(pivot,Vector3(0,.1,0),Vector3(.052,.20,.058),Color("57707c"))
		box(pivot,Vector3(0,.19,0),Vector3(.095,.13,.09),Color("142432"))
		buttons.append(box(pivot,Vector3(0,.262,-.013),Vector3(.04,.016,.04),Color("ff8861")).material_override)
		grips.append(stick.position+Vector3(0,.19,0))
		label3(console,("L / SENTRY" if side<0 else "R / SENTRY") if automatic else ("L / FIRE" if side<0 else "R / AIM + FIRE"),Vector3(side*.57,.86,-.84),21)
	box(room,Vector3(0,.45,.09),Vector3(.63,.12,.65),Color("1c303d"))
	box(room,Vector3(0,.88,.4),Vector3(.65,.82,.13),Color("1c303d"))
	box(console,Vector3(0,1.49,-2.26),Vector3(3.36,2.00,.14),Color("071018"))
	label3(console,"BA-2  /  REMOTE PILOT STATION",Vector3(0,2.62,-2.25),37)
	label3(console,"GRIP: MANUAL   /   TRIGGER: FIRE   /   RELEASE: AUTO   /   JUMP: EXIT" if automatic else "GRIP TO HOLD   /   TRIGGER TO FIRE   /   B OR Y TO RECENTER",Vector3(0,.38,-2.23),23)
	if automatic:return
	var lamp:=OmniLight3D.new();console.add_child(lamp);lamp.position=Vector3(0,2,-.5);lamp.omni_range=5;lamp.light_energy=1.6;lamp.light_color=Color("9fc9df")
