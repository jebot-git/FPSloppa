extends SceneTree
const Delivery = preload("res://deathmatch/network/input_delivery.gd")
const Bandwidth = preload("res://deathmatch/network/bandwidth.gd")
const Interpolation = preload("res://deathmatch/network/interpolation.gd")
var failures: Array = []
class Actor extends RefCounted:
	var jump_held := true
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func _initialize() -> void:
	var client := Delivery.new(); var actor := Actor.new()
	var s := {"serial":1,"dead":false,"spectator":false,"jump":false}
	var press := {"jump":true}; client.sample(press,1,0)
	var lost := press.duplicate(); client.annotate(lost,0)
	client.sample({"jump":false},1,.016)
	var recovered := {"jump":false}; client.annotate(recovered,.033)
	Delivery.accept(s,recovered)
	check(Delivery.consume(s,actor) and not actor.jump_held,"Lost press is recovered after release; missing release cannot block the edge")
	Delivery.accept(s,recovered)
	check(not Delivery.consume(s,actor),"Repeated event cannot jump twice")
	client.acknowledge(1,s.jump_ack); client.annotate(recovered,.066)
	check(recovered.jump_event==0,"Consumed jump stops retransmission")
	client.sample({"jump":true},1,.1); client.annotate(recovered,.11)
	s.serial=2; Delivery.accept(s,recovered)
	check(not Delivery.consume(s,actor),"Old-life jump cannot replay after respawn")
	client.annotate(recovered,.4); check(recovered.jump_event==0,"Stale press expires after 250 ms")
	s.jump=true
	check(Delivery.consume(s,actor) and Delivery.consume(s,actor),"Held jump remains held for swimming; no synthetic release")
	var accepted := 0
	for i in 100:
		if client.allow(42,0): accepted += 1
	check(accepted==12 and client.allow(42,.1),"Input decode rate is bounded and recovers")
	var interpolation := Interpolation.new()
	interpolation.push(2,10,Vector3.ZERO,Vector3.RIGHT,0,1,0)
	interpolation.push(2,10.1,Vector3.RIGHT,Vector3.RIGHT,1,1,.1)
	interpolation.advance(.125)
	var sample := interpolation.sample(2)
	check(sample.position.x>.4 and sample.position.x<.6,"Remote body samples a timestamped interval")
	interpolation.push(2,10.05,Vector3(99,0,0),Vector3.ZERO,0,1,.13)
	check(interpolation.sample(2).position.x<1,"Reordered old position cannot reset current body")
	interpolation.push(2,10.2,Vector3(20,0,0),Vector3.ZERO,0,2,.2)
	check(interpolation.sample(2).position.x==20,"Respawn clears interpolation across lives")
	interpolation.advance(20)
	check(interpolation.sample(2).position.x==20,"Missing packets cannot extrapolate through walls")
	check(interpolation.render_time<=interpolation.server_time,"Lag compensation cannot advance beyond the latest rendered server sample")
	for i in 100: interpolation.push(2,11+i*.05,Vector3(i*.1,0,0),Vector3.RIGHT,0,2,1+i*.05)
	check(interpolation.tracks[2].size()<=12,"Interpolation history is bounded")
	var budget := Bandwidth.new()
	check(budget.claim(1,32768,0)==32768 and budget.claim(2,32768,0)==32768 and budget.claim(3,32768,0)==0,"Map and model senders share one bounded burst")
	budget.reserve(65536,.02)
	check(budget.claim(1,32768,.02)==0,"Gameplay reservation defers bulk upload")
	budget.reset(); budget.claim(1,32768,0,16)
	check(budget.claim(1,32768,.1,16)==0 and budget.claim(1,32768,.15,16)==32768,"Per-peer share prevents a fast client monopolizing aggregate budget")
	check(budget.claim(2,32768,1,1,50,65536)==0,"Outstanding map/model bytes share one queue bound")
	budget.reset()
	check(budget.claim(2,32768,0,1,0,60000)==5536,"Partial final window cannot exceed the combined queue limit")
	print("NETWORK_DELIVERY_RESULT ",JSON.stringify(failures)); quit(0 if failures.is_empty() else 1)
