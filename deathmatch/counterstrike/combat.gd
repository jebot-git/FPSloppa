extends RefCounted
const Reload=preload("res://deathmatch/counterstrike/reload_state.gd")
## Clips consume the existing shared ammo pools at fire time. Reloads never create ammo.
var game
var states: Dictionary={}
var view: Dictionary={}
func setup(arena):game=arena
func reset():states.clear();view.clear()
func cancel(id: int):states.erase(id)
func state(id: int) -> Dictionary:
	var s: Dictionary=game.players[id]
	if not states.has(id) or states[id].serial!=s.serial:
		states[id]={"serial":s.serial,"weapon":s.weapon,"clips":{},"modes":{},"physical":{},"reload_at":0.0,"reloading":-1,"alt_held":false,"reload_held":false,"heat":0.0,"shot_at":-10.0,"burst":0,"next_burst":0.0,"burst_until":0.0}
	var c: Dictionary=states[id]
	if c.weapon!=s.weapon:
		if c.physical.has(c.weapon):Reload.interrupt(c.physical[c.weapon])
		c.weapon=s.weapon;c.reloading=-1;c.burst=0;c.heat=0.0;c.erase("spray")
		# Holstering cancels unfinished reloads; the existing clip is retained.
	var d: Dictionary=game.armory.data(s.weapon)
	if d.ammo>=0 and not c.clips.has(s.weapon):c.clips[s.weapon]=mini(d.magazine,s.ammo[d.ammo])
	if d.ammo>=0:c.clips[s.weapon]=mini(c.clips[s.weapon],s.ammo[d.ammo])
	return c
func manual(id: int) -> bool:return id>0 and game.players[id].vr_device and game.players[id].weapon>0
func physical(id: int) -> Dictionary:
	var c:=state(id);var w: int=game.players[id].weapon
	if not c.physical.has(w):c.physical[w]=Reload.make(int(c.clips.get(w,0)))
	c.physical[w].weapon=w
	return c.physical[w]
func supported(id: int) -> bool:
	var s: Dictionary=game.players[id]
	if not s.vr_device:return true
	if s.xr.is_empty() or not s.xr.has("offhand_weapon") or not s.get("reload_grip",false) or s.xr.get("pump",false):return false
	var p:=physical(id)
	if not p.grab.is_empty() or p.carry>0:p.braced=false;return false
	if p.get("braced",false):return true
	var model=preload("res://deathmatch/counterstrike/models.gd")
	var point: Vector3=model.grip(s.weapon)+Vector3(0,0,-.07) if s.weapon in [1,2,10] else model.support(s.weapon)
	var hand: Transform3D=s.xr.right if s.xr.left_handed else s.xr.left
	p.braced=hand.origin.distance_to(Reload.model_pose(s.xr,s.weapon)*point)<.14
	return p.braced
func recoil_scale(id: int) -> float:
	if game.armory.effective()!="cs16" or not game.players[id].vr_device or game.players[id].weapon in [1,2,10] or supported(id):return 1.0
	return 2.0
func reload_sound(id: int,kind: String):
	game._cs_reload_sound.rpc(game.map_epoch,id,int(game.players[id].serial),kind)
func definition(id: int,at_time: float=-1.0) -> Dictionary:
	var s: Dictionary=game.players[id];var d: Dictionary=game.armory.data(s.weapon).duplicate(true)
	var c:=state(id)
	if c.modes.get(s.weapon,false) and d.has("suppressor"):d.merge(d.suppressor,true)
	var shot_time: float=game.clock if at_time<0.0 else at_time
	var heat: float=maxf(0,float(c.heat)-maxf(0,shot_time-float(c.shot_at)-.12)*5.0)
	var motion: float=Vector2(game.fighters[id].velocity.x,game.fighters[id].velocity.z).length()
	var extra: float=0.0 if d.get("shell_reload",false) else minf(4.0,heat)+(.0 if motion<.5 else 1.6)
	if not game.fighters[id].is_supported():extra+=4.0
	if s.weapon==9 and not s.get("weapon_zoom",false):extra+=3.0
	var penalty:=recoil_scale(id)
	# A recovered, stationary shot goes exactly along the sight, including an
	# unscoped AWP. Shotguns and unsupported VR long guns retain their spread.
	if heat==0.0 and motion<.5 and game.fighters[id].is_supported() and not d.get("shell_reload",false) and penalty==1.0:
		d.spread=0.0;d.vertical=0.0;extra=0.0
	d.spread+=extra;d.vertical+=extra
	if s.vr_device:
		d.spread*=penalty;d.vertical*=penalty
		# Sustained recoil climbs above the tracked sight, without moving the palm.
		d.recoil_pitch=minf(4.0,heat)*.35*penalty
	return d
