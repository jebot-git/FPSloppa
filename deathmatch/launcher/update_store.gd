extends RefCounted
const P=preload("res://deathmatch/launcher/update_policy.gd")
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):return {}
	var file:=FileAccess.open(path,FileAccess.READ)
	if not file or file.get_length()>8_000_000:return {}
	var value=JSON.parse_string(file.get_as_text());return value if value is Dictionary else {}
static func write(path: String,value: Dictionary) -> bool:
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file:return false
	file.store_string(JSON.stringify(value));file.flush();var ok:=file.get_error()==OK;file.close()
	return ok and DirAccess.rename_absolute(path+".tmp",path)==OK
static func plain_path(root: String,path: String) -> bool:
	var current:=root;var dir:=DirAccess.open(root)
	if not dir:return false
	for part in path.split("/"):
		dir=DirAccess.open(current)
		if dir and dir.is_link(part):return false
		current=current.path_join(part)
	return true
static func remove_tree(path: String) -> bool:
	var dir:=DirAccess.open(path)
	if not dir:return not FileAccess.file_exists(path) or DirAccess.remove_absolute(path)==OK
	dir.include_hidden=true
	for name in dir.get_files():
		if dir.remove(name)!=OK:return false
	for name in dir.get_directories():
		if dir.is_link(name):
			if dir.remove(name)!=OK:return false
		elif not remove_tree(path.path_join(name)):return false
	return DirAccess.remove_absolute(path)==OK
static func status(work: String,message: String,done: int=0,total: int=0) -> void:
	write(work.path_join("progress.json"),{"message":message,"done":done,"total":total})
static func prepare(root: String,release: Dictionary,installed: Dictionary) -> Dictionary:
	var work:=root.path_join(P.WORK);var archive:=work.path_join("download.zip")
	status(work,"Verifying release checksum…")
	if not P.manifest(installed,"",P.platform()) or DirAccess.dir_exists_absolute(root.path_join(".git")):return {"error":"Only managed release installations can be updated."}
	if FileAccess.get_sha256(archive)!=release.sha256:return {"error":"Release checksum mismatch. Download again."}
	var zip:=ZIPReader.new()
	if zip.open(archive)!=OK:return {"error":"Cannot open release ZIP."}
	var prefix:="FPSloppa-"+str(installed.platform)+"/";var names:=zip.get_files();var seen: Dictionary={}
	for name in names:
		if not name.begins_with(prefix):zip.close();return {"error":"Unexpected ZIP layout."}
		var relative:=str(name).trim_prefix(prefix).trim_suffix("/")
		if relative.is_empty():continue
		if not P.safe_path(relative) or seen.has(relative.to_lower()):zip.close();return {"error":"Unsafe or duplicate ZIP path."}
		seen[relative.to_lower()]=true
	var raw:=zip.read_file(prefix+P.MANIFEST)
	if raw.size()>8_000_000:zip.close();return {"error":"Oversized install manifest."}
	var manifest=JSON.parse_string(raw.get_string_from_utf8())
	if not P.manifest(manifest,release.version,installed.platform):zip.close();return {"error":"This release has no supported install manifest."}
	var total:=0;var listed: Dictionary={}
	for row in manifest.files:total+=int(row.bytes);listed[row.path]=true
	for name in names:
		if not name.ends_with("/") and name!=prefix+P.MANIFEST and not listed.has(str(name).trim_prefix(prefix)):zip.close();return {"error":"ZIP contains an unlisted file."}
	var disk:=DirAccess.open(root)
	if disk.get_space_left()<total*2+1_000_000_000:zip.close();return {"error":"Insufficient free space for staging, helper and rollback."}
	var stage:=work.path_join("stage")
	if not plain_path(root,P.WORK+"/stage") or not remove_tree(stage) or DirAccess.make_dir_recursive_absolute(stage)!=OK:zip.close();return {"error":"Cannot create update staging folder."}
	var done:=0
	for row in manifest.files:
		if str(row.path).begins_with("bgm/"):zip.close();return {"error":"Release may not replace user playlists."}
		var bytes:=zip.read_file(prefix+row.path)
		if bytes.size()!=int(row.bytes):zip.close();return {"error":"Missing or truncated ZIP entry: "+row.path}
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
		if hash.finish().hex_encode()!=row.sha256:zip.close();return {"error":"File checksum mismatch: "+row.path}
		var target:=stage.path_join(row.path)
		if DirAccess.make_dir_recursive_absolute(target.get_base_dir())!=OK:zip.close();return {"error":"Cannot create staged directory."}
		var file:=FileAccess.open(target,FileAccess.WRITE)
		if not file:zip.close();return {"error":"Cannot write staged file."}
		file.store_buffer(bytes);file.flush();var ok:=file.get_error()==OK;file.close()
		if not ok:zip.close();return {"error":"Staging write failed."}
		if OS.get_name()!="Windows":FileAccess.set_unix_permissions(target,int(row.get("mode",420)))
		done+=bytes.size();status(work,"Verifying and extracting "+row.path,done,total)
	zip.close()
	if not write(stage.path_join(P.MANIFEST),manifest):return {"error":"Cannot stage install metadata."}
	# Copy the current runtime outside the files being replaced. Windows can then
	# release every installed DLL/PCK before the transaction starts.
	var runner:=work.path_join("runner")
	if not plain_path(root,P.WORK+"/runner") or not remove_tree(runner) or DirAccess.make_dir_recursive_absolute(runner)!=OK:return {"error":"Cannot prepare installer runtime."}
	for row in installed.files:
		if str(row.path).contains("/") or (row.path!=P.executable(installed.platform) and row.path!="FPSloppa.pck" and not str(row.path).ends_with(".dll") and not str(row.path).contains(".so")):continue
		status(work,"Preparing installer runtime: "+row.path)
		if not plain_path(root,row.path) or DirAccess.copy_absolute(root.path_join(row.path),runner.path_join(row.path),int(row.get("mode",420)))!=OK:return {"error":"Cannot copy installer runtime: "+row.path}
	return {"manifest":manifest}
