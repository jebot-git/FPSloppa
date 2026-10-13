extends SceneTree
const Rules=preload("res://deathmatch/conquest/classes/rules.gd")
class Team extends RefCounted:
	var players:Dictionary
	func same_team(a:int,b:int)->bool:return players[a].team==players[b].team
class Host extends Node:
	var players:Dictionary={}
	var clock:=0.0
	var match_mode=Team.new()
var failures:Array=[]
func check(value:bool,label:String)->void:
	print("PASS " if value else "FAIL ",label)
	if not value:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var host:=Host.new();root.add_child(host)
	for id in [1,2,3,4]:host.players[id]={"hp":100,"dead":false,"spectator":false,"team":0 if id!=4 else 1,"fire":false,"alt_fire":false}
	host.match_mode.players=host.players
	var rules:=Rules.new();rules.setup(host)
	rules.choose(1,"scout");rules.spawn(1);rules.choose(2,"medic");rules.spawn(2)
	check(not rules.cloak(2),"Medic cannot cloak")
	check(rules.cloak(1) and rules.cloaked(1),"Scout becomes invisible")
	host.clock=9.99;check(rules.cloaked(1),"Cloak lasts ten seconds")
	host.clock=10;check(not rules.cloaked(1) and not rules.cloak(1),"Expiry preserves thirty-second cooldown")
	host.clock=30;check(rules.cloak(1),"Cloak ready thirty seconds after activation")
	rules.weapon_used(1);check(not rules.cloaked(1),"Weapon use breaks cloak immediately")
	rules.spawn(1);check(not rules.cloak(1),"Respawn cannot reset cloak cooldown")
	check(not rules.incapacitate(3,4,"headshot",false,true,false),"Lethal headshot bypasses incapacitation")
	check(not rules.incapacitate(3,4,"rocket",true,false,false),"Gibbing bypasses incapacitation")
	check(rules.incapacitate(3,4,"carbine",false,false,false),"Ordinary lethal hit incapacitates")
	host.clock+=8;rules.tick(8);check(is_equal_approx(rules.downed[3].remaining,2),"Ten-second bleed timer")
	check(not rules.injection(4,3,.1),"Enemies cannot pause death timer")
	for i in 20:
		host.clock+=.1;rules.injection(2,3,.1);rules.tick(.1)
	check(is_equal_approx(rules.downed[3].remaining,2),"Chest injection pauses remaining death timer")
	host.clock+=.1;rules.tick(.1)
	check(is_equal_approx(rules.downed[3].remaining,1.9) and not rules.injecting.has(3),"Broken contact resumes countdown and resets injection")
	for i in 29:
		host.clock+=.1;rules.injection(2,3,.1);rules.tick(.1)
	check(rules.downed.has(3),"Short injection cannot revive")
	host.clock+=.1;check(rules.injection(2,3,.1) and not rules.downed.has(3) and host.players[3].hp==35,"Three continuous seconds revives")
	check(rules.states[2].xp.medic==75,"Only completed revival awards XP")
	rules.incapacitate(3,4,"carbine",false,false,false)
	host.clock+=10;check(rules.tick(10).size()==1,"Bleedout finalizes exactly once")
	check(rules.tick(1).is_empty(),"Expired incapacitation cannot duplicate kills")
	print("CQ_CLASSES_RESULT ",JSON.stringify(failures));host.free();quit(0 if failures.is_empty() else 1)
