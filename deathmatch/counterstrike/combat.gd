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
		c.weapon=s.weapon;c.reloading=-1;c.burst=0;c.heat=0.0
		# Holstering cancels unfinished reloads; the existing clip is retained.
	var d: Dictionary=game.armory.data(s.weapon)
	if d.ammo>=0 and not c.clips.has(s.weapon):c.clips[s.weapon]=mini(d.magazine,s.ammo[d.ammo])
	if d.ammo>=0:c.clips[s.weapon]=mini(c.clips[s.weapon],s.ammo[d.ammo])
	return c
func manual(id: int) -> bool:return id>0 and game.players[id].vr_device and game.players[id].weapon>0
func physical(id: int) -> Dictionary:
	var c:=state(id);var w: int=game.players[id].weapon
	if not c.physical.has(w):c.physical[w]=Reload.make(int(c.clips.get(w,0)))
	return c.physical[w]
func definition(id: int) -> Dictionary:
	var s: Dictionary=game.players[id];var d: Dictionary=game.armory.data(s.weapon).duplicate(true)
	var c:=state(id)
	if c.modes.get(s.weapon,false) and d.has("suppressor"):d.merge(d.suppressor,true)
	var heat: float=maxf(0,float(c.heat)-maxf(0,game.clock-float(c.shot_at)-.12)*5.0)
	var motion: float=Vector2(game.fighters[id].velocity.x,game.fighters[id].velocity.z).length()
	var extra: float=0.0 if d.get("shell_reload",false) else minf(4.0,heat)+(.0 if motion<.5 else 1.6)
	if not game.fighters[id].is_supported():extra+=4.0
	if s.weapon==9 and not s.get("weapon_zoom",false):extra+=3.0
	d.spread+=extra;d.vertical+=extra
	return d
func begin_reload(id: int) -> bool:
	if manual(id):return false
	var s: Dictionary=game.players[id];var c:=state(id);var d: Dictionary=game.armory.data(s.weapon)
	if d.ammo<0 or c.reloading>=0 or c.burst>0 or s.cooldown>0 or s.ammo[d.ammo]<=c.clips[s.weapon] or c.clips[s.weapon]>=d.magazine:return false
	c.reloading=s.weapon;c.reload_at=game.clock+(.55 if d.get("shell_reload",false) else d.reload);c.heat=0.0
	return true
func tick_input(id: int,_delta: float):
	var s: Dictionary=game.players[id];var c:=state(id);var w: int=s.weapon
	if s.dead or s.spectator or game.lobby.active() or game.intermission>0 or game.match_mode.special.blocked(id):
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
		var p:=physical(id)
		c.clips[w]=Reload.sample(p,w,c.clips[w],s.ammo[d.ammo],d.magazine,s.xr,s.get("reload_grip",false),reload_pressed,game.clock,not blocked)
		if not Reload.can_fire(p,w):c.burst=0
		if p.grab!="" or p.cover>.05:alt=false
	if c.reloading>=0:
		if d.get("shell_reload",false) and primary and c.clips[w]>0:c.reloading=-1
		elif game.clock>=c.reload_at:
			c.clips[w]=mini(mini(c.clips[w]+1,d.magazine) if d.get("shell_reload",false) else d.magazine,s.ammo[d.ammo])
			if d.get("shell_reload",false) and c.clips[w]<mini(d.magazine,s.ammo[d.ammo]):c.reload_at=game.clock+d.reload
			else:c.reloading=-1
	if alt and not c.alt_held and (w==1 or d.has("suppressor")) and c.reloading<0 and s.cooldown<=0 and c.burst==0:
		c.modes[w]=not c.modes.get(w,false);s.cooldown=.3 if w==1 else 2.0
	c.alt_held=alt
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
	if manual(id) and not Reload.can_fire(physical(id),w):return false
	if game._shot_solution(id).blocked:return false
	# Reuse the authority's trace, rewind, friendly-fire and damage path.
	var loaded: int=c.clips[w]
	if not game.variant_combat.fire(id,false,0.0,true):return false
	c.clips[w]=loaded-1;c.heat=minf(5.0,maxf(0,c.heat-maxf(0,game.clock-c.shot_at-.12)*5.0)+d.bloom);c.shot_at=game.clock;s.held=true
	if manual(id):
		var p:=physical(id)
		if Reload.manual_cycle(w) or c.clips[w]==0:p.ready=false
		if c.clips[w]==0:p.locked=true
	if w==1 and c.modes.get(w,false):
		if not burst_round:c.burst=mini(2,c.clips[w]);c.burst_until=game.clock+.5
		s.cooldown=.1;c.next_burst=game.clock+.1
	return true
