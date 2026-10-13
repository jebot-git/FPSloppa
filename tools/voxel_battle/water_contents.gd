extends "res://deathmatch/maps/contents.gd"
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
func at(point:Vector3) -> int:
 if not point.is_finite():return -1
 return -3 if Landscape.in_water(point) else -1

func water_level(point:Vector3) -> float:return Landscape.water_sample(point.x,point.z).y
