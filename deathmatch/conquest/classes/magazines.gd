extends RefCounted
## CS clips and manual reload gestures, adapted to CQ cell/pack/magazine geometry.
const Reload=preload("res://deathmatch/conquest/classes/reload_state.gd")
var host:WeakRef
var game:
	get:return host.get_ref()
var states:Dictionary={}
func setup(arena) -> void:host=weakref(arena)
func state(id:int) -> Dictionary:
	var s:Dictionary=game.players[id]
	if not states.has(id) or states[id].serial!=s.serial:states[id]={"serial":s.serial,"weapon":s.weapon,"clips":{},"physical":{},"reloading":-1,"reload_at":0.0,"reload_held":false}
	var c:Dictionary=states[id]
	if c.weapon!=s.weapon:
		if c.physical.has(c.weapon):Reload.interrupt(c.physical[c.weapon])
		c.weapon=s.weapon;c.reloading=-1
	var d:Dictionary=game.armory.data(s.weapon)
	if d.ammo>=0:
		if not c.clips.has(s.weapon):c.clips[s.weapon]=mini(d.magazine,s.ammo[d.ammo])
		c.clips[s.weapon]=mini(c.clips[s.weapon],s.ammo[d.ammo])
	return c
func geometry(w:int) -> int:return 12 if w==5 else 2 if w in [2,9] else 7
func tick(id:int) -> bool:
	var s:Dictionary=game.players[id];var c:=state(id);var w:int=s.weapon;var d:Dictionary=game.armory.data(w)
	if d.ammo<0:return true
	var blocked:bool=s.get("input_blocked",false) or game.clock-s.last_input>.35 or not game.classes.alive(id)
	if blocked:
		c.reloading=-1
		if c.physical.has(w):Reload.interrupt(c.physical[w])
		return false
	var reload_pressed:bool=s.get("reload",false)
	if s.vr_device:
		c.reloading=-1
		if not c.physical.has(w):c.physical[w]=Reload.make(c.clips[w])
		var p:Dictionary=c.physical[w];p.weapon=geometry(w)
		c.clips[w]=Reload.sample(p,geometry(w),c.clips[w],s.ammo[d.ammo],d.magazine,s.xr,s.get("reload_grip",false),reload_pressed,game.clock,true,s.last_input)
		return c.clips[w]>0 and Reload.can_fire(p,geometry(w))
	if c.reloading>=0 and game.clock>=c.reload_at:c.clips[w]=mini(d.magazine,s.ammo[d.ammo]);c.reloading=-1
	if c.reloading<0 and (c.clips[w]==0 or reload_pressed and not c.reload_held) and c.clips[w]<mini(d.magazine,s.ammo[d.ammo]) and s.cooldown<=0:
		c.reloading=w;c.reload_at=game.clock+d.reload
	c.reload_held=reload_pressed
	return c.reloading<0 and c.clips[w]>0
func consume(id:int,count:int=1) -> void:
	var c:Dictionary=states[id];var w:int=game.players[id].weapon;c.clips[w]=maxi(0,c.clips[w]-count)
	if c.physical.has(w) and c.clips[w]==0:c.physical[w].ready=false;c.physical[w].locked=true
func loaded(id:int) -> int:
	var c:=state(id);return c.clips.get(game.players[id].weapon,0)
func snapshot() -> Dictionary:
	var result:Dictionary={}
	for id in states:
		var c:Dictionary=states[id];result[id]={"serial":c.serial,"weapon":c.weapon,"clips":c.clips.duplicate(),"reloading":c.reloading,"reload_at":c.reload_at,"physical":{}}
		for w in c.physical:
			var p:Dictionary=c.physical[w];result[id].physical[w]={"mag":p.mag,"ready":p.ready,"carry":p.carry,"stroke":p.stroke,"locked":p.locked}
	return result
