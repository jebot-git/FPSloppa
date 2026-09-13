extends SceneTree
## Opt-in X40 hardware suite. Requires the exact selected BlueZ ID after --.
## About four minutes, 25% intensity, no more than four motors active at once.
const Native=preload("res://deathmatch/haptics/native.gd")
const X40_FRONT=[31,30,1,0,33,32,3,2,35,34,5,4,37,36,7,6,39,38,9,8]
const X40_BACK=[10,11,20,21,12,13,22,23,14,15,24,25,16,17,26,27,18,19,28,29]
var output: RefCounted
var failures: Array=[]
var stages: Array=[]
var started:=0
var report_path:="res://test-results/bhaptics-soak.json"
var latencies: Array[float]=[]
func _initialize() -> void:call_deferred("run")
func stats() -> Dictionary:return JSON.parse_string(output.bridge.diagnostics_json())
func check(ok: bool,label: String) -> bool:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
	return ok
func healthy() -> bool:
	return output.bridge.device_connected() and output.bridge.is_running() and stats().write_errors==0
func frame(indices: Array) -> PackedByteArray:
	var values:=PackedByteArray();values.resize(40)
	for index in indices:values[index]=1
	return values
func expected(indices: Array) -> Array:
	# JSON.parse_string returns floats; match that representation for Array equality.
	var values: Array=[];values.resize(40);values.fill(0.0)
	for index in indices:values[X40_FRONT[index] if index<20 else X40_BACK[index-20]]=4.0
	return values
func wait_written(indices: Array,timeout_ms: int=250) -> bool:
	var begin:=Time.get_ticks_msec()
	var wanted:=expected(indices)
	while Time.get_ticks_msec()-begin<timeout_ms:
		if not healthy():return false
		if stats().last_frame==wanted:return true
		await process_frame
	return false
func send_checked(indices: Array) -> bool:
	var begin:=Time.get_ticks_usec()
	if not output.bridge.submit_frame(frame(indices),.25):return false
	if not await wait_written(indices):return false
	latencies.append((Time.get_ticks_usec()-begin)/1000.0)
	return true
func pause(seconds: float) -> void:
	if seconds>0:await create_timer(seconds).timeout
func mark(label: String,extra: Dictionary={}) -> void:
	var record: Dictionary={"stage":label,"elapsed_seconds":(Time.get_ticks_msec()-started)/1000.0,"diagnostics":stats()}
	record.merge(extra);stages.append(record)
	print("STAGE ",label," elapsed=",record.elapsed_seconds," writes=",record.diagnostics.writes," changes=",record.diagnostics.frame_changes)
