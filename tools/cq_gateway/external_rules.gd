extends SceneTree
const External=preload("res://deathmatch/server/districts/external.gd")
const Gateway=preload("res://deathmatch/server/districts/gateway.gd")
const State=preload("res://deathmatch/server/districts/state.gd")
var checks:=0
var failures: Array=[]
class Peer extends RefCounted:
	var disconnected:=false
	func disconnect_from_host():disconnected=true
class Link extends RefCounted:
	var peer=Peer.new()
	var messages: Array=[]
	func send(value):messages.append(value.duplicate(true))
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label)
	print("PASS " if ok else "FAIL ",label)
func _initialize():call_deferred("run")
func run():
	var path:="user://external-rules.json"
	var data:={"port":39000,"session":"a".repeat(64),"workers":[{"zone":0,"token":"b".repeat(64),"instance":"c".repeat(64)}]}
	write(path,data)
	check(not External.gateway(path,4).has("error"),"Valid fixed district inventory")
	for change in [{"port":0},{"port":39000.5},{"session":"bad"},{"workers":[]},{"workers":[data.workers[0],data.workers[0]]}]:
		var bad:=data.duplicate(true);bad.merge(change,true);write(path,bad);check(External.gateway(path,4).has("error"),"Reject invalid inventory "+str(change.keys()))
	var second: Dictionary=data.workers[0].duplicate();second.zone=1
	for field in ["token","instance"]:
		var bad:=data.duplicate(true);var other:=second.duplicate();other[field]="d".repeat(64);bad.workers.append(other);write(path,bad)
		check(External.gateway(path,4).has("error"),"Reject reused worker "+("instance" if field=="token" else "token"))
	var worker: Dictionary=data.workers[0].duplicate();worker.session=data.session;worker.port=data.port;write(path,worker)
	check(not External.worker(path,0).has("error") and External.worker(path,1).has("error"),"Worker file binds exactly one district")
	var g=Gateway.new();g.external_session=data.session
	g.game={"cq_maps":{"enabled":false},"map_sha":"m","map_epoch":7,"clock":0.0,"match_mode":{"friendly_fire":false}}
	g.workers[0]={"external":true,"pid":0,"token":data.workers[0].token,"instance":data.workers[0].instance,"wire":null,"ready":false}
	var hello:={"kind":"hello","zone":0,"pid":123456789,"token":worker.token,"session":worker.session,"instance":worker.instance,"link":External.PROTOCOL,"version":ProjectSettings.get_setting("application/config/version"),"map":"m","schema":State.SCHEMA}
	for change in [{"session":"d".repeat(64)},{"token":"d".repeat(64)},{"instance":"d".repeat(64)},{"link":"old"},{"version":"other"},{"map":"other"},{"schema":-1},{"pid":"oops"},{"zone":{}},{"zone":15}]:
		var bad:=hello.duplicate();bad.merge(change,true);var link=Link.new();g.connections.append(link);g.handle(link,bad)
		check(link.peer.disconnected and not g.workers[0].ready and not g.connections.has(link),"Reject foreign or malformed worker "+str(change.keys()))
	var accepted=Link.new();g.connections.append(accepted);g.handle(accepted,hello)
	check(g.workers[0].ready and g.workers[0].pid==123456789 and accepted.messages.size()==2,"Accept independently supervised PID and start via master")
	check(accepted.messages[0].session==worker.session and accepted.messages[0].instance==worker.instance,"Welcome binds the master lifetime and worker instance")
	var duplicate=Link.new();g.connections.append(duplicate);g.handle(duplicate,hello)
	check(duplicate.peer.disconnected and g.workers[0].wire==accepted and not accepted.peer.disconnected,"Duplicate district cannot replace live authority")
	g.stop();check(accepted.peer.disconnected,"Master shutdown disconnects external authority without killing a local PID")
	g.free();DirAccess.remove_absolute(path)
	print("EXTERNAL_WORKER_RULES ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
func write(path: String,value: Dictionary):
	var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(value));f.close()
