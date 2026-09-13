extends RefCounted
## Common map/model upload budget. Gameplay is charged first, never delayed here.
const RATE = 4_194_304.0 # Previous combined map/model ceiling, now includes reserved gameplay.
const BURST = 65_536.0
const PEER_RATE = 1_048_576.0
var tokens := BURST
var updated := -1.0
var peers: Dictionary = {}
var realtime_bytes := 0
var asset_bytes := 0
var throttled := 0
func reset() -> void:
	tokens = BURST; updated = -1; peers.clear(); realtime_bytes = 0; asset_bytes = 0; throttled = 0
func tick(now: float) -> void:
	if updated >= 0: tokens = minf(BURST,tokens+maxf(0,now-updated)*RATE)
	updated = now
func reserve(bytes: int, now: float) -> void:
	tick(now); tokens = maxf(-BURST,tokens-bytes); realtime_bytes += bytes
func claim(peer: int, requested: int, now: float, active_peers: int = 1, rtt_ms: float = 0, outstanding: int = 0) -> int:
	tick(now)
	var row: Dictionary = peers.get(peer,{"tokens":32768.0,"at":now,"baseline":rtt_ms})
	if rtt_ms > 0: row.baseline = rtt_ms if row.baseline <= 0 else minf(row.baseline,rtt_ms)
	var rate := minf(PEER_RATE,RATE/maxi(1,active_peers))
	if rtt_ms > row.baseline+40: rate *= .35
	row.tokens = minf(32768,row.tokens+maxf(0,now-row.at)*rate); row.at = now; peers[peer] = row
	# Keep the aggregate map + model queue for a peer small, even on a fast disk.
	var grant := mini(mini(requested,32768),65536-outstanding)
	if outstanding >= 65536 or grant<=0 or tokens<grant or row.tokens<grant: throttled += 1; return 0
	tokens -= grant; row.tokens -= grant; asset_bytes += grant
	return grant
