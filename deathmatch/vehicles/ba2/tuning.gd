extends RefCounted
const SPEED=0.8 # metres/second; 48 metres/minute at cruise.
const TRANSITION=5.0 # Smooth five-second acceleration and braking.
const STRIDE=2.52
const AUTHORED_SPEED=0.45 # Source clip: 2.52 metres over 5.6 seconds.
const LATERAL_LIMIT=PI/24 # +/-7.5 degrees, a total fifteen-degree route-facing arc.
static func body_sway(row: Dictionary) -> float:
	return deg_to_rad(3)*sin(fposmod(float(row.distance),STRIDE)/STRIDE*TAU)*clampf(float(row.speed)/SPEED,0,1)
static func body_yaw(row: Dictionary) -> float:
	return clampf(float(row.get("body_yaw",body_sway(row))),-LATERAL_LIMIT,LATERAL_LIMIT)
