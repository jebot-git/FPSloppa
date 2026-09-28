extends RefCounted
## Pinned Tribes 1 base script values. Health uses the existing .66 -> 100 scale.
const KINDS={
	"turret":{"limit":10,"hp":.65,"range":30.0,"reserve":60.0,"size":Vector3(1.0,1.1,1.0)},
	"inventory":{"limit":5,"hp":.25,"range":0.0,"reserve":3000.0,"size":Vector3(1.3,1.5,.8)},
	"ammo_station":{"limit":7,"hp":.25,"range":0.0,"reserve":2500.0,"size":Vector3(1.2,.8,.8)},
	"pulse":{"limit":15,"hp":1.0,"range":200.0,"reserve":0.0,"size":Vector3(.8,1.3,.8)},
	"motion":{"limit":15,"hp":.4,"range":50.0,"reserve":0.0,"size":Vector3(.55,.5,.55)},
	"remote_jammer":{"limit":8,"hp":.5,"range":80.0,"reserve":0.0,"size":Vector3(.8,1.0,.8)},
	"camera":{"limit":15,"hp":.25,"range":50.0,"reserve":0.0,"size":Vector3(.55,.65,.55)}
}
static func is_pack(key: String) -> bool:return KINDS.has(key)
static func allowed(armour: String,key: String) -> bool:
	return armour!="light" or key not in ["turret","inventory","ammo_station"]
static func hp(key: String) -> float:return KINDS[key].hp*100.0/.66
static func eye(row: Dictionary) -> Vector3:
	return frame(row)*Vector3(0,.57,0)+row.aim*.29 if row.kind=="camera" else frame(row)*Vector3(0,KINDS[row.kind].size.y+.08,0)
static func frame(row: Dictionary) -> Transform3D:
	var up: Vector3=row.normal;var forward:=Basis(Vector3.UP,row.yaw)*Vector3.BACK
	forward=forward.slide(up).normalized()
	if forward.length()<.1:forward=Vector3.RIGHT.slide(up).normalized()
	return Transform3D(Basis(up.cross(forward).normalized(),up,forward),row.position)
