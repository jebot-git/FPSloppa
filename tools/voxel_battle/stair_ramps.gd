extends RefCounted
## Authored stair collider substitution. Render meshes are untouched.
## Each flight becomes a thin OBB slab, preserving usable space underneath.
const Architecture=preload("res://tools/voxel_battle/architecture.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
static func key(p:Vector3)->Vector3i:return Vector3i(roundi(p.x*1000),roundi(p.y*1000),roundi(p.z*1000))
static func array(p:Vector3)->Array:return [p.x,p.y,p.z]
static func apply(map)->Dictionary:
	if not map.stair_ramps.is_empty():return map.stair_ramps
	var candidates:Dictionary={};var flights:Array=[];var removed:=0;var visual_hash:int=hash(map.layout.render_boxes)
	for node in map.get_children():
		if node is StaticBody3D and node.get_child_count()==1:
			var child=node.get_child(0)
			if child is CollisionShape3D and child.shape is BoxShape3D and child.shape.size.distance_to(Vector3(2.4,.2,.52))<.001:
				candidates[key(node.position)]=node
	var plans:Array=[]
	for building in map.layout.buildings:
		var base:Vector3=Landscape.CENTERS[building.kind]+building.center;var w:float=building.size.x;var d:float=building.size.y
		for floor_index in int(building.floors)-1:
			var nodes:Array=[]
			for step in 16:
				var p:Vector3=base+Vector3(w*.5-1.5,floor_index*Architecture.STOREY+(step+1)*.2,-d*.5+.5+step*.5)
				var node=candidates.get(key(p))
				if node==null:push_error("Missing exact stair tread at "+str(p));return {}
				nodes.append(node)
			var start:Vector3=base+Vector3(w*.5-1.5,floor_index*Architecture.STOREY+.1,-d*.5+.24)
			var end:Vector3=base+Vector3(w*.5-1.5,(floor_index+1)*Architecture.STOREY+.1,-d*.5+7.9)
			plans.append({"nodes":nodes,"start":start,"end":end,"kind":building.kind,"role":building.role,"floor":floor_index})
	for plan in plans:
		var travel:Vector3=plan.end-plan.start;var angle:float=atan2(travel.y,travel.z);var frame:=Basis(Vector3.RIGHT,-angle)
		var body:=StaticBody3D.new();body.name="StairRamp_%d"%flights.size();body.collision_layer=1
		body.transform=Transform3D(frame,(plan.start+plan.end)*.5-frame.y*.09);map.add_child(body)
		var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2.4,.18,travel.length());collider.shape=box;body.add_child(collider)
		for node in plan.nodes:map.remove_child(node);node.free();removed+=1
		flights.append({"start":array(plan.start),"end":array(plan.end),"kind":plan.kind,"role":plan.role,"floor":plan.floor,"slope_degrees":rad_to_deg(angle),"width":2.4,"slab_thickness":.18})
	assert(hash(map.layout.render_boxes)==visual_hash)
	return {"flights":flights,"removed_treads":removed,"added_ramps":flights.size(),"render_boxes_unchanged":true}
