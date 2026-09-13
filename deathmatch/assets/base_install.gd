extends RefCounted
## Disk-worker-only installer. Verify every payload before replacing any assets.
static func install(data: Dictionary,archive: String,directory: String) -> String:
	if FileAccess.get_sha256(archive)!=data.get("sha256",""):return "Asset archive checksum mismatch."
	var zip:=ZIPReader.new()
	if zip.open(archive)!=OK:return "Cannot open asset archive."
	for row in data.files:
		var relative: String=row.path
		if not (relative.begins_with("maps/") or relative.begins_with("vrm/")) or relative.contains("..") or relative.contains("\\"):
			zip.close();return "Invalid asset path."
		var bytes:=zip.read_file(relative)
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
		if bytes.size()!=int(row.size) or hash.finish().hex_encode()!=row.sha256:
			zip.close();return "Invalid asset: "+relative
	for row in data.files:
		var dest:=directory.path_join(row.path)
		# Keep editable maplists/configs; repair or update bundled binary assets.
		if FileAccess.file_exists(dest) and ((row.path.get_extension() in ["cfg","maplist"] or row.path.ends_with("_maplist.txt")) or FileAccess.get_sha256(dest)==row.sha256):continue
		if DirAccess.make_dir_recursive_absolute(dest.get_base_dir())!=OK:zip.close();return "Cannot create asset directory."
		var temporary:=dest+".installing"
		var file:=FileAccess.open(temporary,FileAccess.WRITE)
		if not file:zip.close();return "Cannot write "+dest
		file.store_buffer(zip.read_file(row.path));var error:=file.get_error();file.close()
		if error!=OK or DirAccess.rename_absolute(temporary,dest)!=OK:zip.close();return "Cannot install "+dest
	zip.close()
	return "Base assets installed."
