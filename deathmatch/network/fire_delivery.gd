extends RefCounted
## Bounded, retransmitted trigger edges. Receipt is distinct from a firing result.
const FIELDS=["fire","alt_fire","offhand_fire"]
const CAPACITY=8
const EXPIRY=.25
const BUFFER=.12
const Poses=preload("res://deathmatch/vr/poses.gd")
var life:=-1
var weapon:=-1
var held:=0
var event:=0
var pending:Array=[]
var active:Array=[0,0,0]
var stats:={"attempts":0,"expired":0,"overflow":0}
func reset() -> void:
 life=-1;weapon=-1;held=0;event=0;pending=[];active=[0,0,0]
func sample(command:Dictionary,serial:int,now:float) -> void:
 if serial!=life:reset();life=serial
 if weapon!=command.weapon:weapon=command.weapon;held=0;pending=[];active=[0,0,0]
 var mask:=0
 if not command.get("input_blocked",false):
  for i in 3:
   if command.get(FIELDS[i],false):mask|=1<<i
 var edges:=mask&~held;held=mask
 if edges:
  event+=1;stats.attempts+=1
  var pose:Dictionary=Poses.gameplay(command.get("xr",{}))
  pose.erase("face")
  var aim:Dictionary={"yaw":command.get("yaw",0.0),"pitch":command.get("pitch",0.0),"view_time":command.get("view_time",-1.0)}
  if command.has("xr"):aim.xr=pose
  if pending.size()>=CAPACITY:pending.pop_front();stats.overflow+=1
  pending.append({"edge":[event,weapon,edges],"aim":aim,"expires":now+EXPIRY})
  for i in 3:
   if edges&(1<<i):active[i]=event
 if command.get("input_blocked",false):pending=[]
 var count:=pending.size()
 pending=pending.filter(func(p):return now<=p.expires)
 stats.expired+=count-pending.size()
func annotate(command:Dictionary,now:float) -> void:
 var rows:Array=[]
 for p in pending:
  if now<=p.expires:rows.append([p.edge,p.aim,clampf(p.expires-now,0,EXPIRY)])
 if not rows.is_empty():
  command.fire_events=rows
  command.fire_event=rows[0][0] # Also understood by offline fixtures.
 command.fire_active=active.duplicate()
func acknowledge(serial:int,value:int) -> void:
 if serial==life:pending=pending.filter(func(p):return p.edge[0]>value)
static func sync_life(state:Dictionary) -> void:
 if state.get("fire_event_life",-1)!=state.serial:
  state.fire_event_life=state.serial;state.fire_received=0;state.fire_ack=0;state.fire_pending=[]
  state.fire_queue=[];state.fire_active=[0,0,0];state.fire_ordinals={};state.fire_results=[];state.shot_context={}
static func result(state:Dictionary,edge:int,status:String,mask:int=1) -> void:
 for i in state.fire_results.size():
  if state.fire_results[i][0]==edge and state.fire_results[i][2]==mask:
   state.fire_results[i]=[edge,status,mask];return
 state.fire_results.append([edge,status,mask])
 while state.fire_results.size()>8:state.fire_results.pop_front()
static func accept(state:Dictionary,command:Dictionary,now:float) -> void:
 sync_life(state)
 if command.get("input_life",-1)!=state.serial:return
 var rows=command.get("fire_events",[[command.get("fire_event",[]),{},EXPIRY]])
 if not rows is Array or rows.size()>CAPACITY:return
 for row in rows:
  if not row is Array or row.size()!=3 or not row[0] is Array or row[0].size()!=3 or not row[1] is Dictionary:return
  var edge:Array=row[0]
  for value in edge:
   if not value is int:return
  if edge[0]<=state.fire_received:continue
  if edge[0]-int(state.fire_received)>32 or edge[1]!=command.weapon or edge[2]<1 or edge[2]>7:return
  if not (row[2] is float or row[2] is int) or not is_finite(float(row[2])):return
  var aim:Dictionary=row[1].duplicate(true)
  for key in ["yaw","pitch","view_time"]:
   if aim.has(key) and (not (aim[key] is float or aim[key] is int) or not is_finite(float(aim[key]))):return
  if aim.has("xr"):
   aim.xr=Poses.validate(aim.xr)
   if aim.xr.is_empty():return
  if aim.has("yaw"):aim.yaw=wrapf(float(aim.yaw),-PI,PI)
  if aim.has("pitch"):aim.pitch=clampf(float(aim.pitch),-1.45,1.45)
  state.fire_received=edge[0];state.fire_ack=edge[0]
  if state.dead or state.spectator or state.get("input_blocked",false) or command.get("input_blocked",false):
   state.fire_queue=[];result(state,edge[0],"blocked",edge[2]);continue
  if state.fire_queue.size()>=CAPACITY:result(state,edge[0],"overflow",edge[2]);continue
  state.fire_queue.append({"id":edge[0],"weapon":edge[1],"mask":edge[2],"aim":aim,"expires":now+clampf(float(row[2]),0,EXPIRY)})
 # Held automatic fire uses the current trigger identity even if its short
 # tap buffer was rejected during a long cooldown. Queued older taps override
 # it only for the duration of their own attempt.
 var active=command.get("fire_active",[])
 if active is Array and active.size()==3:
  for i in 3:
   if active[i] is int and active[i]>0 and active[i]<=state.fire_received and command.get(FIELDS[i],false)==true:
    state.fire_active[i]=maxi(state.fire_active[i],active[i])
 # Compatibility diagnostic used by existing fixtures; queue owns execution.
 if not state.fire_queue.is_empty():
  var p:Dictionary=state.fire_queue[0];state.fire_pending=[p.weapon,p.mask,p.expires]
