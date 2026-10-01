extends SceneTree
## Enumerate actual mixer routes, including imported .res clips and alt aliases.
func _initialize():run.call_deferred()
func run():
	var args:=OS.get_cmdline_user_args()
	if args.is_empty():quit(2);return
	var out: String=args[0];DirAccess.make_dir_recursive_absolute(out)
	var mixer=preload("res://deathmatch/audio/spatial.gd").new();root.add_child(mixer);mixer.prewarm()
	var rules=preload("res://deathmatch/experimental/weapon_rules.gd").new()
	var requests: Dictionary={};var rows: Dictionary={}
	for set_name in rules.IDS:
		rules.select(set_name)
		for slot in rules.table.size():
			for alt in [false,true]:
				var kind: String=("weapon_" if set_name=="doom" else set_name+"_weapon_")+str(slot)+("_alt" if alt and set_name!="doom" else "")
				requests[kind]=float(rules.data(slot,alt).cycle)
	for kind in ["explosion","quake_explosion","quake_bounce","ut99_explosion","ut99_bounce","ut99_combo","tribes_explosion","tribes_bounce"]:requests[kind]=.7 if "explosion" in kind or "combo" in kind else .2
	requests.flamethrower=.12
	for kind in ["cs_reload_mag_out","cs_reload_mag_in","cs_reload_rack_back","cs_reload_rack_close","cs_reload_empty_lock","de_snip"]:requests[kind]=.3
	for kind in requests:
		var streams: Array=[]
		if kind=="weapon_0":
			# The mixer randomly chooses these at runtime; enumerate its warmed
			# cache so a calibration run can never miss a random variation.
			for path in mixer.cache:
				if path.begins_with("res://deathmatch/audio/recorded/impactPunch_heavy_"):streams.append(mixer.cache[path])
		else:
			for take in maxi(1,mixer.ModeSounds.SOUNDS.get(kind,[]).size()):streams.append(mixer.choose(kind))
		for stream in streams:
			if not stream:push_error("Missing weapon audio: "+kind);quit(1);return
			var path: String=stream.resource_path
			if not rows.has(path):
				var decoded: String=ProjectSettings.globalize_path(path)
				if path.ends_with(".res"):
					if not stream is AudioStreamWAV:push_error("Cannot decode "+path);quit(1);return
					decoded=out.path_join(path.md5_text()+".wav")
					if stream.save_to_wav(decoded)!=OK:push_error("Cannot export "+path);quit(1);return
				rows[path]={"path":path,"decoded":decoded,"cycle":requests[kind],"kinds":[]}
			rows[path].cycle=minf(rows[path].cycle,requests[kind])
			if not kind in rows[path].kinds:rows[path].kinds.append(kind)
	FileAccess.open(out.path_join("inventory.json"),FileAccess.WRITE).store_string(JSON.stringify(rows.values(),"  "))
	print("WEAPON_AUDIO_INVENTORY ",rows.size()," unique streams, ",requests.size()," routes")
	mixer.free();quit()
