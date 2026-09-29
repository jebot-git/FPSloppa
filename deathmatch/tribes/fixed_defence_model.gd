extends RefCounted
const Props=preload("res://deathmatch/tribes/prop_library.gd")
static func make(kind: String,team: int) -> Node3D:
	var root=Props.make("fixed_"+kind,team)
	var label:=Label3D.new();label.name="Status";label.font_size=24;label.pixel_size=.012;label.position.y=2.1 if kind=="mini" else 4.0;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;root.add_child(label)
	return root
