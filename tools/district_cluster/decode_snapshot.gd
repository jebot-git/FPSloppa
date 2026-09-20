extends SceneTree
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	var snapshot=bytes_to_var(Marshalls.base64_to_raw(FileAccess.get_file_as_string(args[0])))
	var rows: Array=[]
	for actor in snapshot.actors:
		rows.append({"id":actor.id,"hp":actor.state.hp,"position":[actor.position.x,actor.position.y,actor.position.z],"jetpack":actor.body.jetpack_state,"sequence":actor.state.last_seq,"ammo":actor.state.ammo,"fire":actor.state.fire,"team":actor.state.team})
	print("CLUSTER_DECODE ",JSON.stringify(rows));quit()
