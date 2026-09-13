extends "res://deathmatch/modes/fortress.gd"
## Retain the payload and universal stations, disable all TF classes/abilities.
func enabled() -> bool:return false
func structures_enabled() -> bool:return mode.kind=="tb" and not game.lobby.active()
func tick(delta: float) -> void:
 super.tick(delta)
 if multiplayer.is_server():tick_sentries()
func spawn(id: int) -> void:
 super.spawn(id)
 var s: Dictionary=game.players[id]
 s.hp=100;s.armor=100;s.tier=2;s.tf_class="none";s.tf_next="none"
 game.armory.spawn_loadout(s)
func resupply(id: int,delta: float) -> void:
 var s: Dictionary=game.players[id]
 s.hp=mini(100,s.hp+maxi(1,int(20*delta)))
 if not walkers.mounted(id):s.armor=mini(100,s.armor+maxi(1,int(15*delta)))
 for i in 4:s.ammo[i]=mini(game.armory.max_ammo()[i],s.ammo[i]+maxi(1,int([40,10,4,40][i]*delta)))
func snapshot() -> Dictionary:return {"buildings":buildings.duplicate(true),"walkers":walkers.snapshot()}
