extends Node3D
## Presentation-only state, driven by accepted/predicted shot feedback and charge snapshots.
## Eight reusable positional loops; delayed recovery cues share the bounded effects mixer.
const Profiles=preload('res://deathmatch/audio/weapon-actions/profiles.gd')
const Bank=preload('res://deathmatch/audio/weapon-actions/catalog.gd')
const MAX_LOOPS:=8
const RANGE:=24.0
var game
var mixer
var states:Dictionary={}
var voices:Array=[]
var audio_clock:=0.0
var occlusion_tick:=0.0
func setup(arena:Node,spatial:Node):game=arena;mixer=spatial
func state_for(id:int,rules:String,slot:int,serial:int,where:Vector3) -> Dictionary:
	if states.has(id) and (states[id].rules!=rules or states[id].slot!=slot or states[id].serial!=serial):forget(id)
	if not states.has(id):
		states[id]={'rules':rules,'slot':slot,'serial':serial,'where':where,'profile':Profiles.for_weapon(rules,slot),'until':-1.0,'firing':false,'charged':false,'charge':0.0,'stage':0,'pending':[],'loop':'','selected_at':audio_clock,'charge_block_until':-1.0}
		cue(states[id],states[id].profile.get('select',''))
	states[id].where=where
	return states[id]
func cue(state:Dictionary,name:String):
	if name.is_empty() or not Bank.SOUNDS.has(name):return
	if is_instance_valid(game.camera) and state.where.distance_squared_to(game.camera.global_position)>RANGE*RANGE:return
	mixer.play('action_'+name,state.where,-6)
func shot(id:int,rules:String,slot:int,serial:int,where:Vector3,cycle:float,manual:bool=false):
	if game.headless or game.quitting:return
	var s:=state_for(id,rules,slot,serial,where);var p:Dictionary=s.profile
	if not s.firing:cue(s,p.get('start',''))
	s.firing=true;s.until=audio_clock+maxf(.18,cycle+.07);s.pending.clear()
	# Stale charge snapshots must not restart a loop after release was heard.
	s.charged=false;s.charge=0.0;s.charge_block_until=audio_clock+.16
	if p.has('after') and (not manual or p.get('manual_after',true)):
		s.pending.append({'at':audio_clock+cycle*float(p.get('after_at',.5)),'name':p.after})
func charge(s:Dictionary,value:float):
	value=clampf(value,0,1)
	if audio_clock<s.charge_block_until:return
	var p:Dictionary=s.profile
	if value>0:
		if not s.charged:cue(s,p.get('charge_start',''));s.stage=0
		var stage:int=mini(int(p.get('stages',1))-1,int(value*int(p.get('stages',1))))
		if stage>s.stage and p.has('stage'):cue(s,p.stage)
		s.stage=stage;s.charged=true;s.charge=value
	elif s.charged:
		cue(s,p.get('cancel',''));s.charged=false;s.charge=0.0
func advance(delta:float):
	audio_clock+=delta
	for s in states.values():
		for event in s.pending.duplicate():
			if audio_clock>=event.at:cue(s,event.name);s.pending.erase(event)
		if s.firing and audio_clock>s.until:
			s.firing=false;cue(s,s.profile.get('stop',''))
		if s.charged:s.loop=s.profile.get('charge_loop','')
		elif s.firing:s.loop=s.profile.get('run','')
		else:s.loop=s.profile.get('idle','') if audio_clock-s.selected_at>.4 else ''
func forget(id:int):
	states.erase(id)
	for voice in voices:
		if voice.owner==id:voice.owner=0;voice.wanted='' # Retire with the normal 40 ms fade.
func clear():
	states.clear()
	for voice in voices:
		if is_instance_valid(voice.player):voice.player.stop();voice.player.queue_free()
	voices.clear()
func _physics_process(delta:float):
	if not game or game.headless:return
	if game.quitting or not game.active or game.map_loading or game.menu_open or game.intermission>0 or game.lobby.active() or not is_instance_valid(game.camera):clear();return
	var live:Dictionary={}
	for id in game.players:
		var p:Dictionary=game.players[id]
		if p.dead or p.spectator or not game.fighters.has(id) or game.match_mode.fortress.walkers.mounted(id):continue
		var rules:String=game.match_mode.fortress.art_rules(id,p.weapon)
		var s:=state_for(id,rules,p.weapon,p.serial,game._weapon_transform(id).origin);live[id]=true
		# UT local prediction and replicated charge use the same visual source.
		if rules=='ut99':charge(s,game.variant_combat.visual_charge(id))
	for id in states.keys():
		if not live.has(id):forget(id)
	advance(delta);update_loops(delta)
func update_loops(delta:float):
	var candidates:Array=[]
	for id in states:
		var s:Dictionary=states[id]
		if not s.loop.is_empty() and s.where.distance_squared_to(game.camera.global_position)<RANGE*RANGE:candidates.append(id)
	candidates.sort_custom(func(a,b):return states[a].where.distance_squared_to(game.camera.global_position)<states[b].where.distance_squared_to(game.camera.global_position))
	if candidates.size()>MAX_LOOPS:candidates.resize(MAX_LOOPS)
	for voice in voices:
		if not voice.owner in candidates:voice.wanted=''
	for id in candidates:
		var index:=-1
		for i in voices.size():
			if voices[i].owner==id:index=i;break
		if index<0:
			for i in voices.size():
				if voices[i].wanted.is_empty() and voices[i].gain==0:index=i;break
		if index<0 and voices.size()<MAX_LOOPS:
			var player:AudioStreamPlayer3D=mixer.create_player();mixer.configure(player);player.max_distance=RANGE;player.pitch_scale=1;add_child(player)
			voices.append({'player':player,'owner':id,'wanted':'','current':'','gain':0.0,'blocked':false});index=voices.size()-1
		if index>=0:voices[index].owner=id;voices[index].wanted=states[id].loop
	occlusion_tick+=delta;var probe:=occlusion_tick>=.1
	if probe:occlusion_tick=0
	for v in voices:
		var player:AudioStreamPlayer3D=v.player
		if states.has(v.owner):player.global_position=states[v.owner].where
		# Fade to silence before switching streams. Pool reuse never adds a click.
		var target:=1.0 if not v.wanted.is_empty() and v.wanted==v.current else 0.0
		v.gain=move_toward(v.gain,target,delta*25)
		if v.gain==0 and v.current!=v.wanted:
			player.stop();v.current=v.wanted
			if not v.current.is_empty():player.stream=mixer.choose('action_'+v.current);player.play()
		if probe:v.blocked=mixer.occluded(game.camera.global_position,player.global_position)
		player.volume_db=-6+linear_to_db(maxf(.0001,v.gain))-(10 if v.blocked else 0)
		player.attenuation_filter_cutoff_hz=1800 if v.blocked else 18000
