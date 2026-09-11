extends Node
## One serial disk worker per transfer service. Only immutable job inputs cross
## threads; callbacks, RPCs and scene changes are delivered on the main thread.
const MAX_PENDING:=256
var thread:=Thread.new()
class Queue extends RefCounted:
	var mutex:=Mutex.new()
	var wake:=Semaphore.new()
	var jobs: Array=[]
	var results: Array=[]
	var pending:=0
	var stopping:=false
	func run() -> void:
		while true:
			wake.wait();mutex.lock()
			if jobs.is_empty():
				var done:=stopping
				mutex.unlock()
				if done:return
				continue
			var job: Array=jobs.pop_front()
			mutex.unlock()
			var result=job[0].call()
			mutex.lock();results.append([job[1],result]);mutex.unlock()
var state:=Queue.new()
var started:=false
var temporary: Dictionary={}
var deleting: Dictionary={}

func submit(work: Callable,complete: Callable=Callable()) -> bool:
	if not started:
		if thread.start(state.run)!=OK:return false
		started=true
	state.mutex.lock()
	if state.stopping or state.pending>=MAX_PENDING:
		state.mutex.unlock();return false
	state.jobs.append([work,complete]);state.pending+=1
	state.mutex.unlock();state.wake.post()
	return true

func track(path: String) -> void:temporary[path]=true
func discard(path: String) -> void:
	# Serialized behind any writes already accepted for this unique temp path.
	if submit(remove.bind(path)):temporary.erase(path);deleting.erase(path)
	else:deleting[path]=true

func _process(_delta: float) -> void:
	for path in deleting.keys():discard(path)
	# Bound completion work per frame as well as queued I/O memory.
	for i in range(32):
		state.mutex.lock()
		if state.results.is_empty():state.mutex.unlock();break
		var result: Array=state.results.pop_front();state.pending-=1
		state.mutex.unlock()
		if result[0].is_valid():result[0].call(result[1])

func _exit_tree() -> void:
	if not started:return
	# Only shutdown waits. During play all disk operations remain asynchronous.
	state.mutex.lock();state.stopping=true;state.mutex.unlock();state.wake.post()
	thread.wait_to_finish()
	for path in temporary:remove(path)
	state.jobs.clear();state.results.clear();temporary.clear();deleting.clear();state.pending=0

static func remove(path: String) -> Error:
	return DirAccess.remove_absolute(path) if FileAccess.file_exists(path) else OK
static func size(path: String) -> int:
	var file:=FileAccess.open(path,FileAccess.READ)
	return file.get_length() if file else -1
static func read(path: String,offset: int,count: int,total: int) -> PackedByteArray:
	var file:=FileAccess.open(path,FileAccess.READ)
	if not file or file.get_length()!=total:return PackedByteArray()
	file.seek(offset)
	return file.get_buffer(count)
static func write(path: String,offset: int,bytes: PackedByteArray) -> Error:
	if offset==0:DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file:=FileAccess.open(path,FileAccess.WRITE if offset==0 else FileAccess.READ_WRITE)
	if not file:return FileAccess.get_open_error()
	if file.get_length()!=offset:return ERR_FILE_CORRUPT
	file.seek(offset);file.store_buffer(bytes)
	var error:=file.get_error();file.close()
	return error
static func text_file(path: String,value: String) -> Error:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if not file:return FileAccess.get_open_error()
	file.store_string(value)
	return file.get_error()
