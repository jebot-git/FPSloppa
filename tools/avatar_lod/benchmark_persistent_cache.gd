extends SceneTree
const Library=preload("res://deathmatch/avatars/library.gd")
const OUT="res://test-results/avatar-cache/"
func _initialize():run.call_deferred()
func run():
	var args:=OS.get_cmdline_user_args();var phase:String=args[0] if not args.is_empty() else "load"
	var library=Library.new();root.add_child(library);library.entries.clear()
	var cache=library.runtime_cache();cache.directory="/tmp/fps-avatar-cache-benchmark"
	if "--cache-dir" in args:cache.directory=args[args.find("--cache-dir")+1]
	var rows:=[]
	for sample in ["sample_d","sample_f","sample_g","sakurada_fumiriya"]:
		var path:String="res://vrm/"+sample+".vrm";var hash:=FileAccess.get_sha256(path)
		library.entries[hash]={"path":path}
		var begin:=Time.get_ticks_usec();var max_call:=0.0;var calls:=0
		while true:
			var call_begin:=Time.get_ticks_usec();var ready:bool=library.prepare_avatar(hash)
			max_call=maxf(max_call,(Time.get_ticks_usec()-call_begin)/1000.0);calls+=1
			if ready:break
			assert(library.last_error.is_empty(),library.last_error)
			await process_frame
		var prepared:=Time.get_ticks_usec();var rig=library.create_avatar(hash);assert(rig)
		var instantiated:=Time.get_ticks_usec()
		var actor:=Node3D.new();root.add_child(actor);actor.add_child(rig)
		var chains:=0
		for secondary in rig.secondary_nodes:chains+=secondary.spring_chain_count()
		var row={"sample":sample,"prepare_wall_ms":(prepared-begin)/1000.0,"max_prepare_call_ms":max_call,"prepare_calls":calls,"instantiate_configure_ms":(instantiated-prepared)/1000.0,"bones":rig.skeleton.get_bone_count(),"chains":chains,"mouth":rig.mouth.binds.size(),"eyes":rig.eyes.channels.size(),"scale":rig.scale_factor,"cache":cache.stats.duplicate()}
		var reuse_start:=Time.get_ticks_usec();var second=library.create_avatar(hash);row.memory_reuse_ms=(Time.get_ticks_usec()-reuse_start)/1000.0;second.free()
		while cache.writer.is_started():await process_frame
		row.cache=cache.stats.duplicate();rows.append(row);actor.free()
		print("AVATAR_CACHE_ROW ",JSON.stringify(row))
	FileAccess.open(OUT+phase+".json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	library.free()
	for i in 10:await process_frame
	quit()