func idle(seconds: float) -> bool:
	var begin:=Time.get_ticks_msec()
	var before:=stats()
	var last_writes: int=int(before.writes)
	var last_progress:=begin
	var next_notice:=begin+30000
	while (Time.get_ticks_msec()-begin)/1000.0<seconds:
		await pause(.1)
		if not healthy():return false
		var current:=stats()
		if current.last_active_motors!=0 or current.active_writes!=before.active_writes:return false
		if int(current.writes)>last_writes:last_writes=int(current.writes);last_progress=Time.get_ticks_msec()
		if Time.get_ticks_msec()-last_progress>1000:return false
		if Time.get_ticks_msec()>=next_notice:mark("idle heartbeat");next_notice+=30000
	return true
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1:push_error("Pass one exact X40 Bluetooth ID after --");quit(2);return
	started=Time.get_ticks_msec();output=Native.new()
	if not check(output.open("",0)==OK,"Native extension loads"):await finish();return
	output.scan()
	var begin:=Time.get_ticks_msec()
	while output.status_text().begins_with("Scanning") and Time.get_ticks_msec()-begin<12000:await process_frame
	var selected:=""
	for device in output.devices():
		if str(device.id)==args[0] and str(device.name)=="TactSuitX40":selected=str(device.id)
	if not check(not selected.is_empty(),"Explicitly selected X40 discovered"):await finish();return
	if not check(output.connect_device(selected),"Connection requested"):await finish();return
	begin=Time.get_ticks_msec()
	while output.status_text().begins_with("Connecting") and Time.get_ticks_msec()-begin<10000:await process_frame
	if not check(healthy(),"Connected: "+output.status_text()):await finish();return
	mark("connected")
	print("TEST all 40 motors individually, 100 ms per motor, 25%")
	for index in 40:
		begin=Time.get_ticks_msec()
		if not check(await send_checked([index]),"Motor %d mapped frame written"%index):await finish();return
		await pause(maxf(0,.1-(Time.get_ticks_msec()-begin)/1000.0))
	check(int(stats().motor_mask)==(1<<40)-1,"All 40 physical motor channels exercised at the host")
	output.stop();await wait_written([]);mark("all motors")
	print("TEST 60 seconds of alternating four-motor patterns, 10 updates/second")
	var patterns: Array=[[0,1,4,5],[2,3,6,7],[20,21,24,25],[22,23,26,27]]
	var before:=stats()
	begin=Time.get_ticks_msec()
	for index in 600:
		var tick:=Time.get_ticks_msec()
		if not await send_checked(patterns[index%patterns.size()]):
			check(false,"Rapid pattern %d was not written promptly: %s"%[index,output.status_text()]);await finish();return
		await pause(maxf(0,.1-(Time.get_ticks_msec()-tick)/1000.0))
		if index%150==149:mark("rapid progress",{"patterns_completed":index+1})
	check(stats().frame_changes-before.frame_changes>=600,"All 600 rapid pattern transitions written")
	mark("rapid complete",{"patterns":600,"seconds":(Time.get_ticks_msec()-begin)/1000.0})
	output.stop()
	if not check(await wait_written([]),"Stop clears all motors before idle"):await finish();return
	print("TEST 120 seconds idle with no Godot frame submissions; native zero heartbeat continues")
	if not check(await idle(120),"Connection and zero writes persist throughout two-minute idle"):await finish();return
	mark("idle complete")
	if not check(await send_checked([5,6,9,10]),"Chest pulse resumes on the same connection after idle"):await finish();return
	output.stop();await wait_written([])
	print("TEST 10 seconds producing frames at approximately 100 Hz; latest frame replaces old input")
	before=stats();begin=Time.get_ticks_msec()
	var submitted:=0
	while Time.get_ticks_msec()-begin<10000:
		if not output.bridge.submit_frame(frame(patterns[submitted%4]),.25) or not healthy():
			check(false,"Overload input lost connection");await finish();return
		submitted+=1;await pause(.01)
	var overloaded:=stats()
	check(overloaded.writes>before.writes+50 and overloaded.writes<before.writes+250,"Bluetooth writes remain bounded during faster producer input")
	check(overloaded.frame_changes>before.frame_changes+30,"Motor patterns continue changing during producer overload")
	if not check(await send_checked([16]),"Final frame takes effect without a stale command backlog"):await finish();return
	output.stop()
	begin=Time.get_ticks_msec()
	check(await wait_written([]),"Stop takes effect promptly after overload")
	mark("overload complete",{"submitted_frames":submitted,"stop_ms":Time.get_ticks_msec()-begin})
	print("TEST producer stall and 200 ms watchdog")
	if not check(await send_checked([25,26]),"Back pulse written before producer stall"):await finish();return
	begin=Time.get_ticks_msec()
	check(await wait_written([],500),"Watchdog releases motors with no new producer frame")
	mark("watchdog complete",{"observed_zero_after_ms":Time.get_ticks_msec()-begin})
	check(await idle(5),"No stale pulse returns after watchdog stop")
	check(stats().connections==1 and stats().write_errors==0,"One uninterrupted connection and no Bluetooth write errors across the suite")
	await finish()
func finish() -> void:
	var final_stats: Dictionary={}
	var status:="Extension unavailable"
	if output and output.bridge:
		output.stop();final_stats=stats();status=output.status_text();output.close()
		var begin:=Time.get_ticks_msec()
		while output.bridge.is_running() and Time.get_ticks_msec()-begin<5000:await process_frame
		check(not output.bridge.is_running() and not output.bridge.device_connected(),"Clean shutdown releases session and worker")
	latencies.sort()
	var timing: Dictionary={}
	if not latencies.is_empty():timing={"samples":latencies.size(),"median":latencies[latencies.size()/2],"p95":latencies[int(latencies.size()*.95)],"maximum":latencies[-1]}
	var report: Dictionary={"date":Time.get_datetime_string_from_system(),"model":"TactSuitX40","intensity":.25,"seconds":(Time.get_ticks_msec()-started)/1000.0,"failures":failures,"stages":stages,"final_diagnostics":final_stats,"status_before_close":status,"submit_to_host_write_ms":timing,"measurement_note":"Host writes use BLE write-without-response. Physical sensation and motor timing need wearer confirmation."}
	var file:=FileAccess.open(report_path,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	else:check(false,"Could not save hardware report")
	print("BHAPTICS_SOAK_RESULT ",JSON.stringify(report))
	output=null;quit(0 if failures.is_empty() else 1)
