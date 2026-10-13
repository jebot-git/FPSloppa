extends SceneTree
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Architecture=preload("res://tools/voxel_battle/architecture.gd")
const Map=preload("res://tools/voxel_battle/map.gd")
var errors: Array=[]
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func _initialize() -> void:
	Landscape.prepare_roads()
	check(absf(Landscape.EXTENT*Landscape.EXTENT-8000000)<.1,"exact 8 square kilometre footprint")
	check(absf(Landscape.TILE*Landscape.GRID-Landscape.EXTENT)<.0001,"tiles cover complete world")
	var source:=Landscape.new();var low:=INF;var high:=-INF
	var overview:=Image.create(1024,1024,false,Image.FORMAT_RGB8)
	for z in 1024:
		for x in 1024:
			var v:=Landscape.surface((x+.5)*Landscape.EXTENT/1024-Landscape.EXTENT/2,(z+.5)*Landscape.EXTENT/1024-Landscape.EXTENT/2)
			low=minf(low,v.x);high=maxf(high,v.x)
			var c:=Color(v.y,v.z,v.w);c=c.lightened(clampf(v.x/450,0,.35))
			overview.set_pixel(x,z,c)
	check(low>=Landscape.MIN_HEIGHT and high<Landscape.MAX_HEIGHT,"terrain within culling bounds")
	check(high-low>350,"mountain relief exceeds 350 metres")
	for site in Landscape.FUTURE_SITES:
		var c: Vector3=site.position
		for offset in [Vector2.ZERO,Vector2(site.radius*.8,0),Vector2(0,-site.radius*.8)]:
			check(absf(Landscape.surface(c.x+offset.x,c.z+offset.y).x-c.y)<.001,"future building pad flat "+site.name)
			check(not Landscape.planting_allowed(Vector2(c.x+offset.x,c.z+offset.y)),"future building pad clear "+site.name)
	var totals: Array=[0,0,0]
	for z in range(0,Landscape.GRID,4):
		for x in range(0,Landscape.GRID,4):
			var tile:=Vector2i(x,z);var rows:=Landscape.features(tile)
			check(rows==Landscape.features(tile),"deterministic ecology "+str(tile))
			check(rows.size()<=16,"features bounded per tile")
			for row in rows:
				totals[row.kind]+=1
				check(Landscape.planting_allowed(Vector2(row.position.x,row.position.z)),"ecology clears sites roads water")
	for count in totals:check(count>100,"each jungle plant species present")
	for coord in [Vector2i(0,0),Vector2i(44,44),Vector2i(87,87)]:
		var a: PackedFloat32Array=source.generate_tile(coord).heights.to_float32_array()
		var b: PackedFloat32Array=source.generate_tile(coord+Vector2i.RIGHT).heights.to_float32_array()
		for z in 65:check(absf(a[z*65+64]-b[z*65])<.0001,"seam across expanded tiles")
	var architecture:=Architecture.new();architecture.generate()
	var obstacles: Array=[]
	for row in architecture.render_boxes:
		var center: Vector3=Landscape.CENTERS[row.kind]+row.center
		obstacles.append(AABB(center-row.size*.5,row.size))
	var road_samples:=0
	var embankment_samples:=0
	var bank_drop_max:=0.0
	for road in Landscape.main_roads:
		var steps:=maxi(1,ceili(road.delta.length()/5))
		var side: Vector3=(road.b-road.a).cross(Vector3.UP).normalized();side.y=0
		for i in steps+1:
			var p: Vector3=road.a.lerp(road.b,float(i)/steps);p.y=Landscape.surface(p.x,p.z).x
			var size: Vector3=side.abs()*(road.width*2+.6)+Vector3(1.8,1.3,1.8)
			var bounds:=AABB(p+Vector3(0,.35,0)-Vector3(size.x/2,0,size.z/2),size)
			var clear:=true
			for obstacle in obstacles:
				if bounds.intersects(obstacle):clear=false;break
			check(clear,"all LOD buildings clear road "+str(p));road_samples+=1
		var midpoint: Vector3=road.a.lerp(road.b,.5)
		var relief:=absf(Landscape.natural(midpoint.x,midpoint.z)-midpoint.y)
		var outdoor:=Landscape.water_mask(midpoint.x,midpoint.z)<.01
		for site in Landscape.sites()+Landscape.FUTURE_SITES:
			var radius: float=site.get("radius",90)+25
			if Vector2(midpoint.x-site.position.x,midpoint.z-site.position.z).length()<radius:outdoor=false
		if relief>20 and outdoor and absf(Landscape.surface(midpoint.x,midpoint.z).x-midpoint.y)<2:
			for sign in [-1,1]:
				var bank: Vector3=midpoint+side*sign*(road.width+Landscape.ROAD_SHOULDER+4)
				var drop:=absf(Landscape.surface(bank.x,bank.z).x-midpoint.y)
				check(drop<relief*.30+3,"raised/cut road has broad supporting bank "+str(bank))
				bank_drop_max=maxf(bank_drop_max,drop);embankment_samples+=1
	check(embankment_samples>50,"broad earthworks exercised across elevated roads")
	var curvature: Array=[]
	for start_index in range(10,10+8*36,36):
		var distance:=0.0
		for i in range(start_index,start_index+36):distance+=Landscape.main_roads[i].delta.length()
		var first: Vector3=Landscape.main_roads[start_index].a;var last: Vector3=Landscape.main_roads[start_index+35].b
		var ratio:=distance/Vector2(last.x-first.x,last.z-first.z).length();curvature.append(ratio)
		check(ratio>1.025,"POI connector follows curved intermediate waypoints")
	for lane in Landscape.access_roads:
		var near:=Landscape.nearest_road(Vector2(lane.b.x,lane.b.z),Landscape.road_bins)
		check(absf(near.distance-near.road.width-.9)<.025,"building lane stops at road shoulder")
	var start:=ceili(Landscape.CENTERS[2].z+70)
	for z in range(start,ceili(Map.LIMIT)+1,4):
		var x: float=Landscape.CENTERS[2].x+sin(maxf(0,z-Landscape.CENTERS[2].z-68)*.003)*28
		check(Landscape.water_mask(x,z)>.99,"water connects port to world edge")
		check(absf(Landscape.surface(x,z).x)<.001,"continuous sea level")
		check(Landscape.in_water(Vector3(x,.1,z)),"water remains lethal")
	var output:="res://test-results/jungle-terrain"
	DirAccess.make_dir_recursive_absolute(output);overview.save_png(output+"/terrain-overview.png")
	var report:={"checks":checks,"errors":errors,"area_m2":Landscape.EXTENT*Landscape.EXTENT,"extent_m":Landscape.EXTENT,"elevation_m":[low,high],"future_sites":Landscape.FUTURE_SITES,"feature_totals_sampled":totals,"road_samples":road_samples,"road_earthworks":{"support_samples":embankment_samples,"maximum_bank_drop_m":bank_drop_max,"max_transition_width_m":Landscape.MAX_EARTHWORK,"connector_length_ratios":curvature},"rock_formations":Landscape.ROCK_FORMATIONS.size(),"terrain_rocks":"heightfield formations; no rock mesh species"}
	FileAccess.open(output+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if errors.is_empty() else 1)
