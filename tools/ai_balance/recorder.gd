extends "res://deathmatch/server/log.gd"
var totals:Dictionary={}
var damage:Dictionary={}
var events:Array=[]
var deaths:Array=[]
var separated_damage:Dictionary={}
var pickups:Array=[]
var hill_seconds:Dictionary={"empty":0.0,"contested":0.0,"red":0.0,"blue":0.0}
var hill_runs:Array=[]
var hill_owner:=-99
var hill_started:=0.0
var origin:=0.0
var carrier_runs:Array=[]
var carriers:Dictionary={}
var approaches:Dictionary={}
var nearest_flag:Dictionary={}
var active_class_seconds:Dictionary={}
var active_bot_seconds:=0.0
var spawn_only_seconds:=0.0
var attacker_water_seconds:=0.0
var wet_attackers:Dictionary={}
var assault:Array=[]
var as_state:=""
var class_combat:Dictionary={}
var elapsed:=0.0
var sample_at:=0.0
var frozen_previous:Dictionary={}
var freezes:=0
var thaws:=0
var freeze_rounds:=0
func equipment(id:int)->Dictionary:
 if not game.players.has(id):return {}
 var s:Dictionary=game.players[id]
 return {"id":id,"team":s.team,"class":s.get("tf_class",""),"weapon":s.weapon,"owned":s.owned.duplicate(),"ammo":s.ammo.duplicate(),"position":game.fighters[id].position,"hp":s.hp,"armor":s.armor,"serial":s.serial}
func record(event:String,data:Dictionary={},_detail:int=1)->void:
 totals[event]=int(totals.get(event,0))+1
 if event=="match_event":
  var message:String=data.get("message","")
  events.append({"time":game.clock-origin,"text":message})
  if " is frozen" in message:freezes+=1
  if " thawed" in message:thaws+=1
  if "wins the freeze round" in message:freeze_rounds+=1
 if event=="pickup":
  var row:=equipment(int(data.peer));row.merge(data,true);row.time=game.clock-origin;pickups.append(row)
 if event!="damage":return
 var weapon:String=data.weapon
 damage[weapon]=int(damage.get(weapon,0))+int(data.damage)
 var kind:="combat"
 if weapon=="SUICIDE":kind="voluntary"
 elif weapon=="CIRCUS HUNGER":kind="hunger"
 elif weapon in ["environment","ENVIRONMENT","DROWNING","FALL","LAVA","SLIME"]:kind="environment"
 elif data.attacker==data.victim:kind="self_damage"
 elif game.players.has(int(data.attacker)) and game.match_mode.same_team(int(data.attacker),int(data.victim)):kind="friendly_fire"
 separated_damage[kind]=int(separated_damage.get(kind,0))+int(data.damage)
 if kind=="combat":
  var role:String=game.players.get(int(data.attacker),{}).get("tf_class","none")
  class_combat[role]=int(class_combat.get(role,0))+int(data.damage)
 if not data.get("fatal",false):return
 var death:=equipment(int(data.victim));death.merge(data,true);death.time=game.clock-origin;death.category=kind
 death.spawn_equipment_only=death.owned.all(func(w):return w in [0,1,2])
 if game.match_mode.kind=="koth":death.hill_distance=game.fighters[int(data.victim)].position.distance_to(game.match_mode.hill)
 if game.match_mode.kind in ["ctf","tf"]:
  death.enemy_flag_distance=game.fighters[int(data.victim)].position.distance_to(game.match_mode.bases[1-game.players[int(data.victim)].team])
 if game.match_mode.kind=="as":death.leg=game.match_mode.assault.leg;death.stage=game.match_mode.assault.stage;death.attacking=game.players[int(data.victim)].team==game.match_mode.assault.attacking
 deaths.append(death)
func begin()->void:
 origin=game.clock;events.clear();totals.clear();pickups.clear()
