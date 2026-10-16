extends "res://tools/voxel_battle/class_arena.gd"
signal test_complete(result:Dictionary)
var started:=Time.get_ticks_msec()
var admitted:=0
var complete:=false
var attempted:=false
func start_join(_name:String,address:String,port:int,spectator:bool=false)->void:
 super.start_join("IO producer" if OS.get_cmdline_user_args().has("--producer") else "IO consumer",address,port,spectator)
func _physics_process(delta:float)->void:
 if complete:return
 super._physics_process(delta)
 var args:=OS.get_cmdline_user_args();var hash_value:=args[args.find("--expected-avatar")+1];var producer:=args.has("--producer")
 if active and admitted==0:admitted=Time.get_ticks_msec()
 var selected:bool=avatars.choices.values().any(func(row):return row.hash==hash_value)
 var known:bool=native_session.catalog.has(hash_value)
 var installed:bool=avatars.library.entries.has(hash_value)
 attempted=attempted or native_session.active
 var passed:bool=active and selected and known and installed
 if producer:passed=passed and admitted>0 and Time.get_ticks_msec()-admitted>35000
 if not passed and Time.get_ticks_msec()-started<90000 and (native_session.active or not attempted):return
 complete=true
 var failures:Array=[]
 if not passed:failures.append("Native avatar upload/download did not complete")
 var path:String=avatars.library.entries.get(hash_value,{}).get("path","")
 if passed and FileAccess.get_sha256(path)!=hash_value:failures.append("Installed bytes differ from requested hash")
 var result:Dictionary={"mode":"producer" if producer else "consumer","failures":failures,"native_services":native_session.services!=null,"selected":selected,"catalog":known,"installed":installed,"bytes":FileAccess.get_file_as_bytes(path).size() if installed else 0,"services":native_session.services.stats() if native_session.services else {},"session":native_session.backend.stats() if native_session.backend else {}}
 print("NATIVE_SERVICES_ARENA_CLIENT ",JSON.stringify(result));test_complete.emit(result)
