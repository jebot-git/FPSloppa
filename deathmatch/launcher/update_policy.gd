extends RefCounted
const REPOSITORY="jebot-git/FPSloppa"
const API="https://api.github.com/repos/"+REPOSITORY+"/releases/latest"
const MANIFEST="INSTALL-MANIFEST.json"
const WORK=".launcher-update"
const MAX_ARCHIVE=4_000_000_000
const MAX_PAYLOAD=8_000_000_000
static func version(value: String) -> Array:
	var re:=RegEx.new();re.compile("^v?([0-9]+(?:\\.[0-9]+){1,3})v?$")
	var found:=re.search(value)
	if not found:return []
	var parts: Array=[]
	for part in found.get_string(1).split("."):parts.append(int(part))
	while parts.size()<4:parts.append(0)
	return parts
static func newer(candidate: String,current: String) -> bool:
	var a:=version(candidate);var b:=version(current)
	if a.is_empty() or b.is_empty():return false
	for i in 4:
		if a[i]!=b[i]:return a[i]>b[i]
	return false
static func platform() -> String:
	return "Linux" if OS.get_name()=="Linux" else "Windows" if OS.get_name()=="Windows" else ""
static func executable(target: String) -> String:return "FPSloppa.exe" if target=="Windows" else "FPSloppa.x86_64"
static func sha(value) -> bool:
	if not value is String or value.length()!=64:return false
	for ch in value:
		if not ch in "0123456789abcdef":return false
	return true
static func safe_path(value: String) -> bool:
	if value.is_empty() or value.length()>220 or value.is_absolute_path() or value.contains("\\") or value.contains(":"):return false
	for part in value.split("/"):
		if part.is_empty() or part in [".",".."] or part.begins_with(".") or part.ends_with(".") or part.ends_with(" "):return false
		for ch in part:
			if ch.unicode_at(0)<32 or ch in ['"',"<",">","|","?","*"]:return false
		if part.get_slice(".",0).to_upper() in ["CON","PRN","AUX","NUL","COM1","COM2","COM3","COM4","COM5","COM6","COM7","COM8","COM9","LPT1","LPT2","LPT3","LPT4","LPT5","LPT6","LPT7","LPT8","LPT9"]:return false
	return true
static func content(path: String) -> bool:
	return path.begins_with("maps/") or path.begins_with("vrm/") or path.begins_with("bgm/") or path.ends_with(".cfg")
static func manifest(value,expected_version: String="",target: String="") -> bool:
	if not value is Dictionary or value.get("schema")!=1 or value.get("repository")!=REPOSITORY:return false
	if not value.get("version") is String or version(value.version).is_empty() or (not expected_version.is_empty() and value.version!=expected_version):return false
	if not value.get("platform") in ["Linux","Windows"] or (not target.is_empty() and value.platform!=target):return false
	if not value.get("files") is Array or value.files.is_empty() or value.files.size()>20000:return false
	var seen: Dictionary={};var total:=0
	for row in value.files:
		if not row is Dictionary or not row.get("path") is String or not safe_path(row.path) or row.path==MANIFEST or not sha(row.get("sha256")):return false
		if seen.has(row.path.to_lower()) or not (row.get("bytes") is float or row.get("bytes") is int) or row.bytes<0 or row.bytes>1_500_000_000:return false
		if int(row.get("mode",420)) not in [420,493]:return false
		seen[row.path.to_lower()]=true;total+=int(row.bytes)
	if total>MAX_PAYLOAD:return false
	return seen.has(executable(value.platform).to_lower()) and seen.has("fpsloppa.pck")
static func release(value,current: String,target: String) -> Dictionary:
	if not value is Dictionary or value.get("draft",true) or value.get("prerelease",true) or not value.get("tag_name") is String or version(value.tag_name).is_empty():return {"error":"GitHub returned no valid stable release."}
	var result:={"version":str(value.tag_name),"outdated":newer(value.tag_name,current),"notes":"https://github.com/"+REPOSITORY+"/releases/tag/"+str(value.tag_name)}
	if not result.outdated:return result
	if not value.get("assets") is Array:result.error="Release assets are missing.";return result
	var wanted:="FPSloppa-"+str(value.tag_name)+"-"+target+".zip"
	for asset in value.assets:
		if not asset is Dictionary or asset.get("name")!=wanted:continue
		var digest:=str(asset.get("digest","")).trim_prefix("sha256:")
		var url:=str(asset.get("browser_download_url",""))
		if not sha(digest) or url!="https://github.com/"+REPOSITORY+"/releases/download/"+str(value.tag_name)+"/"+wanted or int(asset.get("size",0))<=0 or int(asset.size)>MAX_ARCHIVE:continue
		result.merge({"url":url,"sha256":digest,"bytes":int(asset.size)});return result
	result.error="New release found, but its verified "+target+" client archive is unavailable."
	return result
