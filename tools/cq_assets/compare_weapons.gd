extends SceneTree
## Read current runtime definitions; estimates assume continuous fire and ignore armour.
func _initialize() -> void:
	var armory=preload("res://deathmatch/conquest/classes/armory.gd").new();armory.select("cq")
	var rows:Array=[]
	for pair in [["shocktroop",4,1],["medic",4,3],["scout",9,10],["technician",5,11],["secondary",2,0]]:
		var entry:Dictionary={"class":pair[0],"tiers":[]}
		for w in [pair[1],pair[2]]:
			var d:Dictionary=armory.data(w).duplicate(true);var model:Dictionary=preload("res://deathmatch/conquest/classes/models.gd").metadata(w,"cq_"+pair[0])
			var spare:int=2 if w in [5,11] else 5 if w==9 else 1 if w in [2,0] else 3
			var rate:float=60.0/d.cycle*float(d.get("burst",1))
			d["slot"]=w;d["zoom_steps"]=model.get("zoom_steps",[]);d["spare_packs"]=spare;d["total_ammo"]=d.magazine*(spare+1)
			d["nominal_projectiles_per_minute"]=rate if w not in [5,11] else null
			d["nominal_direct_dps"]=d.damage*rate/60.0 if w not in [5,11] else null
			d["ammo_per_trigger"]=3 if w in [0,5] else 1
			d["internal_reload_seconds"]=d.reload if w==11 else 0.0
			d["salvo_count"]=3 if w==5 else 1
			if w==11:
				d["homing_lock_range"]=preload("res://deathmatch/conquest/classes/vehicle_lock.gd").RANGE;d["homing_lock_seconds"]=preload("res://deathmatch/conquest/classes/vehicle_lock.gd").DWELL
			d["ideal_desktop_sustained_direct_dps"]=float(d.damage*d.magazine)/(d.magazine/float(d.get("burst",1))*d.cycle+d.reload) if w not in [5,11] else float(d.damage*3)/(d.charge_time+2*d.salvo_interval+d.reload) if w==5 else float(d.damage)/d.reload
			entry.tiers.append(d)
		rows.append(entry)
	DirAccess.make_dir_recursive_absolute("res://test-results/weapon-sources")
	FileAccess.open("res://test-results/weapon-sources/class-weapon-stats.json",FileAccess.WRITE).store_string(JSON.stringify({"comparisons":rows},"  "))
	print("CQ_WEAPON_STATS ",JSON.stringify(rows));quit()
