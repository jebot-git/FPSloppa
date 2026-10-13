extends RefCounted
const Original=preload("res://deathmatch/avatars/visual_loader.gd")
const Rig=preload("res://tools/ut99_avatar/profile/rig.gd")
static func prepare_avatar(library:Node,hash:String,wait:bool=false) -> bool:return Original.prepare_avatar(library,hash,wait)
static func create_avatar(library:Node,hash:String) -> Node3D:
	if not Original.prepare_avatar(library,hash,true):return null
	var rig:=Rig.new();rig.name="UT99Avatar";rig.avatar_hash=hash
	rig.configure(library.scenes[hash]);library.track_instance(hash,rig);return rig
