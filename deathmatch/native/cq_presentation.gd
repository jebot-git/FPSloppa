extends RefCounted
## Client-only projection into the existing presentation/prediction API.
const ROLES=["shocktroop","scout","medic","technician"]
const PRIMARY=[4,9,4,5]
const ADVANCED=[1,10,3,11]
const UTILITY=[["jetpack","airstrike"],["recon","recon_drone"],["medical","healing_grenade"],["engineering","turret"]]
static func project(frame:Dictionary,origin:float,epoch:int,duration:float)->Array:
 var mode:Dictionary={"kind":"tdm","scores":frame.mode.scores,"bases":[],"flags":[],"hill":Vector3.ZERO,"owner":-1,"friendly_fire":false,"announcer":false,"weapon_rules":"ut99","locomotion":{},"movement_ack":{},"ordnance":{},"cq_points":{"scores":frame.mode.scores,"winner":frame.mode.winner},"class_mode":{"clock":origin+frame.mode.time,"lighting_time":frame.mode.lighting_time}}
 var players:Array=[];var shots:Array=[];var watermark:=-1
 for id in frame.players:
  var p:Dictionary=frame.players[id]
  if not p.has("class") or not p.has("owned"):return []
  var c:Dictionary=p["class"];var state:Dictionary={"team":p.team,"squad":p.get("squad",-1),"combat_until":origin+p.get("combat_until",0.),"class":ROLES[c.role],"next":ROLES[c.next],"xp":{},"nv":p.nvg,"nb":origin+c.blind_until,"cloak_until":origin+c.cloak_until,"cloak_ready":origin+c.cloak_ready,"dispenser_ready":origin+c.box_ready,"drone_ready":origin+c.drone_ready,"airstrike_ready":origin+c.strike_ready,"turret_ready":origin+c.turret_ready,"primary_choices":{},"secondary_choices":{},"utility_choices":{},"equipped_utility":UTILITY[c.role][int(c.equipped_t2)],"weapon_held":p.get("weapon_held",true)}
  for i in 4:
   state.xp[ROLES[i]]=c.xp[i];state.primary_choices[ROLES[i]]=ADVANCED[i] if c.primary_t2&(1<<i) else PRIMARY[i];state.secondary_choices[ROLES[i]]=0 if c.secondary_t2&(1<<i) else 8 if i==1 else 2;state.utility_choices[ROLES[i]]=UTILITY[i][int(bool(c.utility_t2&(1<<i)))]
  var clips:Dictionary={}
  for i in 12:clips[i]=p.clips[i]
  var mag:Dictionary={"serial":p.life,"weapon":p.weapon,"clips":clips,"physical":p.physical,"reloading":p.get("reloading",-1),"reload_at":origin+p.get("reload_at",0.),"cycling":p.get("cycling",-1),"cycle_at":origin+p.get("cycle_at",0.)}
  mode["cp:"+str(id)]={"state":state,"mag":mag,"spot":[origin+p.spotted[0],origin+p.spotted[1]],"lock":{"ready":p.lock_elapsed>=1.5,"elapsed":p.lock_elapsed,"target":str(p.lock_vehicle),"life":p.life} if p.lock_vehicle else {},"charge":{"at":origin+p.charge_at} if p.charge_at>0 else {}}
  if p.incapacitated:mode["cd:"+str(id)]={"remaining":p.bleed_remaining,"attacker":0,"weapon":"INJURY"}
  if p.inject_progress>0:mode["ci:"+str(id)]={"medic":p.injector,"progress":p.inject_progress,"touched":origin+frame.mode.time}
  if p.designation.active:mode["cl:"+str(id)]={"start":p.designation.start,"position":p.designation.position,"direction":p.designation.direction,"until":origin+p.designation.until,"team":p.team,"life":p.life}
  var jet:Dictionary=p.get("jetpack",{}).duplicate()
  mode.locomotion[id]={"incapacitated":p.incapacitated,"height":p.height,"grounded":p.grounded,"cs16_stamina":p.stamina,"jetpack":jet,"jump_ack":p.jump_ack,"jetpack_ack":p.jetpack_ack,"fire_ack":p.fire_ack};mode.movement_ack[id]=p.last_seq
  players.append([id,p.position,p.velocity,p.yaw,p.pitch,p.hp,p.armor,p.dead,p.weapon,Array(p.ammo),p.owned,p.kills,p.deaths,0,p.life,maxf(0,p.respawn_at-frame.mode.time),p.invulnerable>frame.mode.time,p.cooldown,p.xr,0.,p.get("staging",false),Vector2.ZERO])
  mode["cg:"+str(id)]=[[p.grenades if c.role==0 else 0,0,0,p.grenades if c.role==2 else 0],(3 if c.role==2 and c.equipped_t2 else 0) if p.grenade_selected else -1,p.grenade_primed,p.grenade_offhand,3 if c.role==2 and c.equipped_t2 else 0]
 for i in frame.mode.zones.size():mode["cqo:"+str(i)]=frame.mode.zones[i]
 for key in frame.get("boxes",{}):
  var b:Dictionary=frame.boxes[key];mode["cb:"+str(key)]={"owner":b.owner,"team":b.team,"kind":"health" if b.health else "ammo","position":b.position,"remaining":b.remaining}
 for key in frame.get("vehicles",{}):
  var v:Dictionary=frame.vehicles[key].duplicate();v.kind=["rocket","light","heavy","transport"][v.kind];v.left=v.remaining;v.next+=origin;v.reload_at+=origin;v.shot_at+=origin;v.spawn=v.position;v.speed=v.velocity.length();mode["ctk:"+str(key)]=v
 for key in frame.get("vehicles",{}):
  var v:Dictionary=mode["ctk:"+str(key)]
  if v.kind!="transport":continue
  v.seats=[0,0,0,0,0,0,0,0];v.seat_lives=[0,0,0,0,0,0,0,0]
  for id in frame.players:
   var rider:Dictionary=frame.players[id];var seat:int=rider.get("vehicle_seat",-1)
   if rider.vehicle==v.index and seat>=0 and seat<8:v.seats[seat]=id;v.seat_lives[seat]=rider.life
 for key in frame.get("turrets",{}):
  var t:Dictionary=frame.turrets[key].duplicate();t.fire_at=origin+t.shot_at+1.5;t.shot_at+=origin;mode["ctu:"+str(key)]=t
 for key in frame.get("fields",{}):
  var f:Dictionary=frame.fields[key].duplicate();f.until+=origin;f.hit_at+=origin;mode["chf:"+str(key)]=f
 for key in frame.get("flights",{}):
  var f:Dictionary=frame.flights[key].duplicate();f.at+=origin;f.until+=origin;f.impact_at+=origin;mode[("cas:" if f.strike else "crd:")+str(key)]=f
 for key in frame.get("grenades",{}):
  var g:Dictionary=frame.grenades[key];mode["ch:"+str(key)]=[key,g.kind,g.owner,g.position,g.velocity,g.age,false]
 for key in frame.projectiles:
  var p:Dictionary=frame.projectiles[key];var direction:Vector3=p.velocity.normalized();shots.append([key,p.position,p.owner,p.weapon,direction,atan2(-direction.x,-direction.z),asin(clampf(direction.y,-1,1))]);watermark=maxi(watermark,key);var extra:Dictionary={"cq_team":p.team}
  if p.weapon==5 and is_equal_approx(p.gravity,20.) and p.radius>.1:extra.battery_shot=true
  var definition:Dictionary={} # Full authored definitions are built by the existing spawn path.
  if extra.get("battery_shot",false):definition={"kind":"tribes_mortar","gravity":p.gravity,"radius":p.radius,"arm":p.arm,"fuse":90.,"splash":152.,"blast_radius":30.,"speed":sqrt(100000.),"damage":152.,"bounce":0.,"guided":false,"cq_effect":"ordnance"}
  mode.ordnance[key]={"velocity":p.velocity,"life":p.remaining,"stuck":p.stuck,"extra":extra}
  if not definition.is_empty():mode.ordnance[key].definition=definition
 var scores:Array=frame.mode.scores;var winner:int=frame.mode.winner;var message:String="" if winner==-2 else "DRAW" if winner<0 else ["RED WINS","BLUE WINS"][winner]
 return [players,PackedByteArray(),frame.mode.remaining,frame.mode.intermission,message,200,int(duration),shots,[],epoch,mode,{},origin+frame.mode.time,watermark]
