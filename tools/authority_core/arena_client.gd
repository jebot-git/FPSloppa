extends "res://tools/voxel_battle/class_arena.gd"
## Full admission/presentation/prediction integration client; no AI or rendering.
signal test_complete(result:Dictionary)
var test_start:=0
var live_start:=0
var phase:=0.
var tracked_test:=OS.get_cmdline_user_args().has("--authority-tracked")
var actions:Dictionary={}
var observed:Dictionary={"native":false,"grenade_selected":false,"grenade_flying":false,"nvg":false,"dead":false,"gibbed":false,"respawn":false,"team_change":false,"jetpack":false,"poses":false,"squad":false}
var first_life:=0
var last_life:=0
var first_team:=-1
var observed_shots:=0
var previous_shots:=0
var completed:=false
func start_join(_player_name:String,address:String,port:int,spectator:bool=false)->void:super.start_join("Native QA",address,port,spectator)
func _ready()->void:
 test_start=Time.get_ticks_msec();super._ready()
func _local_command()->Dictionary:
 var c:Dictionary={"seq":sequence,"fly":0.,"move":Vector2(.1,-.2),"yaw":.3,"pitch":.6,"weapon":players.get(multiplayer.get_unique_id(),{}).get("weapon",4),"fire":phase>.5 and phase<1.5 or phase>3.8 and phase<5.,"slow":false,"respawn":false,"jump":false,"jetpack":phase>14 and phase<14.15,"reload":false,"reload_grip":false,"crouch":false,"prone":phase>5.2 and phase<6.5,"input_blocked":false,"room":Vector3.ZERO,"xr":{},"vr_device":tracked_test,"swim":Vector3.ZERO,"melee":false,"offhand_fire":false,"alt_fire":false}
 if not tracked_test:
  if phase>2.2 and phase<2.95:c.fire=true
  return c
 var head:=Vector3(0,.55 if c.prone else 1.65,0);var right:=Vector3(.3,.35 if c.prone else 1.1,-.3);var left:=Vector3(-.3,right.y,-.3)
 if phase>2.2 and phase<3.1:left.z-=clampf(phase-2.2,0,.7)*.3
 if phase>4.5 and phase<4.7:left=head+Vector3(0,.15,0);c.offhand_fire=true
 var weapon:=Transform3D(Basis(Vector3.RIGHT,.6),right)
 c.xr={"head":Transform3D(Basis.IDENTITY,head),"left":Transform3D(Basis.IDENTITY,left),"right":weapon,"weapon":weapon,"offhand_weapon":Transform3D(Basis.IDENTITY,left),"left_handed":false,"height":.65 if c.prone else 1.65}
 return c
func once(key:String,after:float)->bool:
 if phase<after or actions.has(key):return false
 actions[key]=true;return true
func _physics_process(delta:float)->void:
 if completed:return
 super._physics_process(delta)
 var now:=Time.get_ticks_msec()
 if active and resident.received_tick>0:
  observed.native=true
  if not live_start:live_start=now
  phase=(now-live_start)/1000.
  var state:Dictionary=local_state();var mine:int=multiplayer.get_unique_id()
  if not state.is_empty():
   var serial:int=state.serial
   if not first_life:first_life=serial;first_team=state.team
   if serial!=last_life:previous_shots=0;last_life=serial
   var frame:Dictionary=resident.client_frame
   if frame.get("players",{}).has(mine):
    var p:Dictionary=frame.players[mine];observed.squad=observed.squad or p.get("squad",-1)>=0
    if p.dead and frame.mode.time>=p.respawn_at and once("deploy-life:"+str(p.life),0.):resident.request(12,0)
    if p.staging and phase>10 and once("squad-life:"+str(p.life),0.):resident.request(11,-1);resident.request(12,0)
    observed_shots+=maxi(0,int(p.shots)-previous_shots);previous_shots=p.shots
    observed.grenade_selected=observed.grenade_selected or p.grenade_selected;observed.nvg=observed.nvg or p.nvg;observed.poses=observed.poses or not p.xr.is_empty();observed.jetpack=observed.jetpack or p.get("jetpack",{}).get("mode",0)!=0
   observed.dead=observed.dead or state.dead
   observed.gibbed=observed.gibbed or fighters[mine].gibbed
   observed.respawn=observed.respawn or observed.dead and not state.dead and serial!=first_life
   observed.team_change=observed.team_change or state.team!=first_team
   observed.grenade_flying=observed.grenade_flying or not grenades.flying.is_empty()
  if once("grenade",2.):resident.request(2 if tracked_test else 9)
  if tracked_test and once("throw",3.):resident.request(3)
  if not tracked_test and once("nvg",4.5):night_vision.request()
  if once("suicide",6.5):request_suicide()
  if once("team",11.):votes.switch_team(1-first_team)
  if phase>18:finish_test()
 if now-test_start>65000:finish_test(true)
func finish_test(timeout:bool=false)->void:
 completed=true
 var failures:Array=[]
 for key in ["native","grenade_selected","grenade_flying","nvg","dead","gibbed","respawn","team_change","jetpack","squad"]:
  if not observed[key]:failures.append(key)
 if tracked_test and not observed.poses:failures.append("poses")
 if observed_shots<1:failures.append("shooting")
 if timeout:failures.append("timeout")
 var result:Dictionary={"tracked":tracked_test,"observed":observed,"shots":observed_shots,"tick":resident.received_tick,"failures":failures}
 print("AUTHORITY_ARENA_CLIENT ",JSON.stringify(result));test_complete.emit(result)
