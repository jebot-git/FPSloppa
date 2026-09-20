extends Node
## Opt-in local test directory, owned by the dedicated process. No shell commands.
var game
var pid:=-1
var token:=""
var registry:=""
var ready_file:=""
var deadline:=0
var announced:=false
var next_check:=0
var last_error:=""

func setup(arena: Node, port: int) -> bool:
	game=arena
	var script: String=ProjectSettings.globalize_path("res://tools/master_server/server.py") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("master/server.py")
	if not FileAccess.file_exists(script):last_error="Test master helper is missing. Use the source checkout or complete dedicated-server package.";return false
	token=Crypto.new().generate_random_bytes(32).hex_encode()
	var folder:=ProjectSettings.globalize_path("user://master-test")
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:last_error="Cannot create test master runtime directory.";return false
	registry=folder.path_join(str(OS.get_process_id())+"-"+Crypto.new().generate_random_bytes(8).hex_encode()+".json")
	ready_file=registry+".ready"
	var file:=FileAccess.open(registry,FileAccess.WRITE)
	if not file:last_error="Cannot write test master token registry.";return false
	file.store_string(JSON.stringify({"local-test":token.sha256_text()}));file.close()
	var python: String=OS.get_environment("FPSLOPPA_PYTHON")
	if python.is_empty():python="python" if OS.has_feature("windows") else "python3"
	pid=OS.create_process(python,[script,"--bind","127.0.0.1","--port",str(port),"--tokens",registry,"--allow-loopback","--parent-pid",str(OS.get_process_id()),"--ready-file",ready_file])
	if pid<=0:last_error="Cannot start test master. Install Python 3.10+ or set FPSLOPPA_PYTHON.";return false
	deadline=Time.get_ticks_msec()+10000
	return true

func _process(_delta: float) -> void:
	if pid<=0 or Time.get_ticks_msec()<next_check:return
	next_check=Time.get_ticks_msec()+250
	if not OS.is_process_running(pid):
		push_error("Test master exited. Check Python availability and sv_master_test_port; see the master startup output.")
		get_tree().quit(2);return
	if not announced and FileAccess.file_exists(ready_file):
		announced=true
		var port:=FileAccess.get_file_as_string(ready_file).strip_edges()
		game.server_log.record("test_master_ready",{"pid":pid,"url":"http://127.0.0.1:"+port})
		print("TEST_MASTER_READY url=http://127.0.0.1:",port)
		if game.discovery:game.discovery.next_heartbeat=0
	elif not announced and Time.get_ticks_msec()>deadline:
		push_error("Test master startup timed out.");get_tree().quit(2)

func _exit_tree() -> void:
	if pid>0 and OS.is_process_running(pid):OS.kill(pid)
	for path in [registry,ready_file]:
		if not path.is_empty() and FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	token="";pid=-1
