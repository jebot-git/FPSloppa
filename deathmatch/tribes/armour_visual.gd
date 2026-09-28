extends Node3D
## Visual armour only. Collision and hit detection keep the established avatar body.
const Models=preload("res://deathmatch/tribes/models.gd")
var armour: Node3D
var replacement=preload("res://deathmatch/tribes/body_replacement.gd").new()
var pack: Node3D
var exhaust: Node3D
var key:=""
func _ready():get_parent().add_child.call_deferred(replacement)
func _exit_tree():
	if is_instance_valid(replacement):replacement.queue_free()
func configure(armour_key: String,pack_key: String,team: int=0):
	var next: String=armour_key+":"+pack_key+str(team)
	if key==next:return
	key=next
	for child in get_children():child.free()
	armour=null
	pack=preload("res://deathmatch/tribes/deployable_model.gd").make(pack_key,team,true) if preload("res://deathmatch/tribes/deployable_data.gd").is_pack(pack_key) else Node3D.new() if pack_key=="none" else Models.model(pack_key+"_pack");pack.position=Vector3(0,-.015,.29);add_child(pack)
	# Reuse the existing twin-jet exhaust mesh, without its old backpack shell.
	var jets=preload("res://deathmatch/pickups/jetpack_model.gd").new()
	exhaust=jets.exhaust;exhaust.reparent(self,false);exhaust.position=pack.position;jets.free()
func update(actor):
	configure(actor.tribes_state.armour,actor.tribes_state.pack,actor.get_parent().players.get(actor.peer_id,{}).get("team",0))
	if replacement.is_inside_tree():replacement.update(actor)
	visible=actor.alive_state and not actor.spectator and not actor.gibbed and not actor.local_player
	if not visible:return # First-person chest/head mask includes these added shells.
	var pose:=Transform3D(Basis(Vector3.RIGHT,-deg_to_rad(77) if actor.stance=="prone" else 0.0),Vector3(0,actor.torso_height(),0))
	var upper=actor.avatar.get_node_or_null("Upper") if is_instance_valid(actor.avatar) else null
	if upper:pose=actor.avatar.transform*upper.transform*Transform3D(Basis.IDENTITY,Vector3(0,.30,0))
	elif not actor.xr_pose.is_empty():
		pose=preload("res://deathmatch/vr/hip_mount.gd").chest(actor.xr_pose)
	elif is_instance_valid(actor.avatar) and actor.avatar.get("skeleton") is Skeleton3D:
		pose=avatar_chest(actor)
	transform=pose
	exhaust.visible=actor.tribes_state.jetting

static func avatar_chest(actor) -> Transform3D:
	var sk: Skeleton3D=actor.avatar.skeleton;var bone:=sk.find_bone("Chest")
	if bone<0:return Transform3D(Basis.IDENTITY,Vector3(0,actor.torso_height(),0))
	var pose:=sk.get_bone_global_pose(bone)
	# VRM imports can face +Z within a rotated model root. Equipment is authored
	# in the avatar's -Z-forward frame, not in the imported chest bone's axes.
	# Keep animated chest rotation relative to its rest, then align that rest
	# frame with the avatar so the backpack offset points behind the wearer.
	var reference: Basis=sk.global_basis.orthonormalized().inverse()*actor.avatar.global_basis.orthonormalized()
	pose.basis=pose.basis*sk.get_bone_global_rest(bone).basis.inverse()*reference
	return actor.global_transform.affine_inverse()*sk.global_transform*pose
