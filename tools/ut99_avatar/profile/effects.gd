extends "res://deathmatch/experimental/visuals.gd"
const Meter=preload("res://tools/ut99_avatar/profile/meter.gd")
func _process(delta:float) -> void:
	var stamp:=Meter.begin("effects_update");super._process(delta);Meter.end("effects_update",stamp)
func impacts(rules:String,start:Vector3,ends:PackedVector3Array,weapon:int,definition:Dictionary={}) -> void:
	var stamp:=Meter.begin("effects_impacts");super.impacts(rules,start,ends,weapon,definition);Meter.end("effects_impacts",stamp)
func shape(mesh:Mesh,pos:Vector3,color:Color,life:float,start:float=1,end:float=1) -> MeshInstance3D:
	var stamp:=Meter.begin("effects_impacts");var node:=super.shape(mesh,pos,color,life,start,end);Meter.end("effects_impacts",stamp);return node
func _acquire_shape() -> Dictionary:
	var stamp:=Meter.begin("effects_pool_acquire");var item:=super._acquire_shape();Meter.end("effects_pool_acquire",stamp);return item
func _activate_shape(item:Dictionary,mesh:Mesh,pos:Vector3,color:Color,life:float,start:float,end:float,base_basis:Basis=Basis.IDENTITY) -> MeshInstance3D:
	var stamp:=Meter.begin("effects_spawn");var node:=super._activate_shape(item,mesh,pos,color,life,start,end,base_basis);Meter.end("effects_spawn",stamp);return node