func falloff(d: Dictionary,damage: int,distance: float) -> int:
	# 500 GoldSrc units -> 12.7 m (one source unit = one inch).
	return maxi(1,roundi(damage*pow(float(d.get("falloff",1)),distance/12.7)))
func row(id: int) -> Array:
	if not game.players.has(id):return []
	var c:=state(id);var s: Dictionary=game.players[id]
	var p: Dictionary=physical(id) if manual(id) else {}
	return [s.serial,s.weapon,int(c.clips.get(s.weapon,0)),maxi(0,roundi((c.reload_at-game.clock)*1000)) if c.reloading>=0 else 0,c.modes.get(s.weapon,false),Reload.flags(p) if not p.is_empty() else 0,roundi(p.stroke*100) if not p.is_empty() else 0,roundi(p.cover*100) if not p.is_empty() else 0,int(p.carry) if not p.is_empty() else 0]
func snapshot() -> Dictionary:
	var rows: Dictionary={}
	for id in game.players:rows[id]=row(id)
	return rows
func receive(rows: Variant):
	view.clear()
	if not rows is Dictionary:return
	for id in rows:
		var r=rows[id]
		if not id is int or not r is Array or r.size()!=9 or not r[0] is int or not r[1] is int or r[1]<0 or r[1]>11 or not r[2] is int or r[2]<0 or r[2]>100 or not r[3] is int or r[3]<0 or r[3]>6000 or not r[4] is bool:continue
		if not r[5] is int or r[5]<0 or r[5]>63 or not r[6] is int or r[6]<0 or r[6]>100 or not r[7] is int or r[7]<0 or r[7]>100 or not r[8] is int or r[8]<0 or r[8]>2:continue
		view[id]=r.duplicate()
func status(id: int) -> Array:
	var row: Array=row(id) if game.multiplayer.is_server() and not game.demos.playing else view.get(id,[])
	var s: Dictionary=game.players.get(id,{})
	return row if row.size()==9 and row[0]==s.get("serial",-1) and row[1]==s.get("weapon",-1) else []
func label(id: int) -> String:
	var row:=status(id)
	if row.is_empty():return ""
	var s: Dictionary=game.players[id];var d: Dictionary=game.armory.data(s.weapon)
	if d.ammo<0:return "MELEE"
	var prompt:=""
	if row[5]&Reload.PHYSICAL:
		if row[8]>0:prompt="INSERT SHELL" if row[8]==2 else "INSERT MAGAZINE"
		elif row[7]>.0:prompt=("EJECT AMMO BOX" if row[5]&Reload.CHAMBERED or row[2]==0 else "CLOSE FEED COVER") if row[5]&Reload.MAGAZINE else "DRAW AMMO BOX"
		elif not row[5]&Reload.MAGAZINE:prompt="DRAW MAGAZINE"
		elif not row[5]&Reload.CHAMBERED and row[2]>0:prompt="PUMP" if s.weapon==3 else "CYCLE BOLT" if s.weapon==9 else "RACK"
		elif row[2]==0:prompt="DRAW SHELL" if Reload.tube_fed(s.weapon) else "OPEN FEED COVER" if s.weapon==8 else "EJECT MAGAZINE"
	return (prompt+" · " if not prompt.is_empty() else "RELOADING · " if row[3]>0 else "")+"%d / %d"%[row[2],maxi(0,s.ammo[d.ammo]-row[2])]+(" · BURST" if s.weapon==1 and row[4] else " · SEMI" if s.weapon==1 else " · SUPPRESSED" if row[4] else "")
func suppressed(id: int) -> bool:
	var r:=status(id)
	return not r.is_empty() and r[1] in [2,7] and r[4]
