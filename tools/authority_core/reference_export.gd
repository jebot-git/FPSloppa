extends SceneTree
const Points=preload("res://deathmatch/conquest/frontier/points.gd")
const Hit=preload("res://deathmatch/hit_detection.gd")
const Jet=preload("res://deathmatch/conquest/jetpack.gd")
class Actor extends RefCounted:
 var jetpack_state:Dictionary=Jet.fresh()
 var velocity:=Vector3.ZERO
 var position:=Vector3.ZERO
 var blast_velocity:=Vector2.ZERO
 var jump_held:=false
 var jetpack_requested:=false
 var jetpack_enabled:=true
 var jetpack_blocked:=false
 var in_water:=false
 var frozen:=false
 var spectator:=false
 var stance:="stand"
 var jump_queued:=false
 var floor_grace:=0
 var stepped_last_frame:=false
 var ceiling:=false
 func is_on_ceiling()->bool:return ceiling
 func is_on_floor()->bool:return position.y<=0
func value(flag:String)->String:
 var args:=OS.get_cmdline_user_args();var at:=args.find(flag);return args[at+1] if at>=0 and at+1<args.size() else ""
func vec(f:FileAccess,v:Vector3)->void:
 f.store_double(v.x);f.store_double(v.y);f.store_double(v.z)