func prepare_spray(id: int,pellets: int):
	# Reserve the random samples after each shot so its recoil can anticipate
	# the next bullet. Movement, stance and recovery are still evaluated at fire.
	var samples: Array[Vector2]=[]
	for pellet in pellets:samples.append(Vector2(randf_range(-1,1),randf_range(-1,1)))
	state(id).spray=samples
func spray_direction(id: int,d: Dictionary,pellet: int) -> Vector3:
	var c:=state(id)
	if not c.has("spray") or c.spray.size()!=int(d.pellets):prepare_spray(id,int(d.pellets))
	var sample: Vector2=c.spray[pellet]
	var accuracy: float=game.fighters[id].accuracy_scale()
	return Vector3(sample.x*tan(deg_to_rad(d.spread*accuracy)),tan(deg_to_rad(float(d.get("recoil_pitch",0.0))))+sample.y*tan(deg_to_rad(d.vertical*accuracy)),-1).normalized()
func begin_reload(id: int) -> bool:
	if manual(id):return false
	var s: Dictionary=game.players[id];var c:=state(id);var d: Dictionary=game.armory.data(s.weapon)
	if d.ammo<0 or c.reloading>=0 or c.burst>0 or s.cooldown>0 or s.ammo[d.ammo]<=c.clips[s.weapon] or c.clips[s.weapon]>=d.magazine:return false
	c.reloading=s.weapon;c.reload_at=game.clock+(.55 if d.get("shell_reload",false) else d.reload);c.heat=0.0
	return true
func tick_input(id: int,_delta: float):
	var s: Dictionary=game.players[id];var c:=state(id);var w: int=s.weapon
	var usp_hands: bool=w==2 and manual(id)
	var alt_requested: bool=s.get("alt_fire",false)
	if s.dead or s.spectator or game.lobby.active() or game.intermission>0 or game.match_mode.special.blocked(id):
		if usp_hands:c.alt_held=alt_requested
		c.reloading=-1;c.burst=0
		if c.physical.has(w):Reload.interrupt(c.physical[w])
		return
	var blocked: bool=s.get("input_blocked",false) or game.clock-s.last_input>.35
	var primary: bool=s.fire and not blocked;var alt: bool=s.get("alt_fire",false) and not blocked
	var reload_pressed: bool=s.get("reload",false) and not blocked
	var d: Dictionary=game.armory.data(w)
	if w==0:
		if not s.vr_device and (primary or alt):
			var previous: bool=s.melee;s.melee=true;game._update_melee_hand(id,false);s.melee=previous
		return
	s.weapon_zoom=w==9 and alt
	var hands:=manual(id)
	if hands:
		c.reloading=-1
		var p:=physical(id);var before:=p.duplicate();var old_clip: int=c.clips[w]
		c.clips[w]=Reload.sample(p,w,c.clips[w],s.ammo[d.ammo],d.magazine,s.xr,s.get("reload_grip",false),reload_pressed,game.clock,not blocked,s.last_input)
		if before.mag and not p.mag:reload_sound(id,"mag_out")
		elif not before.mag and p.mag or Reload.tube_fed(w) and c.clips[w]>old_clip:reload_sound(id,"mag_in")
		if before.stroke<.7 and p.stroke>=.7:reload_sound(id,"rack_back")
		if not before.ready and p.ready:reload_sound(id,"rack_close")
		if not Reload.can_fire(p,w):c.burst=0
		if p.grab!="" or p.cover>.05:alt=false
		# Test both sides of sampling: seating ammo/releasing the slide must
		# not turn that same reload press into a silencer attachment.
		if usp_hands and (reload_pressed or before.grab!="" or before.carry>0 or p.grab!="" or p.carry>0 or not Reload.usp_suppressor_contact(s.xr)):alt=false
	if c.reloading>=0:
		if d.get("shell_reload",false) and primary and c.clips[w]>0:c.reloading=-1
		elif game.clock>=c.reload_at:
			c.clips[w]=mini(mini(c.clips[w]+1,d.magazine) if d.get("shell_reload",false) else d.magazine,s.ammo[d.ammo])
			if d.get("shell_reload",false) and c.clips[w]<mini(d.magazine,s.ammo[d.ammo]):c.reload_at=game.clock+d.reload
			else:c.reloading=-1
	if alt and not c.alt_held and (w==1 or d.has("suppressor")) and c.reloading<0 and s.cooldown<=0 and c.burst==0:
		c.modes[w]=not c.modes.get(w,false);s.cooldown=.3 if w==1 else 2.0
	# Re-entering reach or finishing a reload while held requires a new press.
	c.alt_held=alt_requested if usp_hands else alt
	if not hands and reload_pressed and not c.reload_held:begin_reload(id)
	c.reload_held=reload_pressed
	if blocked:c.burst=0;return
	if c.burst>0 and game.clock>=c.next_burst:
		if shoot(id,true):c.burst-=1;c.next_burst=game.clock+.1
		elif s.cooldown<=0:c.burst=0
	elif primary:shoot(id)
	if not hands and c.clips[w]==0:begin_reload(id)
