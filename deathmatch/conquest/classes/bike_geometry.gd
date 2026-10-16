extends RefCounted
## Authored Desert Bike sockets; shared with native geometry generation.
static var manifest:Dictionary={}
static func data()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/models/desert_bike/manifest.json"))
 return manifest
static func point(key:String)->Vector3:
 var p:Array=data()[key];return Vector3(p[0],p[1],p[2])
static func steering_mount()->Transform3D:return Transform3D(Basis.IDENTITY,point("steering_pivot"))
static func grip(side:int)->Vector3:
 var p:Array=data().grips[side];return Vector3(p[0],p[1],p[2])
