extends "res://tools/lighting_experiment/coverage_import.gd"
const AUDIT="res://test-results/bsp-import-audit/"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(AUDIT)
	var rows: Array=[]
	for entry in [
		["ashfall","res://maps/tb_ashfall.bsp",true],
		["external-original","res://test-results/lighting-coverage/external-original.bsp",false],
		["external-optin","res://test-results/lighting-coverage/external-optin.bsp",true],
		["ao-off","res://test-results/lighting-ao/tf_pressureworks-off.bsp",true],
		["ao-low","res://test-results/lighting-ao/tf_pressureworks-low.bsp",true]]:
		var hash:=FileAccess.get_sha256(entry[1]);var node:=Loader.read(entry[1])
		check(node!=null,entry[0]+": fresh import")
		if not node:continue
		var before:=inspect(node)
		check((before.baked_materials>0)==entry[2],entry[0]+": expected baked-light eligibility")
		check(before.invalid==0 and before.overflow==0,entry[0]+": valid atlas bounds")
		var packed:=PackedScene.new();check(packed.pack(node)==OK,entry[0]+": pack")
		var path: String=AUDIT+entry[0]+".scn"
		check(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK,entry[0]+": cache save")
		node.free();packed=null
		var reloaded: PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		node=reloaded.instantiate();check(inspect(node)==before,entry[0]+": cached pixels and materials match fresh import")
		check(FileAccess.get_sha256(entry[1])==hash,entry[0]+": import leaves BSP unchanged")
		rows.append({"id":entry[0],"path":entry[1],"sha256":hash,"inspection":before})
		node.free();print("IMPORT_AUDIT ",JSON.stringify(rows.back()));await process_frame
	check(rows.size()==5,"All five import cases completed")
	if rows.size()==5:
		check(rows[3].inspection.faces==rows[4].inspection.faces,"AO pair retains the same lit-face count")
		check(rows[3].inspection.atlases!=rows[4].inspection.atlases,"Previously baked AO differences survive import and cache reload")
	FileAccess.open(AUDIT+"results.json",FileAccess.WRITE).store_string(JSON.stringify({"maps":rows,"failures":failures,"automatic_light_or_ao_bake":false,"requires_worldspawn_optin":true},"  "))
	print("BSP_IMPORT_AUDIT_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
