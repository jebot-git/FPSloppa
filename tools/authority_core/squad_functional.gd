extends SceneTree
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
var authority
var world:Node3D
var checks:=0
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);push_error(label)
func box(at:Vector3,size:Vector3)->StaticBody3D:
	var body:=StaticBody3D.new();body.position=at;body.collision_layer=1
	var shape:=BoxShape3D.new();shape.size=size;var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);world.add_child(body);return body
func actor(id:int,team:int)->int:
	var body:=CharacterBody3D.new();body.collision_layer=2;body.collision_mask=3
	var shape:=CylinderShape3D.new();shape.radius=.3;shape.height=1.65
	var collider:=CollisionShape3D.new();collider.shape=shape;collider.position.y=.83;body.add_child(collider);world.add_child(body)
	var life:int=authority.attach_actor(id,body,collider,team,1<<2,PackedInt32Array([100,100,100,100]));check(life>0,"Jolt squad actor admitted");return life
func tick(count:int=1):
	for i in count:await physics_frame;check(authority.advance(),"native squad step")
func command(life:int,seq:int)->Dictionary:
	return {"life":life,"seq":seq,"move":Vector2.ZERO,"yaw":0.,"pitch":0.,"weapon":4,"fire":false,"jump":false,"reload":false,"slow":false,"crouch":false,"prone":false,"blocked":false}
func run():
	Engine.physics_ticks_per_second=30
	world=Node3D.new();root.add_child(world);box(Vector3(0,-.5,0),Vector3(1200,1,1200))
	authority=ClassDB.instantiate("FPSAuthority");check(authority.configure_world(world),"cold Jolt squad world")
	check(authority.configure_cq({"squads":true,"map_limit":250.}),"native squad policy enabled");authority.configure_frames(true)
	check(authority.configure_zone(Vector3(-177,0,-144),15.),"insertion-side test POI")
	var first:=actor(1,0);var second:=actor(2,0);var enemy:=actor(3,1)
	await tick(2)
	check(authority.inspect(1).staging and authority.inspect(1).squad==-1,"unassigned actor is staged")
	authority.request_action(1,first,0,12,0,0,0);await tick()
	check(authority.inspect(1).staging,"Jolt authority denies unsquadded spawn")
	authority.request_action(1,first,1,11,0,0,0);authority.request_action(1,first,2,12,0,0,0)
	authority.request_action(3,enemy,0,11,0,0,0);authority.request_action(3,enemy,1,12,0,0,0)
	await tick()
	check(not authority.inspect(1).staging and authority.inspect(1).position.x<0 and authority.inspect(3).position.x>0,"opposite team bases are real Jolt-safe spawns")
	check(authority.squad_roster()=={1:0,2:-1,3:4},"voice roster is authoritative and bounded")
	authority.request_action(2,second,0,11,0,0,0);authority.request_action(2,second,1,12,2,1,first);await tick()
	check(not authority.inspect(2).staging and authority.inspect(2).position.distance_to(authority.inspect(1).position)<5.,"buddy spawn uses a clear nearby Jolt capsule location")
	var decoded:Dictionary=Codec.decode_frame(authority.snapshot())
	check(not decoded.is_empty() and decoded.players[1].squad==0 and decoded.players[3].squad==0,"native squad section decodes with team-local squad IDs")
	var shot:=command(first,0);shot.fire=true;authority.submit(1,shot);await tick()
	check(authority.inspect(1).combat_until>0,"firing updates replicated combat lockout")
	await tick(310)
	decoded=Codec.decode_frame(authority.snapshot());check(decoded.mode.zones[0].owner==0,"capture status reaches deployment snapshot")
	authority.submit(2,command(second,0));authority.request_action(2,second,2,7,0,0,0);await tick()
	check(authority.inspect(2).dead,"native death enters squad deployment flow")
	await tick(170)
	check(authority.inspect(2).dead,"native human waits on deployment map instead of automatic respawn")
	authority.request_action(2,second,3,12,1,0,0);await tick()
	check(not authority.inspect(2).dead and authority.inspect(2).life!=second and authority.inspect(2).squad==0,"controlled POI deployment creates a new squad-preserving life")
	authority=null;world.queue_free();await process_frame;await process_frame
	print("AUTHORITY_SQUAD_FUNCTIONAL ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