static func begin_attempt(state:Dictionary,now:float,buffer_primary:bool=false) -> Array:
 sync_life(state)
 var previous:Array=[state.fire,state.get("alt_fire",false),state.get("offhand_fire",false),state.fire_active.duplicate()]
 state.shot_context={};state.fire_attempts=[]
 if state.get("input_blocked",false) or state.dead or state.spectator:
  state.fire_queue=[];state.fire_pending=[];return previous
 var remaining:Array=[];var used:=0
 for edge in state.fire_queue:
  if edge.weapon!=state.weapon or now>edge.expires:
   result(state,edge.id,"cancelled" if edge.weapon!=state.weapon else "expired",edge.mask);continue
  var wait_mask:=0
  for i in 3:
   var bit:=1<<i
   if not edge.mask&bit:continue
   var cooldown:float=state.get("offhand_cooldown",0) if i==2 else state.get("cooldown",0)
   if used&bit:
    wait_mask|=bit;continue
   if cooldown>0 and i!=1:
    if cooldown<=(EXPIRY if buffer_primary and i==0 else BUFFER):wait_mask|=bit
    else:result(state,edge.id,"cooldown",bit)
    continue
   used|=bit;state.fire_active[i]=edge.id
   state[FIELDS[i]]=true
   state.shot_context[i]=edge.aim
   state.fire_attempts.append([edge.id,bit])
   # A new semi-auto edge implies a release even when its packet was lost.
   if i==0:state.held=false
   elif i==2:state.offhand_held=false
  if wait_mask:
   var waiting:Dictionary=edge.duplicate();waiting.mask=wait_mask;remaining.append(waiting)
 state.fire_queue=remaining;state.fire_pending=[]
 state.fire_attempt_shots=state.get("shots",0)
 return previous
static func end_attempt(state:Dictionary,previous:Array) -> void:
 for attempt in state.get("fire_attempts",[]):
  # Successful shots report their exact identity in shot(); retain a rejection
  # for attempts which the weapon state machine did not accept.
  if not state.get("fire_fired_edges",[]).has(attempt):result(state,attempt[0],state.get("fire_reject","not_ready"),attempt[1])
 state.fire_fired_edges=[];state.erase("fire_reject")
 for i in 3:
  state[FIELDS[i]]=previous[i]
  state.fire_active[i]=maxi(state.fire_active[i],previous[3][i])
 state.shot_context={}
static func context(state:Dictionary,offhand:bool=false,alternate:bool=false) -> Dictionary:
 return state.get("shot_context",{}).get(2 if offhand else 1 if alternate else 0,{})
static func shot(state:Dictionary,offhand:bool=false,alternate:bool=false) -> Array:
 sync_life(state)
 var hand:=2 if offhand else 1 if alternate else 0
 var edge:int=state.fire_active[hand]
 var key:=str(hand)+":"+str(edge)
 var ordinal:int=state.fire_ordinals.get(key,0)+1
 state.fire_ordinals[key]=ordinal
 while state.fire_ordinals.size()>8:state.fire_ordinals.erase(state.fire_ordinals.keys()[0])
 var attempt:Array=[edge,1<<hand]
 if not state.has("fire_fired_edges"):state.fire_fired_edges=[]
 state.fire_fired_edges.append(attempt)
 result(state,edge,"fired",1<<hand)
 return [state.serial,edge,ordinal,hand,state.weapon]
