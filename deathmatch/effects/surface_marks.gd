extends RefCounted
## Shared material assignment and server-verified world contacts for every arsenal.
enum Style { BULLET, CUT, DENT, SCORCH, ENERGY, BIO, PIN }
const SIZES=[.065,.22,.16,.65,.24,.48,.045]
static func profile(d: Dictionary) -> int:
	var title: String=d.get("name","")
	var kind: String=d.get("kind","")
	if title in ["REPAIR GUN","TARGETING LASER"] or kind=="translocator":return -1
	if title in ["AXE","KNIFE","CHAINSAW"] or kind in ["razor","razor_blast"]:return Style.CUT
	if title in ["FIST","SPANNER","WEAPON WHIP","KICK"] or kind=="hammer":return Style.DENT
	if kind=="bio":return Style.BIO
	if kind=="nail":return Style.PIN
	if title in ["PLASMA RIFLE","BFG 9000","RAILGUN","BLASTER","PLASMA GUN","LASER RIFLE"] or kind in ["beam","shock_beam","shock_orb","pulse","plasma","tribes_bolt"]:return Style.ENERGY
	if title in ["FLAMETHROWER","ROCKET LAUNCHER","INCENDIARY CANNON"] or float(d.get("splash",0))>0:return Style.SCORCH
	return Style.BULLET
static func valid_contact(game: Node,hit: Dictionary) -> bool:
	if hit.is_empty() or not hit.collider is StaticBody3D or hit.collider is AnimatableBody3D:return false
	var runtime=game.get_node_or_null("Map/MapRuntime")
	return not runtime or not runtime.triggers.rows.has(hit.collider)
static func contact(game: Node,hit: Dictionary,start: Vector3,end: Vector3,d: Dictionary) -> void:
	if not hit.get("hit",false) or hit.get("id",0)!=0 or hit.has("building") or hit.has("mine") or hit.has("generator") or hit.has("deployable") or hit.has("map_node"):return
	var style:=profile(d)
	if style<0:return
	var direction: Vector3=(end-start).normalized()
	var ray: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,hit.position+direction*(maxf(float(d.get("radius",0)),float(d.get("beam_radius",0)))+.08),1))
	if valid_contact(game,ray):game._surface_marks.rpc(PackedVector3Array([ray.position]),PackedVector3Array([ray.normal]),style)
static func blast(game: Node,point: Vector3,d: Dictionary) -> void:
	var style:=profile(d)
	if style<0:return
	var points:=PackedVector3Array();var normals:=PackedVector3Array()
	# Short, occluded probes: air bursts do not paint distant walls. Never run
	# this from projectile removal, which also handles cancellation and expiry.
	var reach:=minf(1.8,float(d.get("blast_radius",1.8)))
	for axis in [Vector3.DOWN,Vector3.UP,Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		var ray: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point,point+axis*reach,1))
		if valid_contact(game,ray):points.append(ray.position);normals.append(ray.normal)
		if points.size()==3:break
	if not points.is_empty():game._surface_marks.rpc(points,normals,style)
