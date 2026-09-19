extends SceneTree
const Maps=preload("res://deathmatch/maps/loader.gd")
const Policy=preload("res://deathmatch/maps/import_policy.gd")
const Preview=preload("res://deathmatch/maps/previews.gd")
class Registry extends Node:
	var map_catalog: Array=[]
	var mode_maplists: Dictionary={}
	var match_mode: Dictionary={"kind":"dm"}
	var map_rotation: Array=[]
	var players: Dictionary={}
var failures: Array=[]
var checks: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok});print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run() -> void:
	if not OS.get_cmdline_user_args().has("--asset-root"):
		push_error("Import test requires --asset-root pointing to a temporary directory");quit(1);return
	for mode in ["dm","tdm","ctf","koth","ig","if","ft","cc","tf","tb","as"]:
		check(Policy.modes(mode+"_arena.bsp")==[mode],mode+" prefix selects only its own mode")
	check(Policy.modes("C:\\Downloads\\TF_Arena.BSP")==["tf"],"Prefix classification ignores directories and letter case")
	check(Policy.modes("arena.bsp")==["dm","tdm","ig","ft","if"] and Policy.modes("unknown_arena.bsp")==["dm","tdm","ig","ft","if"],"Untagged and unknown prefixes receive exactly the five requested arena modes")
	check(Policy.modes("my_tf_arena.bsp")==["dm","tdm","ig","ft","if"],"A tag inside the name is not a leading mode tag")
	check(Maps.available_for_mode({"modes":["ig"]},"if") and not Maps.available_for_mode({"modes":["ig"],"imported":true},"if"),"Curated IG compatibility does not leak IG-tagged imports into IF")
	var inherited_rows: Array=[{"id":"base","modes":["ig"]},{"id":"ig_import","modes":["ig"],"imported":true},{"id":"plain","modes":Policy.DEFAULT_MODES,"imported":true}]
	check(Maps.inherited_maplist(inherited_rows,"if",["base","ig_import","plain"])==["base","plain"],"Legacy IF fallback excludes IG-only imports after maplist reload")
	var config=preload("res://deathmatch/server/config.gd")
	var defaults: Dictionary=config.parse('set ig_maplist "qsrc_dm1"').values
	defaults.mode_maps["if"].append("if_extra")
	check(defaults.mode_maps.ig==["qsrc_dm1"],"Legacy IF fallback copies IG without sharing mutable storage")
	var explicit: Dictionary=config.parse('set ig_maplist "qsrc_dm1"\nset if_maplist "if_arena"').values
	check(explicit.mode_maps["if"]==["if_arena"] and explicit.mode_maps.ig==["qsrc_dm1"],"Explicit IF configuration remains separate from IG")
	DirAccess.make_dir_recursive_absolute(Maps.Paths.root())
	var source:=Maps.Paths.root()+"/TF_Preview.v1.bsp"
	var bytes:=FileAccess.get_file_as_bytes("res://maps/qsrc_dm1.bsp");bytes.append_array(" preview policy fixture".to_utf8_buffer())
	var file:=FileAccess.open(source,FileAccess.WRITE);file.store_buffer(bytes);file.close()
	var row:=Maps.import_custom(source)
	check(not row.has("error") and row.get("modes")==["tf"],"BSP importer preserves TF classification under a hash-based id")
	if row.has("error"):print(row);quit(1);return
	var fresh: Dictionary=Maps.catalog().filter(func(entry):return entry.sha256==row.sha256)[0]
	check(fresh.modes==["tf"] and fresh.source_name=="TF_Preview.v1","Fresh catalog preserves original filename and modes")
	check(Maps.import_custom(source).id==row.id,"Repeated imports deduplicate without losing metadata")
	check(Policy.spawn_error("res://maps/tf_ironspan.bsp").is_empty(),"Native team map spawns are accepted by import validation")
	var registry:=Registry.new();root.add_child(registry)
	registry.map_catalog=[{"id":"base","modes":["dm","tdm","ig","ft"],"sha256":"b".repeat(64)},row]
	registry.mode_maplists={"dm":["base"],"tf":["tf_existing"]}
	var uploads=preload("res://deathmatch/maps/uploads.gd").new();registry.add_child(uploads);uploads.setup(registry)
	uploads.register_map(row)
	check(registry.mode_maplists.tf==["tf_existing",row.id] and registry.mode_maplists.dm==["base"],"Import into running DM server updates TF list without changing DM")
	var plain:={"id":"plain","modes":Policy.modes("arena"),"imported":true};registry.map_catalog.append(plain)
	uploads.register_map(plain)
	check(["dm","tdm","ig","ft","if"].all(func(mode):return "plain" in registry.mode_maplists[mode]) and not "plain" in registry.mode_maplists.tf and not registry.mode_maplists.has("ctf"),"Untagged import enters all five arena lists and no objective lists")
	check(registry.map_rotation==registry.mode_maplists.dm,"Current rotation receives eligible imports")
	registry.mode_maplists.koth=Array(range(32)).map(func(index):return "map"+str(index))
	check(uploads.register_map({"id":"overflow","modes":["koth"]})==["koth"] and registry.mode_maplists.koth.size()==32,"Full maplists are reported without exceeding the server limit")
	for frame in 120:
		await process_frame
		if FileAccess.file_exists(Maps.Paths.folder("maps")+"if_maplist.txt"):break
	check(FileAccess.file_exists(Maps.Paths.folder("maps")+"tf_maplist.txt") and FileAccess.get_file_as_string(Maps.Paths.folder("maps")+"tf_maplist.txt").contains(row.id),"Mode maplist persists for server restart")
	var picture:=Image.create(320,180,false,Image.FORMAT_RGB8);picture.fill(Color("438ab3"));var png:=picture.save_png_to_buffer()
	check(Preview.store_png(row.sha256,png) and Preview.decode(Preview.bytes_for(row.sha256))!=null,"Bounded PNG previews persist by map hash")
	var invalid:=png.duplicate();invalid[16]=1
	check(Preview.decode(invalid)==null and Preview.decode(PackedByteArray([1,2,3]))==null and not Preview.store_png("../escape",png),"Invalid dimensions, invalid PNGs and non-hash paths are rejected")
	registry.free()
	DirAccess.make_dir_recursive_absolute("res://test-results/map-previews")
	FileAccess.open("res://test-results/map-previews/policy.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("IMPORTED_MAP_POLICY_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
