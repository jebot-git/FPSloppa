extends SceneTree
var failures: Array=[]
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.dedicated=true;g.set_physics_process(false)
	var path:="/tmp/entryway-server-log-test-"+str(OS.get_process_id())+".jsonl"
	var log=g.server_log
	check(log.setup(g,{"sv_log_level":"verbose","sv_log_file":path,"sv_log_max_mb":1,"sv_log_backups":2}),"Verbose server log opens")
	log.max_bytes=600
	for i in range(20):log.record("test",{"peer":i,"safe_text":"line\nbreak"},2)
	check(FileAccess.file_exists(path+".1") and FileAccess.file_exists(path+".2") and not FileAccess.file_exists(path+".3"),"Log rotation retains bounded backups")
	log.file.flush()
	var text:=FileAccess.get_file_as_string(path+".1");var valid:=true
	for line in text.split("\n",false):
		var event=JSON.parse_string(line);valid=valid and event is Dictionary and event.has("utc") and event.has("seq") and event.event=="test"
	check(valid,"JSONL records remain valid with escaped untrusted names and text")
	log.setup(g,{"sv_log_level":"normal","sv_log_file":path});var before:int=log.file.get_position();log.record("verbose_ignored",{},2)
	check(log.file.get_position()==before,"Normal logging excludes verbose events")
	log.setup(g,{"sv_log_level":"off","sv_log_file":path});check(log.file==null,"Off mode closes optional log file")
	const Config=preload("res://deathmatch/server/config.gd")
	for value in ['set sv_log_level "trace"','set sv_log_max_mb "0"','set sv_log_backups "10"']:check(Config.parse(value).has("error"),"Invalid logging option rejected: "+value)
	for suffix in ["",".1",".2"]:DirAccess.remove_absolute(path+suffix)
	print("SERVER_LOGGING_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
