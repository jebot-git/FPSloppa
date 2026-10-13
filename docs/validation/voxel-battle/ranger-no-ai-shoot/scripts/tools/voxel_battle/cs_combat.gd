extends "res://deathmatch/experimental/combat.gd"
var reloads:=0
func tick_input(id: int,delta: float) -> void:
	var s: Dictionary=game.players[id]
	if s.dead or s.spectator:return
	if s.cs_reload_until>0:
		if game.clock<s.cs_reload_until:return
		var bucket: int=s.cs_reload_ammo
		var amount:=mini(game.armory.max_ammo()[bucket]-s.ammo[bucket],s.cs_reserve[bucket])
		s.ammo[bucket]+=amount;s.cs_reserve[bucket]-=amount;s.cs_reload_until=0.0
	var d: Dictionary=game.armory.data(s.weapon)
	if d.ammo>=0 and s.ammo[d.ammo]<d.cost and s.cs_reserve[d.ammo]>0:
		s.cs_reload_ammo=d.ammo;s.cs_reload_until=game.clock+(2.7 if d.ammo==2 else 2.2)
		s.cooldown=maxf(s.cooldown,s.cs_reload_until-game.clock);reloads+=1;return
	super.tick_input(id,delta)
