extends SceneTree
## Isolated arithmetic benchmark: the production rounded-box collision function.
const Hits=preload("res://deathmatch/hit_detection.gd")
func _initialize() -> void:
	var output:="res://test-results/native-study"
	DirAccess.make_dir_recursive_absolute(output)
	var rng:=RandomNumberGenerator.new();rng.seed=20260928
	var starts:=PackedVector3Array();var ends:=PackedVector3Array();var sizes:=PackedVector3Array();var radii:=PackedFloat64Array()
	for i in 30000:
		# Mixed misses, crossings, initial overlaps, stationary and axis-parallel rays.
		var scale:=3.0 if i%3==0 else .6
		var start:=Vector3(rng.randf_range(-scale,scale),rng.randf_range(-scale,scale),rng.randf_range(-scale,scale))
		var end:=Vector3(rng.randf_range(-scale,scale),rng.randf_range(-scale,scale),rng.randf_range(-scale,scale))
		if i%11==0:end=start
		if i%13==0:end.x=start.x;end.y=start.y
		starts.append(start);ends.append(end);sizes.append(Vector3(.275,.29,.16));radii.append(0.0 if i%2==0 else .15)
	var samples: Array=[];var checksum:=0.0;var contacts:=0
	for trial in 6:
		var before:=Time.get_ticks_usec();checksum=0;contacts=0
		for i in starts.size():
			var value:=Hits.box_fraction(starts[i],ends[i],sizes[i],radii[i])
			if is_finite(value):checksum+=value;contacts+=1
		if trial>0:samples.append((Time.get_ticks_usec()-before)/1000.0)
	var file:=FileAccess.open(output+"/boxes.bin",FileAccess.WRITE)
	file.store_32(starts.size())
	for i in starts.size():
		for vector in [starts[i],ends[i],sizes[i]]:
			for axis in 3:file.store_float(vector[axis])
		file.store_double(radii[i]);file.store_double(Hits.box_fraction(starts[i],ends[i],sizes[i],radii[i]))
	file.close()
	var report:={"engine":Engine.get_version_info().string,"cases":starts.size(),"warmup_passes":1,"milliseconds":samples,"contacts":contacts,"checksum":checksum,"scope":"Production GDScript box_fraction; synthetic mixed cases; no engine collision or extension boundary."}
	FileAccess.open(output+"/gdscript-box.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("GDSCRIPT_BOX ",JSON.stringify(report));quit()
