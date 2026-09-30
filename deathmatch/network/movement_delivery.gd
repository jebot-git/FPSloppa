extends RefCounted
## Fixed-tick command history, sent redundantly at 30 Hz. The authority consumes
## at most one command per physics tick; client timestamps never grant extra time.
const CAPACITY=4
const Poses=preload("res://deathmatch/vr/poses.gd")
const Room=preload("res://deathmatch/vr/room_scale.gd")
var history:Array=[]
var life:=-1
func reset() -> void:history=[];life=-1
func sample(command:Dictionary,serial:int) -> void:
 if serial!=life:reset();life=serial
 var c:Dictionary={}
 for field in ["seq","move","yaw","slow","jump","crouch","prone","room","swim","xr","input_blocked"]:
  if command.has(field):c[field]=command[field]
 if c.has("xr"):
  c.xr=Poses.gameplay(c.xr)
 history.append(c)
 while history.size()>CAPACITY:history.pop_front()
func annotate(command:Dictionary) -> void:command.move_commands=history.duplicate(true)
static func accept(state:Dictionary,command:Dictionary) -> void:
 if not command.has("move_commands") or command.get("input_life",-1)!=state.serial:return
 var rows=command.move_commands
 if not rows is Array or rows.size()>CAPACITY:return
 if state.get("movement_life",-1)!=state.serial:
  state.movement_life=state.serial;state.movement_queue={};state.movement_ack=-1;state.movement_latest=-1;state.movement_held={}
 for raw in rows:
  if not raw is Dictionary:return
  if not raw.get("seq") is int or raw.seq<0 or raw.seq>command.seq or raw.seq<=state.movement_ack:continue
  if raw.seq<command.seq-CAPACITY or not raw.get("move") is Vector2 or not raw.move.is_finite():return
  if not (raw.get("yaw") is float or raw.get("yaw") is int) or not is_finite(float(raw.yaw)):return
  for field in ["slow","jump","crouch","prone","input_blocked"]:
   if raw.has(field) and not raw[field] is bool:return
  var c:Dictionary=raw.duplicate(true)
  c.move=c.move.limit_length(1);c.yaw=wrapf(float(c.yaw),-PI,PI)
  c.xr=Poses.validate(c.get("xr",{}))
  if raw.has("xr") and c.xr.is_empty():return
  c.room=Room.validate(c.get("room"),c.xr)
  c.swim=c.get("swim",Vector3.ZERO)
  if not c.swim is Vector3 or not c.swim.is_finite():return
  c.swim=c.swim.limit_length(1)
  if c.xr.is_empty():c.swim=Vector3.ZERO
  if c.get("input_blocked",false):c.move=Vector2.ZERO;c.room=Vector3.ZERO;c.swim=Vector3.ZERO;c.jump=false
  state.movement_latest=maxi(state.movement_latest,c.seq)
  if state.movement_queue.size()<12:state.movement_queue[c.seq]=c
static func consume(state:Dictionary) -> Dictionary:
 if state.get("movement_life",-1)!=state.serial or not state.has("movement_queue"):return {}
 var queue:Dictionary=state.movement_queue
 if state.movement_ack<0 or not queue.is_empty() and int(queue.keys().min())>state.movement_ack+CAPACITY:
  if queue.is_empty():return {}
  state.movement_ack=int(queue.keys().min())-1
 if queue.is_empty() and state.movement_ack>=state.get("movement_latest",state.movement_ack):
  var held:Dictionary=state.get("movement_held",{}).duplicate(true)
  if not held.is_empty():held.room=Vector3.ZERO
  return held
 state.movement_ack+=1
 var c:Dictionary=queue.get(state.movement_ack,{})
 queue.erase(state.movement_ack)
 # A gap before a known newer command is held and acknowledged. Late
 # retransmissions cannot simulate that elapsed interval a second time.
 if c.is_empty():
  c=state.get("movement_held",{}).duplicate(true)
  if not c.is_empty():c.room=Vector3.ZERO
 else:state.movement_held=c.duplicate(true)
 for seq in queue.keys():
  if seq<state.movement_ack:queue.erase(seq)
 return c
