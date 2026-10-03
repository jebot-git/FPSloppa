extends RefCounted
## Positional wire fields avoid sending replay-state names for every actor.
## The in-memory simulation state remains named and readable.
const FIELDS=["jump_held","jump_queued","blast_velocity","floor_grace","stepped_last_frame","water_jump_used","water_deep_time","water_exit_grace","water_boost","was_in_water","in_water","underwater","water_surface"]
static func encode(state:Dictionary) -> Dictionary:
 var result:=state.duplicate()
 if state.get("replay") is Dictionary:
  var row:Array=[]
  for field in FIELDS:row.append(state.replay[field])
  if state.replay.has("cs16_stamina"):row.append(state.replay.cs16_stamina)
  result.replay=row
 return result
static func decode(state:Dictionary) -> Dictionary:
 var result:=state.duplicate()
 if state.get("replay") is Array and state.replay.size() in [FIELDS.size(),FIELDS.size()+1]:
  result.replay={}
  for i in FIELDS.size():result.replay[FIELDS[i]]=state.replay[i]
  if state.replay.size()>FIELDS.size():result.replay.cs16_stamina=state.replay[-1]
 return result