func _initialize()->void:
 var folder:=value("--output");DirAccess.make_dir_recursive_absolute(folder)
 var f:=FileAccess.open(folder.path_join("points.bin"),FileAccess.WRITE);f.store_buffer("CQP1".to_ascii_buffer());f.store_32(12000)
 var rules=Points.new();var rng:=RandomNumberGenerator.new();rng.seed=176043
 for index in 12000:
  var reset:=index%137==0;var count:=1+index/137%11
  if reset:rules.reset(count)
  f.store_8(int(reset));f.store_8(count)
  var delta:float=[0.,.01,1./30,.1,.9,1.,9.99,10.,11.5][index%9];f.store_double(delta)
  var killer:=rng.randi_range(-1,1);f.store_8(killer&255)
  var presence:Array=[]
  for i in count:
   var bits:=rng.randi_range(0,3);presence.append([bool(bits&1),bool(bits&2)]);f.store_8(bits)
  rules.advance(delta,presence)
  if index%5==0:rules.kill(killer)
  f.store_8(int(index%5==0));f.store_16(rules.scores[0]);f.store_16(rules.scores[1]);f.store_8(rules.winner&255)
  for i in count:
   f.store_8(rules.owners[i]&255);f.store_double(rules.progress[i][0]);f.store_double(rules.progress[i][1]);f.store_double(rules.credit[i]);f.store_8(int(rules.contested[i]))
 f.close()
 f=FileAccess.open(folder.path_join("jetpack.bin"),FileAccess.WRITE);f.store_buffer("CQJ1".to_ascii_buffer());f.store_32(16000)
 var actor:=Actor.new();rng.seed=176044
 for index in 16000:
  var reset:=index%317==0
  if reset:actor.jetpack_state=Jet.fresh();actor.position=Vector3.ZERO;actor.velocity=Vector3.ZERO
  var flags:=int(reset)|(int(index%401<370)<<1)|(int(index%257>230)<<2)|(int(index%389>380)<<3)|(int(index%40 in [0,1,4,5])<<4)|(int(index%40 in [1,2,5,6])<<5)|(int(index%199==20)<<6)|(int(index%59==8)<<7)
  actor.jetpack_enabled=bool(flags&2);actor.jetpack_blocked=bool(flags&4);actor.stance="prone" if flags&8 else "stand";actor.jump_held=bool(flags&32);actor.jetpack_requested=bool(flags&64);actor.ceiling=bool(flags&128)
  var dt:float=[1./30,1./60,1./90,.05][index%4];var direction:=Vector3(sin(index*.01),0,cos(index*.017))
  if index%23<5:direction=Vector3.ZERO
  f.store_8(flags);f.store_double(dt);vec(f,direction);vec(f,actor.position);vec(f,actor.velocity)
  var before:=actor.position;var active:bool=Jet.tick(actor,direction,dt,bool(flags&16));actor.position+=actor.velocity*dt
  if actor.position.y<0:actor.position.y=0;actor.velocity.y=0
  if active:Jet.moved(actor,before)
  f.store_8(int(active));vec(f,actor.velocity);vec(f,actor.position);f.store_8(actor.jetpack_state.mode)
  for key in ["age","cooldown","tap","distance","time"]:f.store_double(actor.jetpack_state[key])
  f.store_double(actor.jetpack_state.heading.x);f.store_double(actor.jetpack_state.heading.y);f.store_32(actor.jetpack_state.activation)
 f.close()
 f=FileAccess.open(folder.path_join("bodies.bin"),FileAccess.WRITE);f.store_buffer("CQB1".to_ascii_buffer());f.store_32(18000);rng.seed=176045
 for index in 18000:
  var from:=Vector3(rng.randf_range(-3,3),rng.randf_range(-.5,2.2),rng.randf_range(-4,4));var to:=Vector3(rng.randf_range(-3,3),rng.randf_range(-.5,2.2),rng.randf_range(-4,4))
  var height:=rng.randi_range(65,165)*.01;var yaw:=rng.randf_range(-PI,PI);var radius:float=[0.,.015,.025,.035,.3][index%5]
  vec(f,from);vec(f,to);f.store_double(height);f.store_double(yaw);f.store_double(radius)
  var fraction:float=Hit.player_fraction_reference(from,to,height,yaw,radius);f.store_double(fraction)
  var point:=from.lerp(to,fraction) if is_finite(fraction) else Vector3.ZERO
  f.store_8(int(is_finite(fraction) and Hit.player_head_reference(point,height,yaw,radius)))
 f.close()
 f=FileAccess.open(folder.path_join("anatomy.bin"),FileAccess.WRITE);f.store_buffer("CQA0".to_ascii_buffer());f.store_32(101)
 for key in range(65,166):
  for part in Hit.Body.parts(key*.01):
   var t:Transform3D=part.pose
   for column in [t.basis.x,t.basis.y,t.basis.z,t.origin,part.size*.5]:vec(f,column)
 f.close()
 f=FileAccess.open(folder.path_join("melee.bin"),FileAccess.WRITE);f.store_buffer("CQM1".to_ascii_buffer());f.store_32(6000)
 var melee=preload("res://deathmatch/melee.gd");var state:Dictionary={};var now:=0.;rng.seed=176045
 for index in 6000:
  var reset:=index%137==0
  if reset:state={}
  now+=[.033333333333,.016666666667,.004,.151,.06][index%5] if index%89<5 else 1./30
  var weapon:int=2 if index%233<200 else 4
  var pose:Dictionary={"left_handed":index%211>100,"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"weapon":Transform3D(Basis.from_euler(Vector3(sin(index*.09),sin(index*.13),cos(index*.05))*.4),Vector3(sin(index*.16)*.25,1.2+cos(index*.1)*.1,-.3))}
  if index%181==0:pose.weapon.origin.x+=1
  var result:Dictionary=melee.sample(state,pose,now,weapon)
  f.store_8(int(reset));f.store_double(now);f.store_8(weapon);f.store_8(int(pose.left_handed));vec(f,pose.head.origin)
  for column in [pose.weapon.basis.x,pose.weapon.basis.y,pose.weapon.basis.z,pose.weapon.origin]:vec(f,column)
  f.store_8(int(not result.is_empty()));f.store_8(int(result.get("started",false)))
  for segment in result.get("segments",[]):vec(f,segment[0]);vec(f,segment[1])
 f.close()
 print("AUTHORITY_REFERENCE_EXPORT ",JSON.stringify({"points":12000,"jetpack":16000}));quit()
