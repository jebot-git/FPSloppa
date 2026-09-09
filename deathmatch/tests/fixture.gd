extends RefCounted
## Isolated synthetic physics fixture, never included in a playable map.
const ORIGIN=Vector3(1000,10,1000)
static func point(x: float=0,z: float=0) -> Vector3: return ORIGIN+Vector3(x,0,z)
static func setup(game: Node3D) -> void:
	box(game,ORIGIN+Vector3(0,-.5,0),Vector3(40,1,40))
	box(game,ORIGIN+Vector3(10,1.5,0),Vector3(.25,3,8))
	if game.gates.is_empty():
		var gate:=box(game,ORIGIN+Vector3(16,1.5,0),Vector3(1,3,1))
		game.gates.append({"node":gate,"base":gate.position.y,"open":false,"until":0.0})
static func box(parent: Node,position: Vector3,size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new();body.position=position
	var shape:=CollisionShape3D.new();var box_shape:=BoxShape3D.new();box_shape.size=size;shape.shape=box_shape
	body.add_child(shape);parent.add_child(body);return body
