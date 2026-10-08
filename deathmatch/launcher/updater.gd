extends Node
signal changed
const P=preload("res://deathmatch/launcher/update_policy.gd")
const Store=preload("res://deathmatch/launcher/update_store.gd")
const Profile=preload("res://deathmatch/profile.gd")
const Paths=preload("res://deathmatch/assets/paths.gd")
var root:=""
var work:=""
var installed: Dictionary={}
var release: Dictionary={}
var managed:=false
var outdated:=false
var phase:="idle"
var message:=""
var fraction:=0.0
var http: HTTPRequest
var disk: Node
var owns_lock:=false
var poll:=0.0
var cache_path:=""
func _ready() -> void:
	root=OS.get_executable_path().get_base_dir();work=root.path_join(P.WORK)
	installed=Store.read(root.path_join(P.MANIFEST))
	managed=not OS.has_feature("editor") and not DirAccess.dir_exists_absolute(root.path_join(".git")) and P.manifest(installed,"",P.platform())
	http=HTTPRequest.new();http.use_threads=true;http.timeout=20;http.body_size_limit=2_000_000;add_child(http);http.request_completed.connect(completed)
	disk=preload("res://deathmatch/network/disk_worker.gd").new();add_child(disk)
	cache_path=ProjectSettings.globalize_path("user://release-"+root.sha256_text().substr(0,16)+".json")
	var cached:=Store.read(cache_path)
	if cached.has("release"):
		phase="checking";completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(cached.release).to_utf8_buffer(),false)
		if Time.get_unix_time_from_system()-float(cached.get("time",0))<3600:return
	check()
func current_version() -> String:return str(installed.version) if managed else str(ProjectSettings.get_setting("application/config/version",""))
func check() -> void:
	if phase!="idle":return
	phase="checking";message="Checking latest public release…";changed.emit()
	http.download_file="";http.timeout=20;http.body_size_limit=2_000_000
	if http.request(P.API,PackedStringArray(["Accept: application/vnd.github+json","User-Agent: FPSloppa-Launcher","X-GitHub-Api-Version: 2022-11-28"]))!=OK:fail("Cannot check GitHub. Try again when connected.")
func completed(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray,save_cache: bool=true) -> void:
	if phase=="checking":
		phase="idle"
		if result!=HTTPRequest.RESULT_SUCCESS or code!=200:fail("Update check unavailable (HTTP %d)."%code);return
		var raw=JSON.parse_string(body.get_string_from_utf8())
		var found:=P.release(raw,current_version(),P.platform())
		if save_cache and found.has("version"):Store.write(cache_path,{"time":Time.get_unix_time_from_system(),"release":raw})
		if found.has("version"):
			release=found;outdated=managed and bool(found.get("outdated",false))
			message=("Update available: "+str(found.version)+(" · %.0f MB"%(float(found.bytes)/1000000.0) if found.has("bytes") else "")) if outdated else ("Client "+current_version()+" is current.")
			if not managed:message="Development / unmanaged install · latest public release: "+str(found.version)
			elif found.has("error"):message=found.error
		else:message=str(found.get("error","Invalid release response."))
		changed.emit();return
	if phase!="downloading":return
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:fail("Download failed (HTTP %d). Retry Update."%code);return
	var file:=FileAccess.open(work.path_join("download.zip"),FileAccess.READ)
	if not file or file.get_length()!=int(release.bytes):fail("Incomplete release download. Retry Update.");return
	file.close();phase="preparing";message="Verifying and preparing update…";fraction=0;changed.emit()
	DirAccess.remove_absolute(work.path_join("progress.json"))
	if not disk.submit(Store.prepare.bind(root,release.duplicate(true),installed.duplicate(true)),prepared):fail("Cannot start verification worker.")
func claim() -> bool:
	if not Store.plain_path(root,P.WORK) or DirAccess.make_dir_recursive_absolute(work)!=OK:return false
	if FileAccess.file_exists(work.path_join("pending.json")):return false
	var lock:=work.path_join("busy")
	if DirAccess.dir_exists_absolute(lock):
		var owner:=Store.read(lock.path_join("owner.json"));var pid:=int(owner.get("pid",0))
		if pid<=0 or preload("res://deathmatch/launcher/update_lease.gd").alive(pid):return false
		if not Store.remove_tree(lock):return false
	if DirAccess.make_dir_absolute(lock)!=OK:return false
	owns_lock=true
	if not Store.write(lock.path_join("owner.json"),{"pid":OS.get_process_id()}):release_lock();return false
	# A committed journal belongs to the previous successful update.
	var journal:=Store.read(work.path_join("journal.json"))
	if not journal.is_empty() and not journal.get("committed",false):release_lock();return false
	DirAccess.remove_absolute(work.path_join("journal.json"));return true
func start() -> void:
	if phase!="idle" or not managed or not outdated:return
	if not release.has("url"):message=str(release.get("error","No verified archive is available."));changed.emit();return
	if not claim():fail("Another updater is active or recovery is pending. Restart using Launch-FPSloppa.");return
	phase="downloading";fraction=0;message="Downloading "+str(release.version)+"…";changed.emit()
	http.download_file=work.path_join("download.zip");http.timeout=0;http.body_size_limit=int(release.bytes)
	if http.request(release.url,PackedStringArray(["User-Agent: FPSloppa-Launcher"]))!=OK:fail("Cannot start release download.")
func cancel() -> void:
	if phase!="downloading":return
	http.cancel_request();DirAccess.remove_absolute(work.path_join("download.zip"));fail("Download cancelled. Update is still required.")
func prepared(result: Dictionary) -> void:
	if result.has("error"):fail(result.error);return
	var job:={"root":root,"parent":OS.get_process_id(),"asset_root":Paths.root(),"config":ProjectSettings.globalize_path(Profile.config_path())}
	var pending:=work.path_join("pending.json")
	if not Store.write(pending,job):fail("Cannot write installer handoff.");return
	var runner:=work.path_join("runner/"+P.executable(P.platform()))
	var pid:=OS.create_process(runner,PackedStringArray(["--xr-mode","off","--","--launcher-install","--install-job",pending]))
	if pid<=0:DirAccess.remove_absolute(pending);fail("Cannot start installer. Retry Update.");return
	# The helper owns pending.json until commit or rollback. It waits for this
	# process and every registered client/asset worker before replacing files.
	owns_lock=false;phase="handoff";message="Starting installer…";changed.emit();get_tree().quit()
func fail(text: String) -> void:
	phase="idle";message=text;fraction=0;release_lock();changed.emit()
func release_lock() -> void:
	if owns_lock:Store.remove_tree(work.path_join("busy"));owns_lock=false
func _process(delta: float) -> void:
	poll+=delta
	if poll<.25:return
	poll=0
	if phase=="downloading":
		var done:=http.get_downloaded_bytes();fraction=clampf(float(done)/maxf(1,float(release.bytes)),0,1)
		message="Downloading %s · %.1f / %.1f MB"%[release.version,done/1000000.0,float(release.bytes)/1000000.0];changed.emit()
	elif phase=="preparing":
		var state:=Store.read(work.path_join("progress.json"));message=str(state.get("message","Verifying release…"));fraction=float(state.get("done",0))/maxf(1,float(state.get("total",0)));changed.emit()
func _exit_tree() -> void:
	http.cancel_request();release_lock()
