extends SceneTree
const IO=preload("res://deathmatch/network/disk_worker.gd")
const Jobs=preload("res://deathmatch/network/asset_jobs.gd")
var failures: Array=[]
var completed: Array=[]
var frames:=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
static func slow_job() -> bool:
	OS.delay_msec(250)
	return not Thread.is_main_thread()
func wait_count(count: int) -> bool:
	var deadline:=Time.get_ticks_msec()+10000
	while completed.size()<count and Time.get_ticks_msec()<deadline:
		await process_frame;frames+=1
	return completed.size()==count
func run() -> void:
	Engine.max_fps=144
	var disk:=IO.new();root.add_child(disk)
	var path:="/tmp/fpsloppa-thread-%d.part"%OS.get_process_id()
	disk.track(path)
	disk.submit(slow_job,func(result):completed.append(result and Thread.is_main_thread()))
	await wait_count(1)
	check(completed[0] and frames>15,"Slow work uses a worker while frames and main-thread completion continue")
	completed.clear()
	var data:=PackedByteArray();data.resize(32768);data.fill(73)
	for i in range(32):
		disk.submit(IO.write.bind(path,i*data.size(),data),func(error):completed.append(error))
	await wait_count(32)
	check(completed.size()==32 and completed.all(func(error):return error==OK),"Queued chunk writes preserve order without sharing file handles")
	completed.clear()
	disk.submit(IO.read.bind(path,32768,262144,1048576),func(bytes):completed.append(bytes))
	await wait_count(1)
	var expected:=PackedByteArray();expected.resize(262144);expected.fill(73)
	check(completed[0]==expected,"Background range reads return the exact requested bytes")
	completed.clear()
	disk.submit(IO.write.bind(path,0,data),func(error):completed.append(error))
	disk.discard(path)
	disk.submit(IO.size.bind(path),func(size):completed.append(size))
	await wait_count(2)
	check(completed[1]==-1,"Cancellation cleanup runs after pending writes and removes partial files")
	completed.clear()
	disk.submit(slow_job,func(result):completed.append(result))
	for i in IO.MAX_PENDING-1:disk.submit(func():return true,func(result):completed.append(result))
	check(not disk.submit(slow_job),"Backpressure bounds pending jobs instead of growing an unbounded queue")
	await wait_count(IO.MAX_PENDING)
	check(completed.size()==IO.MAX_PENDING,"Bounded queue drains without losing completions")
	completed.clear()
	disk.submit(Jobs.model_file.bind("res://vrm/sample_f.vrm","0".repeat(64),"/tmp/"),func(result):completed.append(result))
	disk.submit(Jobs.map_file.bind("res://maps/lqdm2.bsp","0".repeat(64),"Bad","/tmp/"),func(result):completed.append(result))
	await wait_count(2)
	check(completed.all(func(result):return result.has("error")),"Corrupt map and model identities are rejected before cache installation")
	var thread: Thread=disk.thread
	disk.free()
	check(not thread.is_started(),"Service teardown joins its worker; no orphan thread remains")
	print("THREADED_IO_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
