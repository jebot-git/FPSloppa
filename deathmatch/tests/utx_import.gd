extends SceneTree
const UTX=preload("res://deathmatch/avatars/utx.gd")
const Import=preload("res://deathmatch/avatars/skin_import.gd")
const Format=preload("res://deathmatch/avatars/ut_format.gd")
const Library=preload("res://deathmatch/avatars/library.gd")
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var library:=Library.new();root.add_child(library)
	var templates:=library.base_templates()
	check(templates.size()==5,"All five stock UT99 archetypes have prepared templates")
	var packages:={"Soldier":"Soldierskins","Commando":"commandoskins","SGirl":"SGirlSkins","FCommando":"FCommandoSkins","Boss":"BossSkins"}
	for model in packages:
		var package:=UTX.read("res://test-results/ut99/base/source/Textures/"+packages[model]+".utx")
		if package.has("error"):check(false,package.error);continue
		check(Import.recognize(package,templates.keys()).model==model,"Auto-recognition selects "+model+" from its package and layout")
		var template:Dictionary=library.entries[templates[model]]
		var families:=Import.groups(package,model)
		check(not families.is_empty(),"Skin families detected for "+model)
		var face:String=Import.faces(package,model,families[0])[0]
		var output:String="res://test-results/ut99/base/"+model+"/import.utavatar"
		var built:=Import.build(package,template,families[0],face,output)
		check(not built.has("error"),"Build skin for "+model+": "+str(built.get("error","OK")))
		if built.has("error"):continue
		var data:=Format.read(output);var source:=Format.read(template.path)
		check(not data.has("error"),"Imported "+model+" passes server validator")
		if data.has("error"):continue
		check(data.positions==source.positions and data.manifest.ik_weights==source.manifest.ik_weights and equal_profile(data.manifest.ik_profile,source.manifest.ik_profile) and data.manifest.clips==source.manifest.clips,"Skin import preserves "+model+" geometry, IK and every original animation")
		var hash:=library.register_file(output)
		check(not hash.is_empty() and FileAccess.get_sha256(library.entries[hash].path)==hash,"Imported "+model+" is SHA-addressed for existing multiplayer transfer")
		var avatar=library.create_avatar(hash)
		check(avatar!=null,"Imported "+model+" loads into production render rig")
		if avatar:avatar.free()
	var package:=UTX.read("res://test-results/ut99/SoldierSkinsDictator.utx")
	var a:=library.register_skin(package,templates.Soldier,"dics","dics4jong-un")
	var b:=library.register_skin(package,templates.Soldier,"dics","dics4putin")
	var again:=library.register_skin(package,templates.Soldier,"dics","dics4jong-un")
	check(not a.is_empty() and not b.is_empty() and a!=b and a==again,"Different World Leaders faces have distinct hashes; repeat imports are deterministic")

	var renamed:=package.duplicate();renamed.filename="UnknownCustomPack"
	var ambiguous:=Import.recognize(renamed,templates.keys(),"SGirl")
	check(ambiguous.confidence=="ambiguous" and ambiguous.model=="SGirl","Ambiguous layouts retain a compatible selection and report uncertainty")
	var commando:=UTX.read("res://test-results/ut99/base/source/Textures/commandoskins.utx");commando.filename="RenamedPack"
	check(Import.recognize(commando,templates.keys()).model=="Commando","Renamed Commando recognized by face slot 2")
	var female:=UTX.read("res://test-results/ut99/base/source/Textures/FCommandoSkins.utx");female.filename="RenamedPack"
	check(Import.recognize(female,templates.keys()).model=="FCommando","Renamed female Commando recognized by three-slot layout")
	var conflict:=package.duplicate();conflict.filename="FCommandoSkinsCustom"
	conflict.textures={"x1":{},"x3":{},"x4face":{}}
	check(Import.recognize(conflict,templates.keys()).confidence=="unknown","Filename never overrides missing required texture slots")
	check(not Import.groups(package,"SGirl").is_empty(),"Manual model override remains available for compatible texture layouts")
	check(library.register_skin(package,templates.Soldier,"missing","bad").is_empty(),"Incomplete skin family rejected without publication")
	FileAccess.open("res://test-results/ut99/utx-import-result.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"network_fixture":library.entries[a].path if not a.is_empty() else "","hash":a},"  "))
	print("UTX_IMPORT_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)

func equal_profile(a:Variant,b:Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not equal_profile(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in a.size():
			if not equal_profile(a[i],b[i]):return false
		return true
	if (a is float or a is int) and (b is float or b is int):return absf(float(a)-float(b))<1e-12
	return a==b
