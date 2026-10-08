extends Control
const P=preload("res://deathmatch/launcher/update_policy.gd")
const Store=preload("res://deathmatch/launcher/update_store.gd")
const Lease=preload("res://deathmatch/launcher/update_lease.gd")
var root:=""
var work:=""
var job: Dictionary={}
var status: Label
var bar: ProgressBar
var restart: Button
var disk: Node
var started:=false
var finished:=false
var elapsed:=0.0
var locked:=false
var probing:=false
func _ready() -> void:
	get_window().title="FPSloppa · Installing update";get_window().size=Vector2i(680,220);get_tree().auto_accept_quit=false
	var margin:=MarginContainer.new();add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
	var column:=VBoxContainer.new();margin.add_child(column)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(status)
	bar=ProgressBar.new();column.add_child(bar)
	restart=Button.new();restart.text="REOPEN LAUNCHER";restart.visible=false;restart.pressed.connect(reopen);column.add_child(restart)
	var args:=OS.get_cmdline_user_args();var i:=args.find("--install-job")
	if i<0 or i+1>=args.size():status.text="Missing installer job.";finished=true;return
	job=Store.read(args[i+1]);root=str(job.get("root",""));work=root.path_join(P.WORK)
	if root.is_empty() or str(args[i+1]).replace("\\","/").simplify_path()!=work.path_join("pending.json").replace("\\","/").simplify_path() or not Store.plain_path(root,P.WORK):status.text="Invalid installer location.";finished=true;return
	# Atomic helper lock also prevents two recovery wrappers applying together.
	var lock:=work.path_join("installer-lock")
	if DirAccess.dir_exists_absolute(lock):
		var pid:=int(Store.read(lock.path_join("owner.json")).get("pid",0))
		if pid<=0 or preload("res://deathmatch/launcher/update_lease.gd").alive(pid):status.text="Another installer is running.";finished=true;return
		Store.remove_tree(lock)
	if DirAccess.make_dir_absolute(lock)!=OK:status.text="Cannot lock installer.";finished=true;return
	locked=true;Store.write(lock.path_join("owner.json"),{"pid":OS.get_process_id()})
	disk=preload("res://deathmatch/network/disk_worker.gd").new();add_child(disk)
	status.text="Waiting for FPSloppa clients and launcher to close…"
func _process(delta: float) -> void:
	if finished or root.is_empty() or not locked:return
	elapsed+=delta
	if elapsed<(.25 if started else 1.0):return
	elapsed=0
	if not started:
		if probing:return
		probing=true
		disk.submit(func():return not Lease.active(root).is_empty() or Lease.alive(int(job.get("parent",0))),func(active):
			probing=false
			if active:status.text="Close FPSloppa clients and other launchers to continue. Your update is ready.";return
			started=true
			if not disk.submit(Store.install.bind(root),completed):completed({"error":"Cannot start installation worker."}))
	else:
		var state:=Store.read(work.path_join("progress.json"));status.text=str(state.get("message","Installing update…"));bar.value=100.0*float(state.get("done",0))/maxf(1,float(state.get("total",0)))
func completed(result: Dictionary) -> void:
	finished=true;status.text=str(result.get("message",result.get("error","Update finished.")))
	if not result.get("recovery_failed",false):
		DirAccess.remove_absolute(work.path_join("pending.json"));Store.remove_tree(work.path_join("busy"));restart.visible=true
	else:status.text+=" Restart Launch-FPSloppa to retry recovery."
	if result.get("complete",false):bar.value=100;reopen()
func reopen() -> void:
	var args:=PackedStringArray(["--xr-mode","off","--","--launcher","--asset-root",str(job.get("asset_root",root)),"--client-config",str(job.get("config",""))])
	if OS.create_process(root.path_join(P.executable(P.platform())),args)>0:get_tree().quit()
	else:status.text="Could not reopen the launcher. Start Launch-FPSloppa manually."
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and (not started or finished):get_tree().quit()
func _exit_tree() -> void:
	if locked:Store.remove_tree(work.path_join("installer-lock"))
