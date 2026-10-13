extends SceneTree
const Models=preload("res://deathmatch/conquest/classes/models.gd")
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for id in [0,1,2,3,4,5,8,9,10,11]:
		var model:=Models.weapon(id,"cq_shocktroop");root.add_child(model)
		var handle=model.find_child("ChargingHandle",true,false)
		var magazine=model.find_child("InsertedAmmo",true,false)
		check((handle==null if id in [5,11] else handle!=null) and magazine!=null,"Weapon %d has authored reload parts; launchers omit cocking handles"%id)
		if magazine:
			var rest:Vector3=handle.position if handle else Vector3.ZERO
			Models.animate_reload(model,{"stroke":1.0,"mag":false});check((not handle or handle.position.is_equal_approx(rest+Vector3(0,0,.065))) and not magazine.visible,"Weapon %d rack stroke preserves fitted handle origin"%id)
			Models.animate_reload(model,{"stroke":0.0,"mag":true});check((not handle or handle.position.is_equal_approx(rest)) and magazine.visible,"Weapon %d seats magazine and returns handle"%id)
			var held:=Models.ammunition(model,id);check(held.transform==Transform3D.IDENTITY and held.get_aabb().get_center().length()<.00001,"Weapon %d pouch magazine uses centered authored geometry"%id);held.free()
		if id in [1,9,10]:
			var optic=preload("res://deathmatch/vr/sniper_scope.gd").new();root.add_child(optic);optic.attach(model)
			check(optic.lens!=null and optic.zoom_steps==([1.5] if id==1 else [1.5,3.0,6.0] if id==9 else [2.0,4.0,8.0]),"Weapon %d has functional configured scope"%id);optic.free()
		if id in [5,11]:check(model.find_child("GuidanceMonitor",true,false)!=null,"Weapon %d has integrated monitor readout"%id)
		model.free()
	print("CQ_MODULAR_MODELS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