func shoot(id: int,burst_round: bool=false) -> bool:
	if not game.multiplayer.is_server() or not game.players.has(id):return false
	if game.match_mode.defusal.combat_blocked(id):return false
	var s: Dictionary=game.players[id];var c:=state(id);var w: int=s.weapon
	if w==0:return false # Knife damage belongs exclusively to the shared melee sweep.
	if s.dead or s.spectator or s.cooldown>0 or c.reloading>=0 or s.get("input_blocked",false) or game.intermission>0 or game.lobby.active() or not w in s.owned or game.match_mode.special.blocked(id):return false
	var d:=definition(id)
	if not burst_round and (game.clock<c.burst_until or d.semi and s.held and id>0):return false
	if c.clips[w]<=0 or s.ammo[d.ammo]<=0:return false
	if manual(id) and (s.xr.get("pump",false) or not Reload.can_fire(physical(id),w)):return false
	if game._shot_solution(id).blocked:return false
	# Reuse the authority's trace, rewind, friendly-fire and damage path.
	var loaded: int=c.clips[w]
	if not game.variant_combat.fire(id,false,0.0,true):return false
	c.clips[w]=loaded-1;c.heat=minf(5.0,maxf(0,c.heat-maxf(0,game.clock-c.shot_at-.12)*5.0)+d.bloom);c.shot_at=game.clock;s.held=true
	if manual(id):
		var p:=physical(id)
		if Reload.manual_cycle(w) or c.clips[w]==0:p.ready=false
		if c.clips[w]==0:
			p.locked=true
			if w in [1,2,10]:reload_sound(id,"empty_lock")
	if w==1 and c.modes.get(w,false):
		if not burst_round:c.burst=mini(2,c.clips[w]);c.burst_until=game.clock+.5
		s.cooldown=.1;c.next_burst=game.clock+.1
	prepare_spray(id,int(d.pellets))
	var next_definition:=definition(id,game.clock+s.cooldown)
	var next_direction:=Vector3.ZERO
	for pellet in int(d.pellets):next_direction+=spray_direction(id,next_definition,pellet)
	# Traces/impacts have already been emitted. This payload is the next shot's
	# pose, never a correction that rotates the gun before the current bullet.
	game._variant_shot_fx.rpc(id,w,suppressed(id),next_direction.normalized())
	return true
func falloff(d: Dictionary,damage: int,distance: float) -> int:
	# 500 GoldSrc units -> 12.7 m (one source unit = one inch).
	return maxi(1,roundi(damage*pow(float(d.get("falloff",1)),distance/12.7)))
func row(id: int) -> Array:
	if not game.players.has(id):return []
	var c:=state(id);var s: Dictionary=game.players[id]
	var p: Dictionary=physical(id) if manual(id) else {}
	return [s.serial,s.weapon,int(c.clips.get(s.weapon,0)),maxi(0,roundi((c.reload_at-game.clock)*1000)) if c.reloading>=0 else 0,c.modes.get(s.weapon,false),Reload.flags(p) if not p.is_empty() else 0,roundi(p.stroke*100) if not p.is_empty() else 0,roundi(p.cover*100) if not p.is_empty() else 0,int(p.carry) if not p.is_empty() else 0,roundi(p.lift*100) if not p.is_empty() else 0,roundi(p.belt_progress*100) if not p.is_empty() else 0,int(p.carried_rounds) if not p.is_empty() else 0]
