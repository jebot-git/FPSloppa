extends RefCounted
## Private provisioning files for externally supervised, tunnel-connected workers.
const PROTOCOL:="cq-external-worker-1"
static func secret(value) -> bool:
	return value is String and value.length()==64 and value.is_valid_hex_number(false)
static func number(value,minimum: int,maximum: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value==int(value) and value>=minimum and value<=maximum
static func read(path: String) -> Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>16384:return {"error":"Missing or oversized external worker file"}
	var value=JSON.parse_string(file.get_as_text())
	if not value is Dictionary:return {"error":"Invalid external worker JSON"}
	if not number(value.get("port"),1024,65535) or not secret(value.get("session")):return {"error":"Invalid external worker port/session"}
	return value
static func gateway(path: String,limit: int) -> Dictionary:
	var value:=read(path)
	if value.has("error"):return value
	if not value.get("workers") is Array or value.workers.is_empty() or value.workers.size()>limit:return {"error":"External worker inventory exceeds the configured limit or is empty"}
	var seen: Dictionary={};var tokens: Dictionary={};var instances: Dictionary={}
	for row in value.workers:
		if not row is Dictionary or not number(row.get("zone"),0,15) or not secret(row.get("token")) or not secret(row.get("instance")):return {"error":"Invalid external worker inventory entry"}
		if seen.has(int(row.zone)) or tokens.has(row.token) or instances.has(row.instance):return {"error":"Duplicate external district or credentials"}
		seen[int(row.zone)]=true;tokens[row.token]=true;instances[row.instance]=true
	return value
static func worker(path: String,zone: int) -> Dictionary:
	var value:=read(path)
	if value.has("error"):return value
	if not number(value.get("zone"),0,15) or int(value.zone)!=zone or not secret(value.get("token")) or not secret(value.get("instance")):return {"error":"Invalid external worker identity"}
	return value
