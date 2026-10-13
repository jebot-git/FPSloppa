extends RefCounted
## UT99 preparation: one decoded mesh/atlas and shared frame texture per source.
var report:={"enabled":true,"format":"UT99 vertex","springs_enabled":false,"prepared_models":[],"avatars":0,"preparation_ms":0.0}
func prepare(game) -> bool:
	if game.headless:report.rendering_skipped=true;return true
	var before:=Time.get_ticks_usec()
	game.avatars.set_process(false);game.avatars.load_queue.clear()
	var library=game.avatars.library
	var hashes:Dictionary={}
	for choice in game.avatars.choices.values():hashes[choice.hash]=true
	for hash in hashes:
		if not library.prepare_avatar(hash):push_error(library.last_error);return false
		report.prepared_models.append({"hash":hash,"surfaces":1,"shared_vertex_animation":true})
	for id in game.players:
		var hash:String=game.avatars.choices[id].hash
		var rig=library.create_avatar(hash)
		if rig==null:push_error(library.last_error);return false
		game.fighters[id].set_avatar(rig,hash);report.avatars+=1
	report.preparation_ms=(Time.get_ticks_usec()-before)/1000.0
	return true
