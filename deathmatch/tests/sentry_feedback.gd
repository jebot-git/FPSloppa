extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var game
var failures: Array=[]
class SoundProbe extends Node3D:
 var calls: Array=[]
 func play(kind: String,where: Vector3,volume: float=-8) -> void:calls.append({"kind":kind,"position":where,"volume":volume})
func check(value: bool,label: String) -> void:
 print("PASS " if value else "FAIL ",label)
 if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.set_process(false)
 var path:="res://maps/as_hislop.bsp";var hash:=FileAccess.get_sha256(path)
 game.map_catalog=[{"id":"as_hislop","title":"HiSlop","path":path,"scene":"/tmp/sentry-feedback-map.scn","sha256":hash,"size":FileAccess.open(path,FileAccess.READ).get_length()}]
 game.selected_map="as_hislop";game.start_host("Sentry test",0,20,10,true,"as")
 if not game.active:check(false,"HiSlop map starts");game.free();quit(1);return
 await physics_frame;await physics_frame
 var tf=game.match_mode.fortress
 check(tf.buildings.size()==3,"Published HiSlop loads its three sentries")
 var overlaps:=0;var spare:=0
 for pickup in game.pickups:
  if pickup.kind!="weapon" or pickup.item!=5:continue
  spare+=1
  for b in tf.buildings.values():
   if Vector2(pickup.position.x-b.position.x,pickup.position.z-b.position.z).length()<.8 and absf(pickup.position.y-b.position.y)<1.5:overlaps+=1
 check(overlaps==0 and spare>0,"Legacy BSP mount pickups removed while ordinary chainguns remain")
 Fixture.setup(game)
 var pos:=Fixture.point();tf.buildings={100000:{"owner":0,"team":1,"position":pos,"kind":"sentry","hp":150,"ready":0.0,"next":0.0,"expires":9999.0,"map_owned":true}}
 for id in game.players:
  game.players[id].spectator=true;game.fighters[id].set_physics_process(false)
 var actor=game.fighters[1];var s: Dictionary=game.players[1]
 s.spectator=false;s.dead=false;s.team=0;s.hp=100;s.armor=0;s.invulnerable=0;actor.position=pos+Vector3(3,1,-5)
 await physics_frame
 game.clock=10;tf.tick_sentries();var b: Dictionary=tf.buildings[100000]
 check(s.hp==88 and b.has("aim"),"Visible opponent receives one sentry hit and authoritative aim")
 game.headless=false;tf.draw();game.headless=true
 var mount: Node3D=tf.visuals.b100000;var pivot: Node3D=mount.get_node("SentryGun");var model: Node3D=pivot.get_node("WeaponModel")
 verify_barrel(pivot,model,b.aim,"Initial visual frame")
 actor.position=pos+Vector3(-4,2,2);game.clock+=.11;tf.tick_sentries()
 check(s.hp==88 and b.aim.distance_to(actor.position+Vector3.UP*.825)<.01,"Aim follows moving opponent during firing cooldown")
 game.headless=false;tf.draw();game.headless=true
 verify_barrel(pivot,model,b.aim,"Moving target")
 for target in [pivot.global_position+Vector3.UP*5,pivot.global_position-Vector3.UP*5]:
  tf.aim_sentry(mount,{"aim":target});verify_barrel(pivot,model,target,"Vertical target")
 game.clock+=.4;tf.tick_sentries();check(s.hp==76,"Tracking updates preserve the half-second firing interval")
 actor.position=Fixture.point(12);game.clock+=.6;tf.tick_sentries();check(s.hp==76,"Sentry cannot fire through fixture wall")
 var snapshot: Dictionary=tf.snapshot();tf.receive(snapshot)
 check(tf.buildings[100000].aim==b.aim,"Snapshot preserves barrel target")
 var original=game.spatial;var sound:=SoundProbe.new();game.add_child(sound);game.spatial=sound
 var fx=load("res://deathmatch/modes/fortress_fx.gd").new();game.add_child(fx);fx.game=game
 game.headless=false;fx.emit("sentry_fire",pos,pos+Vector3.FORWARD*3,1);game.headless=true
 check(sound.calls.size()==1 and sound.calls[0].kind=="weapon_5" and sound.calls[0].volume==-4,"Sentry uses normalized player-chaingun gain (8 dB louder)")
 game.spatial=original;fx.free();sound.free()
 print("SENTRY_FEEDBACK_RESULT ",JSON.stringify(failures));game.free();await process_frame;quit(0 if failures.is_empty() else 1)
func verify_barrel(pivot: Node3D,model: Node3D,target: Vector3,label: String) -> void:
 var muzzle: Vector3=model.to_global(game.Art.muzzle(5))
 var direction: Vector3=(target-pivot.global_position).normalized()
 check((-model.global_basis.z.normalized()).dot(direction)>.9999 and (muzzle-pivot.global_position).normalized().dot(direction)>.9999,label+" points the actual muzzle and barrel axis at target")
