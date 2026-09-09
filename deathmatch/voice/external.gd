extends RefCounted
## A deliberate handoff to the user's Mumble client, never an automatic microphone connection.
static func valid_url(value: String) -> bool:
	if value.length()>512:return false
	var expression:=RegEx.new()
	expression.compile("^mumble://([A-Za-z0-9.-]+|\\[[0-9A-Fa-f:]+\\])(:[0-9]{1,5})?(/[A-Za-z0-9._~%/-]*)?(\\?version=1\\.2\\.0)?$")
	var match_result:=expression.search(value)
	if not match_result:return false
	var port: String=match_result.get_string(2)
	return port.is_empty() or (int(port.substr(1))>=1 and int(port.substr(1))<=65535)
static func open_client(value: String) -> Error:
	if not valid_url(value):return ERR_INVALID_PARAMETER
	return OS.shell_open(value)
