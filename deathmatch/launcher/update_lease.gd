extends Node
## Lives under SceneTree.root so switching scenes does not release the lease.
var path:=""
func register(root: String) -> bool:
	var folder:=root.path_join(".launcher-processes")
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:return false
	path=folder.path_join(str(OS.get_process_id()))
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if not file:return false
	file.store_string("FPSloppa");file.close();return true
func _exit_tree() -> void:
	if not path.is_empty():DirAccess.remove_absolute(path)
static func active(root: String) -> Array:
	var result: Array=[];var folder:=root.path_join(".launcher-processes")
	if not DirAccess.dir_exists_absolute(folder):return result
	for name in DirAccess.get_files_at(folder):
		if not name.is_valid_int():continue
		var pid:=int(name)
		if pid>0 and alive(pid):result.append(pid)
		else:DirAccess.remove_absolute(folder.path_join(name))
	return result

static func alive(pid: int) -> bool:
	if pid<=0:return false
	# Godot 4.7 OS.is_process_running only knows children of the caller.
	# The installer must also observe its parent and sibling game processes.
	if OS.get_name()=="Linux":
		var path:="/proc/"+str(pid)+"/stat"
		if not FileAccess.file_exists(path):return false
		var file:=FileAccess.open(path,FileAccess.READ)
		if not file:return FileAccess.file_exists(path)
		var value:=file.get_line()
		if value.is_empty():return true
		var end:=value.rfind(")")
		return end<0 or not value.substr(end+2,1) in ["Z","X"]
	if OS.get_name()=="Windows":
		var output: Array=[]
		var windows:=OS.get_environment("SystemRoot")
		if windows.is_empty():windows="C:/Windows"
		var code:=OS.execute(windows.path_join("System32/tasklist.exe"),PackedStringArray(["/FI","PID eq "+str(pid),"/FO","CSV","/NH"]),output,false)
		if code!=0:return true # A failed probe must never authorize replacement.
		for chunk in output:
			for line in str(chunk).split("\n"):
				var columns:=line.split(",")
				if columns.size()>1 and columns[1].strip_edges().trim_prefix('"').trim_suffix('"')==str(pid):return true
		return false
	return true
