extends SceneTree
const Library=preload("res://deathmatch/avatars/library.gd")
const Cache=preload("res://deathmatch/avatars/runtime_cache.gd")
var checks:=0
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label)
	print("PASS " if ok else "FAIL ",label)
func run():
	var library=Library.new()
	var base:=PackedScene.new();var node:=Node3D.new();var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();var material:=StandardMaterial3D.new();material.albedo_color=Color.RED;mesh.material_override=material;node.add_child(mesh);mesh.owner=node;assert(base.pack(node)==OK);node.free()
	var alive:Array=[]
	for i in 10:
		var key:=str(i);library.remember_scene(key,base);var rig:=Node3D.new();alive.append(rig);library.track_instance(key,rig)
	library.prune_scenes();check(library.scenes.size()==10,"All ten active decoded scenes survive the old four-entry limit")
	for rig in alive:rig.free()
	library.prune_scenes();check(library.scenes.size()==4,"Only four inactive scenes remain")
	check(library.scenes.has("9") and not library.scenes.has("0"),"Inactive eviction follows last use")
	library.pinned=["pinned"]
	library.remember_scene("pinned",base)
	for i in 8:library.remember_scene("idle"+str(i),base)
	library.prune_scenes();check(library.scenes.has("pinned"),"Join preparation retains pinned models")
	library.free()
	var cache:=Cache.new();cache.directory="/tmp/fps-avatar-cache-regressions-"+Crypto.new().generate_random_bytes(8).hex_encode();root.add_child(cache)
	var hash:="sample".sha256_text()
	check(cache.path_for(hash,true)!=cache.path_for(hash,false),"Surface-compiler options change cache identity")
	check(cache.path_for(hash,true)!=cache.path_for("other".sha256_text(),true),"VRM content changes cache identity")
	var remap_target:=cache.directory+"-compiled.gdc";var remap_file:=cache.directory+"-source.gd.remap"
	var compiled:=FileAccess.open(remap_target,FileAccess.WRITE);compiled.store_string("version-one");compiled.close()
	var remap:=ConfigFile.new();remap.set_value("remap","path",remap_target);remap.save(remap_file)
	var old_fingerprint:=Cache.file_fingerprint(remap_file)
	compiled=FileAccess.open(remap_target,FileAccess.WRITE);compiled.store_string("version-two");compiled.close()
	check(Cache.file_fingerprint(remap_file)!=old_fingerprint,"Exported bytecode changes invalidate a stable remap path")
	var fingerprint:=Cache.fingerprint();var old_path:=cache.path_for(hash,true);Cache.fingerprint_value="changed"
	check(old_path!=cache.path_for(hash,true),"Importer/engine revision invalidates derived scenes");Cache.fingerprint_value=fingerprint
	cache.store(hash,true,base)
	var isolated=cache.snapshot.instantiate();var copy_material=isolated.get_child(0).material_override
	material.albedo_color=Color.BLUE
	check(copy_material!=material and copy_material.albedo_color==Color.RED,"Writer snapshot is isolated from live material changes")
	isolated.free()
	while cache.writer.is_started():await process_frame
	check(cache.stats.writes==1 and FileAccess.file_exists(old_path),"Background write publishes an atomic completed scene")
	var response:Dictionary=cache.request(hash,true)
	while response.status=="pending":await process_frame;response=cache.request(hash,true)
	check(response.status=="ready","Threaded cache load completes")
	if response.status=="ready":
		var loaded=response.scene.instantiate();check(loaded.get_child(0).material_override.albedo_color==Color.RED,"Saved scene retains pre-runtime material state");loaded.free()
	var bad_hash:="corrupt".sha256_text();var corrupt:=FileAccess.open(cache.path_for(bad_hash,true),FileAccess.WRITE);corrupt.store_string("truncated");corrupt.close()
	check(cache.request(bad_hash,true).status=="miss" and not FileAccess.file_exists(cache.path_for(bad_hash,true)),"Truncated cache entry is discarded for VRM fallback")
	var tiny_dir:=cache.directory.path_join("bounded");var result:=Cache.save_scene(base,tiny_dir.path_join("a.scn"),1)
	check(not result.ok and DirAccess.get_files_at(tiny_dir).is_empty(),"Oversize save publishes nothing and removes its temporary file")
	var hashes:Array=[]
	for i in 3:
		var key:=str(i).sha256_text();hashes.append(key);assert(ResourceSaver.save(base,cache.path_for(key,true))==OK)
	cache.request(hashes[0],true);cache.request(hashes[1],true)
	var deadline:=Time.get_ticks_msec()+5000;response=cache.request(hashes[2],true)
	while response.status=="pending" and Time.get_ticks_msec()<deadline:await process_frame;response=cache.request(hashes[2],true)
	check(response.status=="ready","Abandoned previews release load slots for the next request")
	var writes_before:int=cache.stats.writes
	for i in 6:
		cache.store(("burst"+str(i)).sha256_text(),true,base)
		check(cache.write_queue.size()<=2,"Background write queue stays bounded")
	while cache.writer.is_started():await process_frame
	check(cache.stats.writes>writes_before,"Queued cache writes complete")
	check(Array(DirAccess.get_files_at(cache.directory)).filter(func(file):return ".tmp-" in file).is_empty(),"Completed queue leaves no partial files")
	cache.free();await process_frame
	var recovery=Library.new();root.add_child(recovery);recovery.entries.clear()
	var source:="res://vrm/sample_d.vrm";var content:=FileAccess.get_sha256(source)
	recovery.entries[content]={"path":source}
	var recovery_cache=recovery.runtime_cache();recovery_cache.directory="/tmp/fps-avatar-cache-recovery-"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(recovery_cache.directory)
	assert(ResourceSaver.save(base,recovery_cache.path_for(content,true))==OK)
	while not recovery.prepare_avatar(content):await process_frame
	var recovered=recovery.create_avatar(content)
	check(recovered!=null and recovered.skeleton.get_bone_count()>100,"Readable but invalid cached scene falls back to the original VRM")
	if recovered:recovered.free()
	while recovery_cache.writer.is_started():await process_frame
	check(recovery_cache.rejected.is_empty(),"A successfully rebuilt entry clears its rejection")
	var vrm1:="res://vrm/AsiaCarrera-FemaleCommando-AsiaBots-experimental.vrm"
	var vrm1_hash:=FileAccess.get_sha256(vrm1);recovery.entries[vrm1_hash]={"path":vrm1}
	check(Library.inspect(vrm1).version=="1.0","Roundtrip fixture is actual VRM 1.0")
	var imported=recovery.create_avatar(vrm1_hash);assert(imported)
	var original_bones:int=imported.skeleton.get_bone_count();var original_scale:float=imported.scale_factor;imported.free()
	while recovery_cache.writer.is_started():await process_frame
	recovery.scenes.erase(vrm1_hash)
	while not recovery.prepare_avatar(vrm1_hash):await process_frame
	var reopened=recovery.create_avatar(vrm1_hash)
	check(reopened!=null and reopened.skeleton.get_bone_count()==original_bones and is_equal_approx(reopened.scale_factor,original_scale),"VRM 1.0 humanoid and scale survive persistent-cache reload")
	if reopened:reopened.free()
	recovery.free();await process_frame
	var report={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/avatar-cache/regressions.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("AVATAR_RUNTIME_CACHE_RESULT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
