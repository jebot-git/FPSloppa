extends SceneTree
## Opt-in hardware test: requires an explicitly selected Bluetooth ID after --.
## Sends one short chest pulse at 25%, then tests watchdog and explicit stop.
const Native=preload("res://deathmatch/haptics/native.gd")
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1:
		push_error("Hardware test requires one explicitly selected Bluetooth device ID after --");quit(2);return
	var output:=Native.new()
	check(output.open("",0)==OK,"Native extension loads")
	if not output.bridge:quit(1);return
	output.scan()
	var started:=Time.get_ticks_msec()
	while output.status_text().begins_with("Scanning") and Time.get_ticks_msec()-started<12000:await process_frame
	print("DISCOVERY ",output.status_text()," ",JSON.stringify(output.devices()))
	var selected:=""
	for device in output.devices():
		if str(device.id).to_upper()==args[0].to_upper():selected=str(device.id)
	check(not selected.is_empty(),"Explicit target discovered")
	if not selected.is_empty():
		check(output.connect_device(selected),"Explicit target connection requested")
		started=Time.get_ticks_msec()
		while output.status_text().begins_with("Connecting") and Time.get_ticks_msec()-started<10000:await process_frame
		check(output.bridge.device_connected(),"Connected directly: "+output.status_text())
		if output.bridge.device_connected():
			var frame:=PackedByteArray();frame.resize(40)
			for i in [5,6,9,10]:frame[i]=1
			print("PULSE front chest, 25%, one frame with 200 ms watchdog")
			check(output.bridge.submit_frame(frame,.25),"Chest pulse accepted")
			await create_timer(.6).timeout
			var stats: Dictionary=JSON.parse_string(output.bridge.diagnostics_json())
			print("WATCHDOG ",JSON.stringify(stats))
			check(stats.active_writes>0 and stats.last_active_motors==0,"Host wrote active motors, then watchdog wrote zero without Godot refresh")
			output.stop()
			await create_timer(.15).timeout
			stats=JSON.parse_string(output.bridge.diagnostics_json())
			check(stats.last_active_motors==0 and output.bridge.device_connected(),"Explicit stop leaves a connected zero-output session")
	output.close()
	started=Time.get_ticks_msec()
	while output.bridge.is_running() and Time.get_ticks_msec()-started<5000:await process_frame
	check(not output.bridge.is_running() and not output.bridge.device_connected(),"Worker exits and Bluetooth session closes")
	output=null
	print("BHAPTICS_LIVE_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
