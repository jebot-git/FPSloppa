extends SceneTree
const Service=preload("res://deathmatch/bot_service/server.gd")
const State=preload("res://deathmatch/bot_service/state.gd")
const Actions=preload("res://deathmatch/bot_service/actions.gd")
class World extends RefCounted:
	var players: Dictionary={}
	var fighters: Dictionary={}
	var map_epoch:=7
	var clock:=10.0
	var active:=true
var checks:=0
func check(value: bool,label: String):
	checks+=1
	if not value:push_error(label);quit(1)
func _initialize():
	var service=Service.new();var world=World.new();service.game=world;service.limit=2;service.identity="fixture"
	var base: Dictionary={"serial":3,"weapon":2,"owned":[2],"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0}
	for field in State.BOOL_INPUTS:base[field]=false
	world.players={-1000:base.duplicate(true),-1001:base.duplicate(true),42:base.duplicate(true)}
	var now:=Time.get_ticks_msec();service.tickets={10:{"at":now,"owners":{-1000:3}}}
	var packet: Dictionary={"epoch":7,"identity":"fixture","ticket":10,"seq":1,"inputs":{-1000:State.intent(base)},"actions":[]}
	packet.inputs[-1000].move=Vector2(0,-1);packet.inputs[-1000].fire=true
	service.consume(packet,now)
	check(service.accepted==1 and service.leases.has(-1000) and world.players[-1000].fire,"valid delegated bot input")
	service.consume(packet,now);check(service.accepted==1,"duplicate sequence")
	var bad:=packet.duplicate(true);bad.seq=2;bad.inputs={42:State.intent(base)};service.consume(bad,now);check(service.accepted==1,"human identity")
	bad.inputs={-1001:State.intent(base)};service.consume(bad,now);check(service.accepted==1,"unassigned bot")
	bad=packet.duplicate(true);bad.seq=2;bad.epoch=6;service.consume(bad,now);check(service.accepted==1,"previous map")
	bad=packet.duplicate(true);bad.seq=2;bad.inputs[-1000].serial=2;service.consume(bad,now);check(service.accepted==1,"previous life")
	bad=packet.duplicate(true);bad.seq=2;bad.inputs[-1000].yaw=NAN;service.consume(bad,now);check(service.accepted==1,"nonfinite aim")
	bad=packet.duplicate(true);bad.seq=2;bad.inputs[-1000].move=Vector2(2,0);service.consume(bad,now);check(service.accepted==1,"excessive input")
	bad=packet.duplicate(true);bad.seq=2;service.consume(bad,now+351);check(service.accepted==1,"expired state ticket")
	bad.identity="other build";service.consume(bad,now);check(service.accepted==1,"incompatible assets/code")
	check(not Actions.valid("queue_free",[-1000]),"no arbitrary method calls")
	check(not Actions.valid("st_kit",[42]),"no human actions")
	check(not Actions.valid("st_refit",[-1000,"light",["malformed"],"none",true]),"typed equipment requests")
	var swimming:=packet.duplicate(true);swimming.seq=3;swimming.inputs[-1000].swim=Vector3(.6,.6,0);swimming.inputs[-1000].pitch=-PI*.5;service.consume(swimming,now)
	check(world.players[-1000].swim==Vector3(.6,.6,0) and is_equal_approx(world.players[-1000].pitch,-PI*.5),"swimming and downward hammer-jump aim survive the adapter")
	var invalid_swim:=swimming.duplicate(true);invalid_swim.seq=4;invalid_swim.inputs[-1000].swim=Vector3(INF,0,0);var before: int=service.accepted;service.consume(invalid_swim,now);check(service.accepted==before,"nonfinite swimming rejected")
	State.neutral(world.players[-1000]);check(not world.players[-1000].fire and world.players[-1000].move==Vector2.ZERO,"lease neutralisation")
	service.disconnect_worker();check(service.leases.has(-1000),"unauthenticated disconnect cannot reset active AI state")
	service.free();print("BOT_SERVICE_CONTRACTS_PASS checks=",checks);quit()
