extends SceneTree
const OUT="res://test-results/vrm-optimization/"
const Rig=preload("res://deathmatch/avatars/rig.gd")
func _initialize():run.call_deferred()
func run():
	var build:=OS.get_cmdline_user_args().has("--build")
	var library=preload("res://deathmatch/avatars/library.gd").new()
	var rows:=[]
	for sample in ["sample_d","sample_f","sample_g","sakurada_fumiriya"]:
		var path: String=OUT+sample+"-runtime.scn"
		if build:
			library.entries[sample]={"path":"res://vrm/"+sample+".vrm"}
			var start:=Time.get_ticks_usec();var rig=library.create_avatar(sample);assert(rig)
			var converted:=Time.get_ticks_usec()
			assert(ResourceSaver.save(library.scenes[sample],path,ResourceSaver.FLAG_COMPRESS)==OK)
			rows.append({"sample":sample,"conversion_ms":(converted-start)/1000.0,"save_ms":(Time.get_ticks_usec()-converted)/1000.0,"bytes":FileAccess.open(path,FileAccess.READ).get_length()});rig.free()
		else:
			var start:=Time.get_ticks_usec();var packed=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE);assert(packed)
			var model=packed.instantiate();var rig:=Rig.new();rig.add_child(model);assert(rig.configure(model))
			var elapsed:=(Time.get_ticks_usec()-start)/1000.0
			var actor:=Node3D.new();root.add_child(actor);actor.add_child(rig);rig.preview_mode=0
			var chains:=0
			for secondary in rig.secondary_nodes:chains+=secondary.spring_chain_count()
			rows.append({"sample":sample,"load_configure_ms":elapsed,"bones":rig.skeleton.get_bone_count(),"spring_chains":chains,"mouth_channels":rig.mouth.binds.size(),"face_channels":rig.eyes.channels.size()});actor.free()
	FileAccess.open(OUT+("cache-build.json" if build else "cache-load.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("RUNTIME_CACHE_BENCHMARK ",JSON.stringify(rows));library.free();quit()
