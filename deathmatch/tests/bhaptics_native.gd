extends SceneTree
const Native=preload("res://deathmatch/haptics/native.gd")
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var output:=Native.new()
	check(output.open("",0)==OK,"Compiled native GDExtension loads in Godot 4.7")
	if not output.bridge:quit(1);return
	check(not output.bridge.device_connected() and not output.bridge.is_running(),"Loading the plugin starts no discovery and connects no device")
	check(output.devices().is_empty(),"Device selection is explicit")
	check(not output.connect_device("unknown-device"),"Unknown device cannot be connected")
	check(not output.bridge.submit_frame(PackedByteArray([1]),.5),"Native API rejects malformed motor frames")
	var frame:=PackedByteArray();frame.resize(40);frame.fill(1)
	check(not output.bridge.submit_frame(frame,NAN),"Native API rejects non-finite strength")
	check(not output.bridge.submit_frame(frame,.5),"Disconnected native backend discards effects")
	# This fixture deliberately disables the system bus; it never scans real devices.
	if OS.get_environment("DBUS_SYSTEM_BUS_ADDRESS")=="unix:path=/tmp/fpsloppa-bhaptics-unavailable.sock":
		var start:=Time.get_ticks_msec()
		output.scan()
		check(Time.get_ticks_msec()-start<100,"Bluetooth work is dispatched without blocking the render thread")
		var frames:=0
		while output.bridge.is_running() and Time.get_ticks_msec()-start<4000:
			await process_frame;frames+=1
		check(not output.bridge.is_running() and not output.bridge.device_connected(),"Unavailable Bluetooth service exits the worker cleanly")
		check(output.status_text().contains("unavailable"),"Bluetooth failure appears as client status")
		check(frames>0,"Godot remains responsive during Bluetooth initialization")
	else:check(false,"Native regression requires the isolated D-Bus address")
	output.stop();output.close()
	check(not output.is_open(),"Native stop closes the client backend")
	output=null
	print("BHAPTICS_NATIVE_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