func snapshot() -> Dictionary:
	var rows: Dictionary={}
	for id in game.players:rows[id]=row(id)
	return rows
func receive(rows: Variant):
	view.clear()
	if not rows is Dictionary:return
	for id in rows:
		var r=rows[id]
		if not id is int or not r is Array or r.size()!=Reload.ROW_SIZE or not r[0] is int or not r[1] is int or r[1]<0 or r[1]>11 or not r[2] is int or r[2]<0 or r[2]>100 or not r[3] is int or r[3]<0 or r[3]>6000 or not r[4] is bool:continue
		if not r[5] is int or r[5]<0 or r[5]>Reload.MAX_FLAGS or not r[6] is int or r[6]<0 or r[6]>100 or not r[7] is int or r[7]<0 or r[7]>100 or not r[8] is int or r[8]<0 or r[8]>Reload.REMOVED_MAG:continue
		if not r[9] is int or r[9]<0 or r[9]>100 or not r[10] is int or r[10]<0 or r[10]>100:continue
		if not r[11] is int or r[11]<0 or r[11]>100 or r[8]!=Reload.REMOVED_MAG and r[11]!=0:continue
		view[id]=r.duplicate()
func status(id: int) -> Array:
	var row: Array=row(id) if game.multiplayer.is_server() and not game.demos.playing else view.get(id,[])
	var s: Dictionary=game.players.get(id,{})
	return row if row.size()==Reload.ROW_SIZE and row[0]==s.get("serial",-1) and row[1]==s.get("weapon",-1) else []
func label(id: int) -> String:
	var row:=status(id)
	if row.is_empty():return ""
	var s: Dictionary=game.players[id];var d: Dictionary=game.armory.data(s.weapon)
	if d.ammo<0:return "MELEE"
	var prompt:=""
	if row[5]&Reload.PHYSICAL:
		if row[8]==Reload.REMOVED_MAG:prompt="HELD MAGAZINE: %d"%row[11]
		elif row[5]&Reload.MAG_GRIP:prompt="PULL MAGAZINE CLEAR"
		elif row[5]&Reload.PUMP_HOLD:prompt="GRIP WEAPON TO TAKE BACK" if row[5]&Reload.CHAMBERED else "SWING BACK + FORWARD"
		elif row[5]&Reload.HK_LOCK:prompt="SLAP COCKING HANDLE"
		elif row[8]>0:prompt="LAY BELT ON FEED TRAY" if row[8]==3 else "INSERT SHELL" if row[8]==2 else "BUMP OLD MAGAZINE" if s.weapon==6 and row[5]&Reload.MAGAZINE else "INSERT MAGAZINE"
		elif s.weapon==8 and row[7]>90 and row[2]>0 and not row[5]&Reload.BELT_SEATED:prompt="GRAB + LAY FEED BELT"
		elif row[7]>.0:prompt=("EJECT AMMO BOX" if row[5]&Reload.CHAMBERED or row[2]==0 else "CLOSE FEED COVER") if row[5]&Reload.MAGAZINE else "DRAW AMMO BOX"
		elif not row[5]&Reload.MAGAZINE:prompt="DRAW MAGAZINE"
		elif not row[5]&Reload.CHAMBERED and row[2]>0:prompt="PUMP / SWING" if s.weapon==3 else "RAISE · PULL · CLOSE · LOCK" if s.weapon==9 else "RACK / SIDE FLICK" if s.weapon in [1,2,10] and row[5]&Reload.SLIDE_LOCK else "RACK"
		elif row[2]==0:prompt="DRAW SHELL" if Reload.tube_fed(s.weapon) else "OPEN FEED COVER" if s.weapon==8 else "EJECT MAGAZINE"
	return (prompt+" · " if not prompt.is_empty() else "RELOADING · " if row[3]>0 else "")+"%d / %d"%[row[2],maxi(0,s.ammo[d.ammo]-row[2])]+(" · BURST" if s.weapon==1 and row[4] else " · SEMI" if s.weapon==1 else " · SUPPRESSED" if row[4] else "")
func suppressed(id: int) -> bool:
	var r:=status(id)
	return not r.is_empty() and r[1] in [2,7] and r[4]
