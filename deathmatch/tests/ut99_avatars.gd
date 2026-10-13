extends SceneTree
const Library=preload("res://deathmatch/avatars/library.gd")
const Format=preload("res://deathmatch/avatars/ut_format.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
const Jobs=preload("res://deathmatch/network/asset_jobs.gd")
var checks:=0
var failures:Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run() -> void:
	var library:=Library.new();root.add_child(library)
	check(library.entries.size()>=7,"World Leaders faces available as default selections")
	for hash in library.entries:
		var info:Dictionary=library.entries[hash]
		var data:=Format.read(info.path)
		check(not data.has("error"),"Container validation: "+info.title)
		if data.has("error"):continue
		check(data.manifest.vertices==info.vertices and data.manifest.frames==info.frames and data.manifest.corners.size()==info.triangles*3,"Original geometry and every animation frame retained")
		var raw:PackedByteArray=data.positions;var reference:int=data.manifest.reference;var min_y:=100.0;var max_y:=-100.0
		for v in int(data.manifest.vertices):
			var y:=raw.decode_float((reference*int(data.manifest.vertices)+v)*16+4);min_y=minf(min_y,y);max_y=maxf(max_y,y)
		check(absf(max_y-min_y-1.7)<.0001 and absf(min_y)<.0001,"Reference frame scaled to 170 cm, grounded")
		var first=library.create_avatar(hash);var second=library.create_avatar(hash)
		check(first!=null and second!=null,"UT99 render rig loads")
		if first==null or second==null:continue
		root.add_child(first);root.add_child(second)
		check(first.visual.mesh==second.visual.mesh,"Instances share mesh, skin and animation GPU resources")
		first.preview_mode=2;second.preview_mode=3;first._process(.12);second._process(.12)
		check(first.clip_name.begins_with("Run") and second.clip_name.begins_with("StillFr"),"Run and shooting select distinct original clips")
		first.selected_sequence="Taunt1";first._process(.08)
		check(first.clip_name=="Taunt1","Original sequence selection")
		first.dead=true;first.selected_sequence="";first._process(10)
		check(first.clip_name.begins_with("Dead"),"Death sequence selected without looping")
		first.free();second.free()
		var received:=Jobs.model_file(info.path,hash,ProjectSettings.globalize_path("user://ut99_test/"))
		check(not received.has("error") and received.path.ends_with(".utavatar"),"SHA-verified network cache publication")
	var neutral:=Poses.neutral()
	check(not Poses.validate(neutral).is_empty(),"Headset and controller poses remain supported")
	for channel in ["body","face"]:
		var pose:=neutral.duplicate();pose[channel]={}
		check(Poses.validate(pose).is_empty(),"Removed tracking channel rejected: "+channel)
	var bytes:=FileAccess.get_file_as_bytes(library.entries[library.selected].path)
	var path:="user://bad.utavatar";var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes.slice(0,32));file.close()
	check(Format.inspect(path).has("error"),"Truncated container rejected")
	bytes[0]=0;file=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
	check(Format.inspect(path).has("error"),"Foreign/VRM container rejected")
	library.free()
	print("UT99_AVATARS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
