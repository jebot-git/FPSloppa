extends Node3D
## Original fictional game prop. Key locations share the authority's contact
## geometry, so rendered buttons and interactive regions cannot drift apart.
const Contact=preload("res://deathmatch/counterstrike/bomb_interaction.gd")
const Art=preload("res://deathmatch/art.gd")
var display: Label3D
var lamp: MeshInstance3D
var wires: Array=[]
var keys: Array=[]
var ready_material: StandardMaterial3D
var idle_material: StandardMaterial3D
func _init():
	name="BombKeypad"
	add_child(load("res://deathmatch/pickups/defusal/bomb_chassis.glb").instantiate())
	idle_material=Art.material(Color("e28c53"),1,0);idle_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ready_material=Art.material(Color("8de2ae"),1,0);ready_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	display=label("C4 · SAFE",Vector3(0,.112,.085),.00075,24,Color("9ad9b1"));add_child(display)
	for digit in 10:
		var key:=Node3D.new();key.position=Contact.key_point(digit);add_child(key);keys.append(key)
		var text:=label(str(digit),Vector3(0,0,.001),.0009,28,Color("ebe0c7"));key.add_child(text)
	lamp=Art.box(self,Vector3(.105,.112,.084),Vector3(.011,.025,.008),idle_material)
	for i in 3:
		var wire:=Node3D.new();add_child(wire);wires.append(wire)
		var mat:=Art.material([Color("e58e68"),Color("e5bf5b"),Color("80c3d2")][i],.7)
		var p: Vector3=Contact.WIRES[i]
		segment(wire,p+Vector3(-.021,-.025,-.027),p+Vector3(-.021,0,0),.009,mat)
		segment(wire,p+Vector3(-.021,0,0),p+Vector3(.021,0,0),.009,mat)
		segment(wire,p+Vector3(.021,0,0),p+Vector3(.021,-.025,-.027),.009,mat)
	var tag:=label("ARENA / DE",Vector3(0,-.157,.071),.00042,20,Color("d5c3a1"));add_child(tag)
static func label(text: String,at: Vector3,pixel: float,font_size: int,color: Color) -> Label3D:
	var node:=Label3D.new();node.text=text;node.position=at;node.pixel_size=pixel;node.font_size=font_size;node.modulate=color;node.outline_size=0;node.no_depth_test=false;return node
static func segment(parent: Node3D,a: Vector3,b: Vector3,width: float,material: Material):
	var part:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.height=a.distance_to(b);mesh.top_radius=width*.5;mesh.bottom_radius=width*.5;mesh.radial_segments=6;mesh.rings=1
	part.mesh=mesh;part.material_override=material;part.position=(a+b)*.5
	part.quaternion=Quaternion(Vector3.UP,(b-a).normalized());part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(part)
func update_display(text: String,armed: bool,cuts: int):
	if display.text!=text:display.text=text
	lamp.material_override=ready_material if armed else idle_material
	for i in 3:wires[i].visible=cuts&(1<<i)==0
static func cutters() -> Node3D:
	return load("res://deathmatch/pickups/defusal/cutters.glb").instantiate()
