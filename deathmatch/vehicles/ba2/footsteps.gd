extends RefCounted
## Cosmetic contact events from replicated travel, matching author_walk.py.
## No extra network messages, physics ticks, or catch-up bursts on joining.
const Tuning=preload("res://deathmatch/vehicles/ba2/tuning.gd")
const CONTACT_PHASE=.20
const FEET=[Vector3(3.8,.4,1.1),Vector3(-3.8,.4,-3.5),Vector3(-3.8,.4,1.1),Vector3(3.8,.4,-3.5)]
var previous:=-1.0
func advance(distance: float,speed: float) -> int:
	var before:=previous;previous=distance
	if before<0 or distance<=before or distance-before>Tuning.STRIDE*.5 or speed<=.015:return -1
	var interval:=Tuning.STRIDE/4.
	var old:=floori((before-Tuning.STRIDE*CONTACT_PHASE)/interval)
	var current:=floori((distance-Tuning.STRIDE*CONTACT_PHASE)/interval)
	return posmod(current,4) if current>old else -1