func observe(delta:float)->void:
 elapsed=game.clock-origin
 var mode=game.match_mode
 if mode.kind=="koth":
  var owner:int=mode.hill_owner
  var key:String="empty" if owner==-1 else "contested" if owner==-2 else "red" if owner==0 else "blue"
  hill_seconds[key]+=delta
  if owner!=hill_owner:
   if hill_owner!=-99:hill_runs.append({"owner":hill_owner,"start":hill_started,"seconds":elapsed-hill_started})
   hill_owner=owner;hill_started=elapsed
 if mode.kind in ["ctf","tf"]:
  for flag in 2:
   var carrier:int=mode.flags[flag].carrier
   if carriers.has(flag) and carriers[flag].id!=carrier:
    var row:Dictionary=carriers[flag];row.end=elapsed;row.ended="capture" if mode.scores[row.team]>row.score_at_take else "drop_or_return";carrier_runs.append(row);carriers.erase(flag)
   if carrier!=0:
    var team:int=game.players[carrier].team
    var home:Vector3=mode.captures[team] if mode.kind=="tf" else mode.bases[team]
    var distance:float=game.fighters[carrier].position.distance_to(home)
    if not carriers.has(flag):
     carriers[flag]={"id":carrier,"team":team,"flag":flag,"take":elapsed,"start_distance":distance,"best_distance":distance,"score_at_take":mode.scores[team],"equipment":equipment(carrier)}
    carriers[flag].best_distance=minf(carriers[flag].best_distance,distance)
 if mode.kind=="as":
  var a=mode.assault
  var state:="%d:%d:%d:%s:%s"%[a.leg,a.stage,a.checkpoint,a.switching,a.finished]
  if state!=as_state:
   assault.append({"time":elapsed,"leg":a.leg,"attacking":a.attacking,"stage":a.stage,"checkpoint":a.checkpoint,"budget":a.budget,"first_time":a.first_time,"finished":a.finished,"switching":a.switching,"score":mode.scores.duplicate()});as_state=state
 if elapsed<sample_at:return
 sample_at=elapsed+.25
 for id in game.players:
  var s:Dictionary=game.players[id]
  if s.spectator or s.dead or mode.special.blocked(id):continue
  active_bot_seconds+=.25
  if s.owned.all(func(w):return w in [0,1,2]):spawn_only_seconds+=.25
  var role:String=s.get("tf_class","none");active_class_seconds[role]=float(active_class_seconds.get(role,0))+.25
  if mode.kind in ["ctf","tf"]:
   var d:float=game.fighters[id].position.distance_to(mode.bases[1-s.team])
   var life:="%s:%s"%[id,s.serial]
   nearest_flag[life]=minf(float(nearest_flag.get(life,INF)),d)
   if d<12 and not approaches.has(life):approaches[life]={"time":elapsed,"distance":d,"equipment":equipment(id)}
  if mode.kind=="as" and s.team==mode.assault.attacking and game.fighters[id].in_water:
   attacker_water_seconds+=.25;wet_attackers["%s:%s:%s"%[mode.assault.leg,id,s.serial]]=equipment(id)
func finish()->Dictionary:
 if hill_owner!=-99:hill_runs.append({"owner":hill_owner,"start":hill_started,"seconds":elapsed-hill_started})
 for row in carriers.values():row.ended="round_end";row.end=elapsed;carrier_runs.append(row)
 return {"damage_categories":separated_damage,"death_equipment":deaths,"pickups":pickups,"hill_seconds":hill_seconds,"hill_runs":hill_runs,"flag_carriers":carrier_runs,"flag_approaches":approaches,"nearest_flag_by_life":nearest_flag,"active_class_seconds":active_class_seconds,"class_combat_damage":class_combat,"active_bot_seconds":active_bot_seconds,"spawn_only_seconds":spawn_only_seconds,"assault_progress":assault,"attacker_water_seconds":attacker_water_seconds,"wet_attacker_lives":wet_attackers,"freezes":freezes,"thaws":thaws,"freeze_rounds":freeze_rounds}
