extends SceneTree
const P=preload("res://deathmatch/launcher/update_policy.gd")
const S=preload("res://deathmatch/launcher/update_store.gd")
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:push_error(message);quit(1);assert(ok,message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	check(preload("res://deathmatch/launcher/update_lease.gd").alive(OS.get_process_id()),"current process detected")
	check(not preload("res://deathmatch/launcher/update_lease.gd").alive(2147483647),"missing process detected")
	check(P.newer("0.22v","0.21v"),"version advances")
	check(P.newer("v0.100.0","0.99v"),"numeric version ordering")
	check(not P.newer("0.21v","0.22v") and not P.newer("0.22v","0.22v"),"never downgrade/reinstall")
	check(P.version("0.23-beta").is_empty(),"stable only")
	for bad in ["../escape","/tmp/a","maps/../../a","C:/a","maps\\a",".launcher-update/a","a/NUL.txt","a/foo.","a//b"]:check(not P.safe_path(bad),"unsafe path "+bad)
	var raw:={"tag_name":"0.22v","draft":false,"prerelease":false,"assets":[]}
	check(P.release(raw,"0.21v","Linux").outdated,"missing archive still gates old client")
	raw.draft=true;check(P.release(raw,"0.21v","Linux").has("error"),"draft rejected");raw.draft=false
	raw.assets=[{"name":"FPSloppa-0.22v-Linux.zip","digest":"sha256:"+"a".repeat(64),"size":100,"browser_download_url":"https://github.com/"+P.REPOSITORY+"/releases/download/0.22v/FPSloppa-0.22v-Linux.zip"}]
	check(P.release(raw,"0.21v","Linux").has("url"),"valid release selected")
	raw.assets[0].browser_download_url="https://evil.invalid/payload";check(not P.release(raw,"0.21v","Linux").has("url"),"untrusted URL rejected")
	for kind in ["success","rollback","recovery","unsafe","checksum","modified","symlink"]:
		var folder: String="/tmp/fpsloppa-update-tests/"+kind;var work:=folder.path_join(P.WORK)
		var prepared:=S.prepare(folder,S.read(folder.path_join("release.json")),S.read(folder.path_join(P.MANIFEST)))
		if kind in ["unsafe","checksum"]:check(prepared.has("error"),kind+" rejected");continue
		check(not prepared.has("error"),kind+" prepared: "+str(prepared.get("error","")))
		if kind=="rollback":DirAccess.remove_absolute(work.path_join("stage/FPSloppa.pck"))
		if kind=="recovery":
			DirAccess.make_dir_recursive_absolute(work.path_join("backup"))
			var old:=FileAccess.get_sha256(folder.path_join("FPSloppa.x86_64"));var next:=FileAccess.get_sha256(work.path_join("stage/FPSloppa.x86_64"))
			DirAccess.rename_absolute(folder.path_join("FPSloppa.x86_64"),work.path_join("backup/FPSloppa.x86_64"))
			DirAccess.rename_absolute(work.path_join("stage/FPSloppa.x86_64"),folder.path_join("FPSloppa.x86_64"))
			S.write(work.path_join("journal.json"),{"committed":false,"actions":[{"path":"FPSloppa.x86_64","old":old,"new":next}]})
		var result:=S.install(folder)
		check(bool(result.get("complete",false))==(kind=="success"),kind+" result: "+str(result))
		check(FileAccess.get_file_as_string(folder.path_join("maps/edited.bsp"))=="custom map",kind+" customized map preserved")
		check(FileAccess.get_file_as_string(folder.path_join("maps/local.bsp"))=="custom collision",kind+" local collision preserved")
		check(FileAccess.get_file_as_string(folder.path_join("bgm/global.m3u8"))=="my song.ogg\n",kind+" playlist preserved")
		check(FileAccess.get_file_as_string(folder.path_join("client.cfg"))=="my settings",kind+" config preserved")
		check(FileAccess.get_file_as_string(folder.path_join("FPSloppa.x86_64"))==("new exe" if kind=="success" else "old exe"),kind+" executable correct")
		check(S.read(folder.path_join(P.MANIFEST)).version==("0.22v" if kind=="success" else "0.21v"),kind+" version committed last")
		if kind=="success":
			check(not FileAccess.file_exists(folder.path_join("old-library.so")),"obsolete owned library removed")
			check(FileAccess.get_file_as_string(folder.path_join("maps/base.bsp"))=="new base","unmodified base updated")
			check(S.install(folder).get("complete",false),"committed journal is idempotent")
	print("Launcher updater: ",checks," checks passed");quit()
