extends SceneTree
const Wire=preload("res://deathmatch/tests/native_client_protocol.gd")
const Protocol=preload("res://deathmatch/native/authority_protocol.gd")
const Presentation=preload("res://deathmatch/native/cq_presentation.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func compare(frame:Dictionary,origin:float,epoch:int,duration:float,label:String)->void:
 var before:=frame.duplicate(true)
 var a:Array=Presentation.native_codec.project_authority_frame(frame,origin,epoch,duration)
 var b:Array=Presentation.project_reference(frame,origin,epoch,duration)
 check(not a.is_empty() and not b.is_empty(),"projectable fixture "+label)
 if a!=b:
  for i in mini(a.size(),b.size()):
   if a[i]!=b[i]:print("PRESENTATION_DIFF ",label," index=",i)
 check(a==b,"exact projection parity "+label)
 check(frame==before,"source frame is unchanged "+label)
func _initialize()->void:
 var wire:=Wire.new();var codec=Presentation.native_codec
 check(codec!=null and codec.has_method("project_authority_frame"),"native projector available")
 if failures.size():wire.free();quit(1);return
 for version in [2,3]:
  for count in [1,4,64,128]:
   var frame:=Protocol.decode_frame(wire.fixture(count,version))
   for winner in [-2,-1,0,1]:
    frame.mode.winner=winner;frame.mode.intermission=3. if winner>=-1 else 0.
    for id in frame.players:
     var p:Dictionary=frame.players[id];p.inject_progress=.5;p.injector=101;p.incapacitated=true;p.bleed_remaining=7.;p.designation.active=true;p.designation.until=24.;p.lock_vehicle=77;p.lock_elapsed=1.6;p.charge_at=9.;p.invulnerable=50.;p.respawn_at=30.;p.staging=false
     p["class"].blind_until=2.;p["class"].cloak_until=11.;p["class"].cloak_ready=12.;p["class"].box_ready=13.;p["class"].drone_ready=14.;p["class"].strike_ready=15.;p["class"].turret_ready=16.
     p.vehicle=0;p.vehicle_seat=posmod(id,8)
    compare(frame,123.25,42,600.75,"v%d/%d/w%d"%[version,count,winner])
 var empty:Dictionary=Protocol.decode_frame(wire.fixture(1));empty.players.clear()
 compare(empty,0.,7,0.,"empty roster and optional entities")
 var compact:Dictionary=Protocol.decode_frame(wire.fixture(4))
 for key in ["boxes","vehicles","turrets","fields","flights","grenades"]:compact.erase(key)
 compact.projectiles.clear();compare(compact,-100.,9,12.,"no optional sections")
 check(codec.project_authority_frame({},0,1,0).is_empty(),"missing frame rejected")
 var bad:Dictionary=Protocol.decode_frame(wire.fixture(1));bad.players[100]["class"].role=9
 check(codec.project_authority_frame(bad,0,1,0).is_empty(),"invalid role rejected")
 check(codec.project_authority_frame(empty,NAN,1,0).is_empty(),"nonfinite origin rejected")
 var timings:Array=[]
 for count in [64,128]:
  var frame:=Protocol.decode_frame(wire.fixture(count));var n:=60;var start:=Time.get_ticks_usec()
  for i in n:Presentation.project_reference(frame,123.,42,600.)
  var reference_us:float=(Time.get_ticks_usec()-start)/float(n);start=Time.get_ticks_usec()
  for i in n:codec.project_authority_frame(frame,123.,42,600.)
  timings.append({"players":count,"reference_us":reference_us,"native_us":(Time.get_ticks_usec()-start)/float(n)})
 wire.free()
 print("NATIVE_CLIENT_PRESENTATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"timings":timings}));quit(0 if failures.is_empty() else 1)
