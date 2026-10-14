extends RefCounted
## Covered ground-floor rooms; one capture cylinder at every authored jungle POI.
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Architecture=preload("res://tools/voxel_battle/architecture.gd")
const Points=preload("res://deathmatch/conquest/frontier/points.gd")
const RADIUS:=3.0
const ROLES=["town hall","dispatch","warehouse","barracks","radar control","relay control","crossing guardhouse","expedition laboratory","outpost storehouse","summit instrument lab","archaeology shelter"]
var game
var sites:Array=[]
var rules=Points.new()
var visuals:Node3D
var labels:Array=[]
func _init() -> void:
	var specs:=Architecture.specifications()
	for zone in Landscape.CENTERS.size():
		var chosen:Dictionary=specs.filter(func(row):return row.kind==zone and row.role==ROLES[zone])[0]
		sites.append({"name":Landscape.TYPES[zone],"position":Landscape.CENTERS[zone]+chosen.center+Vector3(0,.13,-3),"building":chosen})
	rules.reset(sites.size())
func setup(arena) -> void:game=arena
func present(id:int,zone:int) -> bool:
	if not game.classes.alive(id) or game.battery_tanks.mounted(id):return false
	return game.match_mode.nearby(id,sites[zone].position,RADIUS)
func tick(delta:float) -> void:
	var presence:Array=[]
	for zone in sites.size():presence.append([false,false])
	for id in game.players:
		var state:Dictionary=game.players[id]
		if state.spectator or state.team not in [0,1] or not game.classes.alive(id) or game.battery_tanks.mounted(id):continue
		for zone in sites.size():
			if present(id,zone):presence[zone][state.team]=true
	for zone in rules.advance(delta,presence):game._announcement.rpc(sites[zone].name.capitalize()+" captured by "+game.match_mode.TEAMS[rules.owners[zone]])
	game.match_mode.scores=rules.scores.duplicate();game.match_mode.check_limit()
func reset() -> void:
	rules.reset(sites.size());clear_visuals()
func clear_visuals() -> void:
	if is_instance_valid(visuals):visuals.queue_free()
	visuals=null;labels.clear()
func draw() -> void:
	if game.headless:return
	if not is_instance_valid(visuals):
		visuals=Node3D.new();game.get_node("Map").add_child(visuals)
		for site in sites:
			var marker:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=RADIUS-.07;ring.outer_radius=RADIUS;ring.rings=24;ring.ring_segments=4
			marker.mesh=ring;marker.position=site.position+Vector3.UP*.01;marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;marker.visibility_range_end=120;visuals.add_child(marker)
			var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;marker.material_override=material
			var label:=Label3D.new();label.position=site.position+Vector3.UP*2.1;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=30;label.pixel_size=.005;label.visibility_range_end=75;visuals.add_child(label);labels.append([label,material])
	for zone in sites.size():
		var owner:int=rules.owners[zone];var color:Color=game.match_mode.COLORS[owner] if owner>=0 else Color("d5c9a0")
		labels[zone][1].albedo_color=color;labels[zone][0].modulate=color
		labels[zone][0].text=sites[zone].name.to_upper()+" · "+("NEUTRAL" if owner<0 else game.match_mode.TEAMS[owner])+progress_text(zone)
func progress_text(zone:int) -> String:
	if rules.contested[zone]:return " · CONTESTED"
	var progress:float=maxf(rules.progress[zone][0],rules.progress[zone][1])
	return " · CAPTURING %.1f / 10s"%progress if progress>0 else ""
func status(id:int) -> String:
	var text:=" · POIs %d : %d"%[rules.held(0),rules.held(1)]
	if not game.fighters.has(id):return text
	for zone in sites.size():
		if game.fighters[id].position.distance_to(sites[zone].position)<12:
			return text+" · "+sites[zone].name.capitalize()+progress_text(zone)
	return text