static func plan(root: String,next: Dictionary) -> Dictionary:
	var old:=read(root.path_join(P.MANIFEST))
	if not P.manifest(old) or not P.manifest(next,"",old.platform) or not P.newer(next.version,old.version):return {"error":"Invalid or non-newer installation metadata."}
	var owned: Dictionary={};var desired: Dictionary={};var actions: Array=[];var preserved: Array=[]
	for row in old.files:owned[row.path]=row
	for row in next.files:
		desired[row.path]=true
		if not plain_path(root,row.path):return {"error":"Update path contains a symbolic link: "+row.path}
		var target:=root.path_join(row.path);var exists:=FileAccess.file_exists(target)
		if DirAccess.dir_exists_absolute(target):return {"error":"A directory conflicts with "+row.path}
		var digest:=FileAccess.get_sha256(target) if exists else ""
		if exists and digest==row.sha256:continue
		if exists and (not owned.has(row.path) or digest!=owned[row.path].sha256):
			if P.content(row.path):preserved.append(row.path);continue
			return {"error":"Locally modified/unowned program file: "+row.path+". Restore it or install separately."}
		actions.append({"path":row.path,"old":digest,"new":row.sha256})
	for path in owned:
		if desired.has(path) or P.content(path):continue
		if not plain_path(root,path):return {"error":"Linked obsolete file: "+path}
		if FileAccess.get_sha256(root.path_join(path))==owned[path].sha256:actions.append({"path":path,"old":owned[path].sha256,"new":""})
	actions.append({"path":P.MANIFEST,"old":FileAccess.get_sha256(root.path_join(P.MANIFEST)),"new":FileAccess.get_sha256(root.path_join(P.WORK+"/stage/"+P.MANIFEST))})
	return {"actions":actions,"preserved":preserved,"version":next.version}
static func rollback(root: String,journal: Dictionary) -> bool:
	var work:=root.path_join(P.WORK)
	var actions: Array=journal.get("actions",[]).duplicate();actions.reverse()
	for row in actions:
		var path: String=row.get("path","")
		if not P.safe_path(path) or not plain_path(root,path):return false
		var target:=root.path_join(path);var backup:=work.path_join("backup/"+path)
		if FileAccess.file_exists(backup):
			if FileAccess.file_exists(target) and DirAccess.remove_absolute(target)!=OK:return false
			if DirAccess.rename_absolute(backup,target)!=OK:return false
		elif row.old=="" and FileAccess.file_exists(target):
			if FileAccess.get_sha256(target)!=row.new or DirAccess.remove_absolute(target)!=OK:return false
	return true
static func install(root: String) -> Dictionary:
	var work:=root.path_join(P.WORK);var journal_path:=work.path_join("journal.json")
	var journal:=read(journal_path)
	if not journal.is_empty():
		if journal.get("committed",false):return {"complete":true,"message":"Update was already completed."}
		status(work,"Recovering interrupted update…")
		if not rollback(root,journal):return {"error":"Recovery needs attention. Keep the update backup folder.","recovery_failed":true}
		DirAccess.remove_absolute(journal_path)
		return {"error":"Interrupted update rolled back. You can retry the download."}
	var next:=read(work.path_join("stage/"+P.MANIFEST));var planned:=plan(root,next)
	if planned.has("error"):return planned
	if not plain_path(root,P.WORK+"/backup") or not remove_tree(work.path_join("backup")):return {"error":"Cannot clear the previous rollback copy."}
	journal={"actions":[],"committed":false}
	for row in planned.actions:
		var path: String=row.path;var target:=root.path_join(path);var backup:=work.path_join("backup/"+path);var staged:=work.path_join("stage/"+path)
		status(work,"Installing "+path,journal.actions.size(),planned.actions.size())
		var error:=""
		if not plain_path(root,path) or (FileAccess.get_sha256(target) if FileAccess.file_exists(target) else "")!=row.old:error="File changed during update: "+path
		elif row.new!="" and FileAccess.get_sha256(staged)!=row.new:error="Staged file changed: "+path
		elif DirAccess.make_dir_recursive_absolute(backup.get_base_dir())!=OK or DirAccess.make_dir_recursive_absolute(target.get_base_dir())!=OK:error="Cannot create installation directories."
		else:
			journal.actions.append(row)
			if not write(journal_path,journal):error="Cannot save update journal."
			elif row.old!="" and DirAccess.rename_absolute(target,backup)!=OK:error="Cannot replace "+path+". Close other game instances."
			elif row.new!="" and DirAccess.rename_absolute(staged,target)!=OK:error="Cannot install "+path
		if not error.is_empty():
			var restored:=rollback(root,journal)
			if restored:DirAccess.remove_absolute(journal_path)
			return {"error":error+(" Previous version restored." if restored else " Recovery needs attention; keep the backup folder."),"recovery_failed":not restored}
	journal.committed=true
	if not write(journal_path,journal):
		var restored:=rollback(root,journal)
		if restored:DirAccess.remove_absolute(journal_path)
		return {"error":"Cannot commit update.","recovery_failed":not restored}
	write(work.path_join("last-result.json"),{"version":next.version,"preserved":planned.preserved,"success":true})
	return {"complete":true,"message":"Updated to "+next.version,"preserved":planned.preserved}
