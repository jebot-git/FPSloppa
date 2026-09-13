extends SceneTree
const Jobs=preload("res://deathmatch/network/asset_jobs.gd")
var failed:=false
func _initialize() -> void:call_deferred("run")
static func write_many(source: String,destination: String,hash: String) -> bool:
	for i in 120:
		if Jobs.publish(source,destination,hash)!=OK:return false
		OS.delay_usec(100)
	return true
func run() -> void:
	var directory:="/tmp/fpsloppa-atomic-assets-%d/"%OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var hashes: Array[String]=[]
	for index in 2:
		var bytes:=PackedByteArray();bytes.resize(262144);bytes.fill(41+index)
		var file:=FileAccess.open(directory+str(index),FileAccess.WRITE);file.store_buffer(bytes);file.close()
		hashes.append(FileAccess.get_sha256(directory+str(index)))
	var destination:=directory+"shared.vrm"
	failed=Jobs.publish(directory+"0",destination,hashes[0])!=OK
	var writers: Array[Thread]=[]
	for index in 2:
		var thread:=Thread.new();thread.start(write_many.bind(directory+str(index),destination,hashes[index]));writers.append(thread)
	var reads:=0
	while writers[0].is_alive() or writers[1].is_alive():
		if not FileAccess.get_sha256(destination) in hashes:failed=true
		reads+=1
		await process_frame
	for thread in writers:
		if not thread.wait_to_finish():failed=true
	if reads==0:failed=true
	var leftovers:=DirAccess.get_files_at(directory)
	if leftovers.size()!=3:failed=true
	for filename in leftovers:DirAccess.remove_absolute(directory+filename)
	DirAccess.remove_absolute(directory)
	print("FAIL " if failed else "PASS ","Concurrent verified asset publication exposes complete files only; reads=",reads)
	quit(1 if failed else 0)
