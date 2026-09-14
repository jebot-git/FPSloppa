extends RefCounted
## Repeat short trigger edges until the authority attempts them once.
const FIELDS=["fire","alt_fire","offhand_fire"]
var life:=-1
var weapon:=-1
var held:=0
var event:=0
var pending:Array=[]
var expires:=0.
func reset() -> void:
 life=-1;weapon=-1;held=0;event=0;pending=[];expires=0
func sample(command:Dictionary,serial:int,now:float) -> void:
 if serial!=life:reset();life=serial
 if weapon!=command.weapon:weapon=command.weapon;held=0;pending=[]
 var mask:=0
 if not command.get("input_blocked",false):
  for i in 3:
   if command.get(FIELDS[i],false):mask|=1<<i
 var edges:=mask&~held;held=mask
 if edges:
  event+=1;pending=[event,weapon,edges];expires=now+.25
 if command.get("input_blocked",false) or now>expires:pending=[]
func annotate(command:Dictionary,now:float) -> void:
 if not pending.is_empty() and now<=expires:command.fire_event=pending.duplicate()
func acknowledge(serial:int,value:int) -> void:
 if serial==life and not pending.is_empty() and value>=pending[0]:pending=[]
static func sync_life(state:Dictionary) -> void:
 if state.get("fire_event_life",-1)!=state.serial:
  state.fire_event_life=state.serial;state.fire_received=0;state.fire_ack=0;state.fire_pending=[]
static func accept(state:Dictionary,command:Dictionary,now:float) -> void:
 sync_life(state)
 var edge=command.get("fire_event",[])
 if not edge is Array or edge.size()!=3 or command.get("input_life",-1)!=state.serial:return
 for value in edge:
  if not value is int:return
 if edge[0]<=state.fire_received or edge[0]-int(state.fire_received)>32 or edge[1]!=command.weapon or edge[2]<1 or edge[2]>7:return
 state.fire_received=edge[0];state.fire_ack=edge[0]
 if state.dead or state.spectator or state.get("input_blocked",false):return
 state.fire_pending=[edge[1],edge[2],now+.25]
static func begin_attempt(state:Dictionary,now:float,buffer_primary:bool=false) -> Array:
 var previous:Array=[state.fire,state.get("alt_fire",false),state.get("offhand_fire",false)]
 var edge:Array=state.get("fire_pending",[]);state.fire_pending=[]
 if edge.size()!=3 or edge[0]!=state.weapon or now>edge[2] or state.get("input_blocked",false) or state.dead or state.spectator:return previous
 var mask:int=edge[1]
 # A brief rocket tap near the end of reload waits for readiness. Keep the
 # original expiry and consume only once; never shorten the weapon's cycle.
 if buffer_primary and mask&1 and float(state.get("cooldown",0))>0:
  state.fire_pending=[edge[0],1,edge[2]];mask&=~1
 for i in 3:state[FIELDS[i]]=previous[i] or bool(mask&(1<<i))
 return previous
static func end_attempt(state:Dictionary,previous:Array) -> void:
 for i in 3:state[FIELDS[i]]=previous[i]
