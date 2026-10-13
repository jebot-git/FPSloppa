extends SceneTree
const Reader=preload("res://quake_mdl.gd")
func _initialize() -> void:
	var directory:=OS.get_cmdline_user_args()[0]
	var report: Array=[];var failures: Array=[]
	for file in DirAccess.get_files_at(directory):
		if not file.ends_with(".mdl"):continue
		var reader:=Reader.new();var model:=reader.parse(directory.path_join(file))
		if model.has("error"):failures.append(file+": "+model.error);continue
		if model.vertices>1024 or model.faces>2048 or model.frames.size()!=40:failures.append(file+": budget/frame count")
		for i in model.frames.size():
			var decoded: Dictionary=Reader.read(directory.path_join(file),i,1.7,0)
			if decoded.has("error"):failures.append(file+": "+decoded.error)
			for v in model.vertices:
				if reader.data[model.frames[i].offset+v*4+3]>=162:failures.append(file+": invalid normal index")
		report.append({"file":file,"vertices":model.vertices,"triangles":model.faces,"frames":model.frames.size()})
	if report.size()!=11:failures.append("Expected all 11 main bundle avatars")
	FileAccess.open(directory.path_join("validation.json"),FileAccess.WRITE).store_string(JSON.stringify({"models":report,"failures":failures,"reader":"existing MDLAvatarConverter Quake IDPO v6 parser","decoded_frames":report.size()*40},"  "))
	print("MDL_VALIDATION ",JSON.stringify({"models":report.size(),"frames":report.size()*40,"failures":failures}));quit(0 if failures.is_empty() else 1)
