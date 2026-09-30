extends RefCounted
## Presentation only: reserve ammunition until an authoritative snapshot includes
## the shot. Effect RPCs can arrive before/after snapshots without double reports.
var life:=-1
var weapon:=-1
var pending:Dictionary={}
var presented:Dictionary={}
var ordinals:Dictionary={}
var cooldowns:Array=[0.0,0.0,0.0]
var results:Array=[]
const Timing=preload("res://deathmatch/network/weapon_timing.gd")
static func key(identity:Array) -> String:return str(identity)
static func counter(hand:int,edge:int) -> String:return str(hand)+":"+str(edge)
func reset() -> void:
 life=-1;weapon=-1;pending.clear();presented.clear();ordinals.clear();cooldowns=[0.0,0.0,0.0];results=[]
func sync(serial:int,slot:int) -> void:
 if serial!=life:reset();life=serial
 if slot!=weapon:
  cooldowns=[0.0,0.0,0.0] if weapon<0 else [.28,.28,.28]
  weapon=slot
func tick(delta:float,command:Dictionary) -> void:
 cooldowns[0]=Timing.advance(cooldowns[0],delta,command.get("fire",false) or command.get("alt_fire",false))
 cooldowns[1]=cooldowns[0]
 cooldowns[2]=Timing.advance(cooldowns[2],delta,command.get("offhand_fire",false))
func reserved(ammo:int) -> int:
 var count:=0
 for shot in pending.values():
  if shot.ammo==ammo:count+=shot.cost
 return count
func reserved_weapon(slot:int) -> int:
 var count:=0
 for shot in pending.values():
  if shot.identity[4]==slot:count+=1
 return count
func predict(serial:int,slot:int,hand:int,edge:int,definition:Dictionary,available:int,now:float,once:bool=false) -> Array:
 sync(serial,slot)
 var k:=counter(hand,edge)
 if pending.size()>=64 or edge<=0 or cooldowns[hand]>0 or once and ordinals.get(k,0)>0:return []
 if definition.ammo>=0 and available-reserved(definition.ammo)<definition.cost:return []
 var ordinal:int=ordinals.get(k,0)+1;ordinals[k]=ordinal
 while ordinals.size()>256:ordinals.erase(ordinals.keys()[0])
 var identity:Array=[serial,edge,ordinal,hand,slot]
 pending[key(identity)]={"identity":identity,"ammo":definition.ammo,"cost":definition.cost,"time":now}
 presented[key(identity)]=now
 while presented.size()>256:presented.erase(presented.keys()[0])
 cooldowns[hand]=Timing.restart(cooldowns[hand],definition.cycle)
 if hand<2:cooldowns[1-hand]=cooldowns[hand]
 return identity
func confirm(identity:Array,cycle:float=0.0) -> bool:
 if identity.size()!=5 or identity[0]!=life:return false
 var k:=key(identity)
 var was_presented:=presented.has(k)
 if not was_presented and cycle>0 and identity[4]==weapon:
  var hand:int=identity[3]
  cooldowns[hand]=maxf(cooldowns[hand],cycle)
  if hand<2:cooldowns[1-hand]=cooldowns[hand]
 var ordinal_key:=counter(identity[3],identity[1])
 ordinals[ordinal_key]=maxi(ordinals.get(ordinal_key,0),identity[2])
 while ordinals.size()>256:ordinals.erase(ordinals.keys()[0])
 presented[k]=0.0
 while presented.size()>256:presented.erase(presented.keys()[0])
 return was_presented
func receive(serial:int,counts:Dictionary,outcomes:Array,now:float) -> void:
 if serial!=life:reset();life=serial
 results=outcomes.duplicate(true)
 for k in counts:ordinals[k]=maxi(ordinals.get(k,0),int(counts[k]))
 while ordinals.size()>256:ordinals.erase(ordinals.keys()[0])
 for k in pending.keys():
  var shot:Dictionary=pending[k];var identity:Array=shot.identity
  if int(counts.get(counter(identity[3],identity[1]),0))>=identity[2]:pending.erase(k);continue
  var rejected:=false
  for outcome in outcomes:
   if outcome[0]==identity[1] and outcome[2]&(1<<identity[3]) and outcome[1]!="fired":rejected=true
  if rejected or now-shot.time>1.0:pending.erase(k)
