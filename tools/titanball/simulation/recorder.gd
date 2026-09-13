extends "res://tools/ai_balance/recorder.gd"
var damage_events: Array=[]
var cannon_volleys: Array=[]
var boardings: Array=[]
var deployable_crushes: Array=[]
func record(event: String,data: Dictionary={},detail: int=1) -> void:
 super.record(event,data,detail)
 if event=="titan_deployable_crushed":
  var row:=data.duplicate(true);row.time=game.clock-origin;deployable_crushes.append(row)
 if event=="titan_boarded":
  var row:=data.duplicate(true);row.time=game.clock-origin;boardings.append(row)
 if event=="damage":
  var row:=data.duplicate(true);row.time=game.clock-origin;row.pilot=game.match_mode.fortress.walkers.mounted(int(data.victim))
  row.attacker_team=game.players.get(int(data.attacker),{}).get("team",-1);row.victim_team=game.players.get(int(data.victim),{}).get("team",-1)
  row.attacker_vantage=-1
  if game.fighters.has(int(data.attacker)):
   var at: Vector3=game.fighters[int(data.attacker)].position
   for i in game.match_mode.titanball.vantages.size():
    var point: Vector3=game.match_mode.titanball.vantages[i].position
    if at.distance_to(point)<3.0 and absf(at.y-point.y)<.7:row.attacker_vantage=i;break
  damage_events.append(row)
 if event=="titan_cannon_volley":
  var row:=data.duplicate(true);row.time=game.clock-origin;cannon_volleys.append(row)
