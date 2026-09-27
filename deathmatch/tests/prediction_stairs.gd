extends SceneTree
const Fighter=preload("res://deathmatch/fighter.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures: Array=[]
func _initialize():run.call_deferred()
func run():
	var world:=Node3D.new();root.add_child(world)
	for x in [-10,10]:
		Fixture.box(world,Vector3(x,-.5,0),Vector3(8,1,20))
		for i in 8:Fixture.box(world,Vector3(x,(i+1)*.125,-1.25-i*.5),Vector3(3,(i+1)*.25,.5))
	for latency in [1,3,6]:
		var a:=Fighter.new();a.setup(1,"Client",Color.WHITE);world.add_child(a);a.position=Vector3(10,.01,.8);a.quake_movement=true
		var b:=Fighter.new();b.setup(2,"Server",Color.WHITE);world.add_child(b);b.position=Vector3(-10,.01,.8);b.quake_movement=true
		await physics_frame;await physics_frame
		var packets: Array=[];var snapshots: Array=[];var ack:=-1;var move:=Vector2.ZERO;var impulses:=0;var maximum:=0.0
		for tick in 300:
			await physics_frame
			var command:=Vector2(0,-1 if tick>=12 and tick<70 else 1 if tick>=85 and tick<143 else 0)
			if tick%2==0:packets.append([tick+latency,tick,command])
			a.simulate(command,0,true,1./60.);a.prediction.remember(tick,a.position,a.velocity)
			while not packets.is_empty() and packets[0][0]<=tick:
				var p: Array=packets.pop_front();ack=p[1];move=p[2]
			b.simulate(move,0,true,1./60.)
			if tick%3==0:snapshots.append([tick+latency,ack,b.position+Vector3(20,0,0),b.velocity,b.is_supported()])
			while not snapshots.is_empty() and snapshots[0][0]<=tick:
				var p: Array=snapshots.pop_front();var before:=a.velocity
				a.prediction.reconcile(a,p[1],p[2],p[3],-1,p[4])
				if absf(a.velocity.y-before.y)>.8:impulses+=1
			maximum=maxf(maximum,a.position.y)
		print("STAIR_PREDICTION ",latency," impulses=",impulses," max=",maximum," stats=",a.prediction.stats," end=",a.position)
		if impulses>0 or maximum<1.5 or a.position.y>.1 or a.position.z<0:failures.append(latency)
		a.free();b.free()
	world.free();print("PREDICTION_STAIRS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
