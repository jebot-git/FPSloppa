extends RefCounted
## Opt-in main-thread CPU scopes. Workers must not use this shared recorder.
## Inclusive time contains descendants; self time excludes measured descendants.
static var enabled:=false
static var labels:Dictionary={}
static var names:Array=[]
static var totals:Array=[]
static var stack:Array=[]
static var ticks:Array=[]
static var errors:=0
static func reset() -> void:
	enabled=false;labels.clear();names.clear();totals.clear();stack.clear();ticks.clear();errors=0
static func begin(label:String) -> int:
	if not enabled:return -1
	var index:int=labels.get(label,-1)
	if index<0:
		index=names.size();labels[label]=index;names.append(label);totals.append([0,0,0,0])
	var token:=stack.size();stack.append([index,Time.get_ticks_usec(),0]);return token
static func end(token:int) -> void:
	if token<0:return
	var now:=Time.get_ticks_usec()
	if token!=stack.size()-1:errors+=1;return
	var entry:Array=stack.pop_back();var elapsed:int=now-int(entry[1]);var own:int=maxi(0,elapsed-int(entry[2]));var row:Array=totals[entry[0]]
	row[0]+=1;row[1]+=elapsed;row[2]+=own;row[3]=maxi(row[3],elapsed)
	if not stack.is_empty():stack[-1][2]+=elapsed
static func tick(callback_us:int,players:int) -> void:
	if not enabled:return
	if not stack.is_empty():errors+=1;stack.clear()
	var sample:Array=[]
	for row in totals:
		sample.append(row.duplicate());row[0]=0;row[1]=0;row[2]=0;row[3]=0
	ticks.append({"callback_us":callback_us,"players":players,"scopes":sample})
static func ray(space:PhysicsDirectSpaceState3D,query:PhysicsRayQueryParameters3D,label:String) -> Dictionary:
	var token:=begin(label);var result:=space.intersect_ray(query);end(token);return result
static func shape(space:PhysicsDirectSpaceState3D,query:PhysicsShapeQueryParameters3D,limit:int,label:String) -> Array[Dictionary]:
	var token:=begin(label);var result:=space.intersect_shape(query,limit);end(token);return result
static func cast(space:PhysicsDirectSpaceState3D,query:PhysicsShapeQueryParameters3D,label:String) -> PackedFloat32Array:
	var token:=begin(label);var result:=space.cast_motion(query);end(token);return result
static func summary() -> Dictionary:
	var categories:Dictionary={};var Summary=preload("res://tools/voxel_battle/performance.gd")
	for index in names.size():
		var calls:=0;var inclusive:=0;var own:=0;var maximum:=0;var all_inclusive:Array=[];var all_own:Array=[];var all_calls:Array=[]
		for sample in ticks:
			var row:Array=sample.scopes[index] if index<sample.scopes.size() else [0,0,0,0]
			calls+=int(row[0]);inclusive+=int(row[1]);own+=int(row[2]);maximum=maxi(maximum,int(row[3]))
			all_inclusive.append(row[1]/1000.);all_own.append(row[2]/1000.);all_calls.append(row[0])
		categories[names[index]]={"calls":calls,"inclusive_total_ms":inclusive/1000.,"self_total_ms":own/1000.,"mean_call_ms":inclusive/1000./maxi(1,calls),"max_call_ms":maximum/1000.,"inclusive_per_tick_ms":Summary.summary(all_inclusive),"self_per_tick_ms":Summary.summary(all_own),"calls_per_tick":Summary.summary(all_calls)}
	return {"ticks":ticks.size(),"scope_errors":errors,"categories":categories,"self_times_exclude_measured_children":true,"idle_input_is_carried_into_next_tick":true}
