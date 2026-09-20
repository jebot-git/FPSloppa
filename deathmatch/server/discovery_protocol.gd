extends RefCounted
## Versioned, bounded JSON shared by public queries and the browser.
const WIRE := "fpsloppa-query-1"
const MAX_PACKET := 1200
const MAX_SERVERS := 256
const MODES := ["dm","tdm","ctf","koth","ig","if","ft","cc","tf","tb","as"]

static func public_text(value: String, byte_limit: int=80) -> String:
	var output:="";var bytes:=0
	for c in value:
		if c.unicode_at(0)<32 or c.unicode_at(0)==127:c=" "
		var count:=c.to_utf8_buffer().size()
		if bytes+count>byte_limit:break
		output+=c;bytes+=count
	return output.strip_edges() if not output.strip_edges().is_empty() else "Unknown"

static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=low and value<=high

static func plain(value: Variant, limit: int) -> bool:
	if not value is String or value.is_empty() or value.length()>limit:return false
	for c in value:
		if c.unicode_at(0)<32 or c.unicode_at(0)==127:return false
	return true

static func valid_status(value: Variant) -> bool:
	if not value is Dictionary:return false
	for key in {"name":80,"map":80,"map_title":80,"protocol":80,"version":40}:
		if not plain(value.get(key),{"name":80,"map":80,"map_title":80,"protocol":80,"version":40}[key]):return false
	if not value.get("mode") in MODES or not value.get("weapon_rules") in ["doom","quake","ut99"]:return false
	if not value.get("state") in ["match","lobby","intermission","loading"]:return false
	if not integer(value.get("game_port"),1024,65535) or not integer(value.get("capacity"),1,32):return false
	for key in ["humans","spectators","bots","reserved","open_slots"]:
		if not integer(value.get(key),0,32):return false
	return value.humans+value.spectators+value.reserved+value.open_slots==value.capacity and value.humans+value.spectators+value.bots<=value.capacity

static func valid_endpoint(value: Variant) -> bool:
	return value is Dictionary and value.get("address") is String and value.address.is_valid_ip_address() and integer(value.get("game_port"),1024,65535) and integer(value.get("query_port"),1024,65535) and value.game_port!=value.query_port

static func endpoint_key(value: Dictionary) -> String:
	return "%s|%d|%d"%[value.address,int(value.game_port),int(value.query_port)]

static func valid_url(url: String) -> bool:
	# Public connections always use TLS. Numeric loopback HTTP is for local setup/tests.
	if url.length()>512 or url.contains("@") or url.contains("?") or url.contains("#"):return false
	for c in url:
		if c.unicode_at(0)<=32 or c.unicode_at(0)==127 or c=="\\":return false
	var expression:=RegEx.new()
	expression.compile("^https://(\\[[0-9a-fA-F:]+\\]|[a-zA-Z0-9.-]+)(:[0-9]{1,5})?(/[a-zA-Z0-9_./-]*)?$")
	if expression.search(url):return true
	expression.compile("^http://(127\\.0\\.0\\.1|\\[::1\\])(:[0-9]{1,5})?(/[a-zA-Z0-9_./-]*)?$")
	return expression.search(url)!=null

static func decode(packet: PackedByteArray) -> Dictionary:
	if packet.is_empty() or packet.size()>MAX_PACKET:return {}
	var parser:=JSON.new()
	if parser.parse(packet.get_string_from_utf8())!=OK:return {}
	var value=parser.data
	return value if value is Dictionary and value.get("wire")==WIRE else {}

static func packet(kind: String, nonce: String, cookie: String="") -> PackedByteArray:
	var value: Dictionary={"wire":WIRE,"kind":kind,"nonce":nonce}
	if not cookie.is_empty():value.cookie=cookie
	# The unauthenticated challenge response cannot amplify the request.
	if kind=="hello":value.padding="x".repeat(96)
	return JSON.stringify(value).to_utf8_buffer()
