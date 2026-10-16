extends RefCounted
## Versioned bounded wire for the resident core. Transport owns framing/compression.
const MAX_FRAME:=1048576
const MAX_PLAYERS:=128
static var native_codec=preload("res://deathmatch/native/runtime.gd").codec()
static func encode_input(c:Dictionary)->PackedByteArray:
 if native_codec and native_codec.has_method("encode_authority_input") and not OS.get_cmdline_user_args().has("--gdscript-cq-input"):return native_codec.encode_authority_input(c)
 return encode_input_reference(c)
static func encode_input_reference(c:Dictionary)->PackedByteArray:
 var pose:Dictionary=c.get("xr",{});var tracked:=not pose.is_empty();var offhand:=tracked and pose.has("offhand_weapon")
 var redundant:bool=c.has("jump_event") or c.has("jetpack_event") or c.has("fire_event")
 var vr:bool=c.get("vr_device",tracked);var rewind:bool=c.has("view_time");var extended:bool=c.get("offhand_fire",false) or c.get("reload_trigger",false) or c.get("reload_grip",false) or c.has("weapon_held") or vr or tracked or c.get("jetpack",false) or rewind or c.get("cq_drag",false) or c.get("melee",false) or c.get("respawn",false) or redundant
 var swimming:bool=c.has("swim");extended=extended or swimming
 var bytes:=PackedByteArray();bytes.resize(((288 if offhand else 240) if tracked else 48 if extended else 30)+(4 if rewind else 0)+(18 if redundant else 0)+(12 if swimming else 0))
 for i in 4:bytes[i]="CQI3".to_ascii_buffer()[i] if swimming else "CQI2".to_ascii_buffer()[i] if extended else "CQI1".to_ascii_buffer()[i]
 bytes.encode_u32(4,c.life);bytes.encode_u32(8,c.seq);bytes.encode_float(12,c.move.x);bytes.encode_float(16,c.move.y);bytes.encode_float(20,c.yaw);bytes.encode_float(24,c.pitch);bytes[28]=c.weapon
 bytes[29]=int(c.fire)|(int(c.jump)<<1)|(int(c.reload)<<2)|(int(c.slow)<<3)|(int(c.crouch)<<4)|(int(c.prone)<<5)|(int(c.blocked)<<6)
 if extended:
  var flags:=int(vr)|(int(tracked)<<1)|(int(offhand)<<2)|(int(pose.get("left_handed",false))<<3)|(int(pose.has("height"))<<4)|(int(c.get("reload_grip",false))<<5)|(int(c.get("jetpack",false))<<6)|(int(c.get("offhand_fire",false))<<7)|(int(rewind)<<8)|(int(c.get("cq_drag",false))<<9)|(int(c.get("melee",false))<<10)|(int(c.get("respawn",false))<<11)|(int(redundant)<<12)|(int(c.has("weapon_held"))<<13)|(int(c.has("weapon_held") and c.get("weapon_held",true))<<14)|(int(c.get("reload_trigger",false))<<15)
  bytes.encode_u16(30,flags);var room:Vector3=c.get("room",Vector3.ZERO);_put_vector(bytes,32,room);bytes.encode_float(44,pose.get("height",1.65))
  if tracked:
   var offset:=48
   for key in (["head","left","right","weapon","offhand_weapon"] if offhand else ["head","left","right","weapon"]):
    var t:Transform3D=pose[key]
    for v in [t.basis.x,t.basis.y,t.basis.z,t.origin]:_put_vector(bytes,offset,v);offset+=12
 var tail:int=(288 if offhand else 240) if tracked else 48
 if rewind:bytes.encode_float(tail,c.view_time);tail+=4
 if redundant:
  bytes.encode_u32(tail,c.get("jump_event",0));bytes.encode_s32(tail+4,c.get("jump_seq",-1));bytes.encode_u32(tail+8,c.get("jetpack_event",0))
  var edge:Variant=c.get("fire_event",[])
  if edge is Array and edge.size()==3:
   bytes.encode_u32(tail+12,edge[0]);bytes[tail+16]=edge[1];bytes[tail+17]=edge[2]
 if swimming:_put_vector(bytes,bytes.size()-12,c.swim)
 return bytes
static func _put_vector(bytes:PackedByteArray,offset:int,v:Vector3)->void:
 bytes.encode_float(offset,v.x);bytes.encode_float(offset+4,v.y);bytes.encode_float(offset+8,v.z)
static func _vector(bytes:PackedByteArray,offset:int)->Vector3:
 return Vector3(bytes.decode_float(offset),bytes.decode_float(offset+4),bytes.decode_float(offset+8))
static func _transform(bytes:PackedByteArray,offset:int)->Transform3D:
 return Transform3D(Basis(_vector(bytes,offset),_vector(bytes,offset+12),_vector(bytes,offset+24)),_vector(bytes,offset+36))
static func decode_frame(bytes:PackedByteArray)->Dictionary:
 if native_codec and native_codec.has_method("decode_authority_frame") and not OS.get_cmdline_user_args().has("--gdscript-cq-frames"):return native_codec.decode_authority_frame(bytes)
 return decode_frame_reference(bytes)
static func decode_frame_reference(bytes:PackedByteArray)->Dictionary:
 if bytes.size()<14 or bytes.size()>MAX_FRAME:return {}
 var magic:=bytes.slice(0,4).get_string_from_ascii()
 if magic!="CQA1" and magic!="CQA2" and magic!="CQA3":return {}
 var count:=bytes.decode_u16(12);var offset:=14
 if count>MAX_PLAYERS or bytes.size()<offset+count*104:return {}
 var result:Dictionary={"tick":bytes.decode_u64(4),"players":{},"projectiles":{},"version":int(magic.right(1))}
 for index in count:
  var id:=bytes.decode_s64(offset);var life:=bytes.decode_u32(offset+8);var team:=bytes[offset+12];var dead:=bytes[offset+13];var weapon:=bytes[offset+14];var grounded:=bytes[offset+15]
  if id==0 or life==0 or result.players.has(id) or team>2 or dead>1 or weapon>=(17 if magic=="CQA3" else 12) or grounded>1:return {}
  for at in range(offset+16,offset+56,4):
   if not is_finite(bytes.decode_float(at)):return {}
  var ammo:=PackedInt32Array();var clips:=PackedInt32Array()
  for i in 4:ammo.append(bytes.decode_u16(offset+72+i*2))
  for i in 12:clips.append(bytes.decode_u16(offset+80+i*2))
  for i in 5:clips.append(0)
  result.players[id]={"life":life,"team":team,"dead":bool(dead),"weapon":weapon,"grounded":bool(grounded),"position":_vector(bytes,offset+16),"velocity":_vector(bytes,offset+28),"yaw":bytes.decode_float(offset+40),"pitch":bytes.decode_float(offset+44),"height":bytes.decode_float(offset+48),"hp":bytes.decode_float(offset+52),"last_seq":bytes.decode_s64(offset+56),"shots":bytes.decode_u64(offset+64),"ammo":ammo,"clips":clips,"xr":{},"physical":{}}
  offset+=104
 if magic=="CQA1":return result if offset==bytes.size() else {}
 var seen:Dictionary={}
 while offset<bytes.size():
  if bytes.size()-offset<6:return {}
  var type:=bytes.decode_u16(offset);var length:=bytes.decode_u32(offset+2);offset+=6
  if seen.has(type) or length<2 or length>bytes.size()-offset:return {}
  seen[type]=true
  var end:=offset+length;var rows:=bytes.decode_u16(offset);offset+=2
  if type in [1,2,4] and rows>(MAX_PLAYERS*17 if type==2 else MAX_PLAYERS):return {}
  if type==3 and rows>2048:return {}
  if type not in [1,2,3,4]:
   if not _cq_section(type,bytes,offset,end,rows,result):return {}
   offset=end;continue
  for index in rows:
   var size:=67 if type==3 else 41 if type==4 else 42 if type==2 else 209
   if end-offset<size:return {}
   if type==3:
    var key:=bytes.decode_u64(offset)
    if key==0 or result.projectiles.has(key):return {}
    result.projectiles[key]={"owner":bytes.decode_s64(offset+8),"life":bytes.decode_u32(offset+16),"team":bytes.decode_s8(offset+20),"weapon":bytes[offset+21],"position":_vector(bytes,offset+22),"velocity":_vector(bytes,offset+34),"remaining":bytes.decode_float(offset+46),"stuck":bool(bytes[offset+50]&1),"quake":bool(bytes[offset+50]&2),"gravity":bytes.decode_float(offset+51),"arm":bytes.decode_float(offset+55),"radius":bytes.decode_float(offset+59),"age":bytes.decode_float(offset+63)}
    offset+=67;continue
   var id:=bytes.decode_s64(offset);var life:=bytes.decode_u32(offset+8)
   if not result.players.has(id) or result.players[id].life!=life:return {}
   var player:Dictionary=result.players[id]
   if type==1:
    var flags:=bytes[offset+12]
    if flags&~3:return {}
    var offhand:=bool(flags&2);size=257 if offhand else 209
    if end-offset<size or not player.xr.is_empty():return {}
    var pose:Dictionary={"left_handed":bool(flags&1),"height":bytes.decode_float(offset+13)};var at:=offset+17
    for name in (["head","left","right","weapon","offhand_weapon"] if offhand else ["head","left","right","weapon"]):pose[name]=_transform(bytes,at);at+=48
    player.xr=pose
   elif type==2:
    var weapon:=bytes[offset+12]
    if weapon>=(17 if magic=="CQA3" else 12) or player.physical.has(weapon):return {}
    var flags:=bytes.decode_u16(offset+15)
    player.physical[weapon]={"clip":bytes.decode_u16(offset+13),"mag":bool(flags&2),"ready":bool(flags&4),"locked":bool(flags&32),"stroke":bytes.decode_float(offset+17),"carry":bytes[offset+21]}
    player.physical[weapon].grab="rack" if flags&8 else "magazine" if flags&1024 else "ammo" if player.physical[weapon].carry>0 else ""
    player.reloading=bytes.decode_s8(offset+22);player.reload_at=bytes.decode_float(offset+23);player.cycling=bytes.decode_s8(offset+27);player.cycle_at=bytes.decode_float(offset+28);player.physical[weapon].pack_until=bytes.decode_float(offset+32);player.physical[weapon].carried_rounds=bytes.decode_u16(offset+36);player.physical[weapon].event=bytes.decode_u32(offset+38)
   elif type==4:
    if player.has("jetpack"):return {}
    player.jetpack={"mode":bytes[offset+12],"age":bytes.decode_float(offset+13),"cooldown":bytes.decode_float(offset+17),"tap":bytes.decode_float(offset+21),"distance":bytes.decode_float(offset+25),"heading":Vector2(bytes.decode_float(offset+29),bytes.decode_float(offset+33)),"activation":bytes.decode_u32(offset+37)}
   offset+=size
  if offset!=end:return {}
 if magic=="CQA3":
  for player in result.players.values():
   if not player.has("tier_mask"):return {}
 return result if _finite(result) else {}

static func _cq_section(kind:int,b:PackedByteArray,at:int,end:int,rows:int,out:Dictionary)->bool:
 var sizes:Dictionary={5:147,7:36,8:47,9:98,10:74,11:79,12:54,13:63,14:83,15:17,16:27}
 var caps:Dictionary={5:128,7:384,8:128,9:32,10:128,11:128,12:384,13:1024,14:128,15:128,16:128}
 if kind==6:
  if rows>32 or end-at!=29+rows*30:return false
  out.mode={"winner":b.decode_s8(at),"scores":[b.decode_u16(at+1),b.decode_u16(at+3)],"time":b.decode_float(at+5),"light_fraction":b.decode_float(at+9),"epoch":b.decode_u32(at+13),"intermission":b.decode_float(at+17),"lighting_time":b.decode_float(at+21),"remaining":b.decode_float(at+25),"zones":[]};at+=29
  for index in rows:
   out.mode.zones.append({"position":_vector(b,at),"radius":b.decode_float(at+12),"owner":b.decode_s8(at+16),"progress":[b.decode_float(at+17),b.decode_float(at+21)],"credit":b.decode_float(at+25),"contested":bool(b[at+29])});at+=30
  return true
 if not sizes.has(kind):return true
 var size:int=sizes[kind]
 if rows>caps[kind] or end-at!=rows*size:return false
 var names:Dictionary={7:"boxes",8:"fields",9:"vehicles",10:"turrets",11:"flights",12:"grenades",13:"events"}
 if kind not in [5,14,15,16]:out[names[kind]]={}
 for index in rows:
  var key:int=b.decode_u64(at)
  if kind==16:
   if out.version!=3 or not out.players.has(key) or out.players[key].life!=b.decode_u32(at+8) or out.players[key].has("tier_mask"):return false
   var p:Dictionary=out.players[key];var mask:int=b.decode_u32(at+12)
   if mask&~131071 or b[at+26]>15:return false
   p.tier_mask=mask;p.primary_t3=b[at+26]
   for i in 5:p.clips[12+i]=b.decode_u16(at+16+i*2)
  elif kind==15:
   if not out.players.has(key) or out.players[key].life!=b.decode_u32(at+8) or out.players[key].has("squad") or b[at+12]>4 or not is_finite(b.decode_float(at+13)):return false
   out.players[key].squad=int(b[at+12])-1;out.players[key].combat_until=b.decode_float(at+13)
  elif kind==14:
   if not out.players.has(key) or out.players[key].life!=b.decode_u32(at+8) or out.players[key].has("owned"):return false
   var p:Dictionary=out.players[key];var mask:int=b.decode_u16(at+12);p.owned=[]
   if mask&~4095:return false
   mask=p.get("tier_mask",mask)
   for i in 17:
    if mask&(1<<i):p.owned.append(i)
   p.cooldown=b.decode_float(at+14);p.invulnerable=b.decode_float(at+18);p.respawn_at=b.decode_float(at+22);p.stamina=b.decode_float(at+26);p.lock_vehicle=b.decode_u64(at+30);p.lock_elapsed=b.decode_float(at+38);p.melee_ready=b.decode_float(at+42);p.grenade_primed=bool(b[at+46]&1);p.grenade_selected=bool(b[at+46]&2);p.grenade_offhand=bool(b[at+46]&4);p.grenade_ready=b.decode_float(at+47);p.grenade_until=b.decode_float(at+51);p.reloading=b.decode_s8(at+55);p.reload_at=b.decode_float(at+56);p.cycling=b.decode_s8(at+60);p.cycle_at=b.decode_float(at+61);p.charge_at=b.decode_float(at+65);p.salvo_left=b[at+69];p.burst_left=b[at+70];p.jump_ack=b.decode_u32(at+71);p.jetpack_ack=b.decode_u32(at+75);p.fire_ack=b.decode_u32(at+79)
  elif kind==5:
   if not out.players.has(key) or out.players[key].life!=b.decode_u32(at+8) or out.players[key].has("class"):return false
   var p:Dictionary=out.players[key];var flags:int=b[at+15]
   if b[at+12]>3 or b[at+13]>3 or b[at+14] not in [1,2] or flags>>5!=0 or b.decode_s8(at+146)<-1 or b.decode_s8(at+146)>7:return false
   p["class"]={"role":b[at+12],"next":b[at+13],"equipped_t2":b[at+14]==2,"xp":[],"primary_t2":b[at+143],"secondary_t2":b[at+144],"utility_t2":b[at+145]}
   for i in 4:p["class"].xp.append(b.decode_s32(at+16+i*4))
   p.vehicle_seat=b.decode_s8(at+146);p.weapon_held=not bool(flags&16);p.staging=bool(flags&8);p.incapacitated=bool(flags&1);p.nvg=bool(flags&2);p.gibbed=bool(flags&4);p.armor=b.decode_u16(at+32);p.armor_tier=b[at+34];p.grenades=b[at+35];p.vehicle=b.decode_s16(at+36);p.kills=b.decode_s32(at+38);p.deaths=b.decode_s32(at+42);p.bleed_remaining=b.decode_float(at+46);p.inject_progress=b.decode_float(at+50);p.injector=b.decode_s64(at+54);p.injector_life=b.decode_u32(at+62)
   var times:Array=["box_ready","cloak_until","cloak_ready","drone_ready","strike_ready","turret_ready","blind_until"]
   for i in times.size():p["class"][times[i]]=b.decode_float(at+66+i*4)
   p.spotted=[b.decode_float(at+94),b.decode_float(at+98)];p.designation={"active":bool(b[at+102]),"start":_vector(b,at+103),"position":_vector(b,at+115),"direction":_vector(b,at+127),"until":b.decode_float(at+139)}
  else:
   var name:String=names[kind]
   if key==0 or out[name].has(key):return false
   var row:Dictionary={}
   if kind in [7,8,10,11,12]:row.owner=b.decode_s64(at+8+(1 if kind==11 else 0));row.token=b.decode_u32(at+16+(1 if kind==11 else 0))
   if kind==7:row.merge({"team":b.decode_s8(at+20),"health":bool(b[at+21]),"position":_vector(b,at+22),"remaining":b.decode_u16(at+34)})
   elif kind==8:row.merge({"team":b.decode_s8(at+20),"position":_vector(b,at+21),"health":b.decode_u16(at+33),"energy":b.decode_float(at+35),"until":b.decode_float(at+39),"hit_at":b.decode_float(at+43)})
   elif kind==9:row={"index":b[at+8],"kind":b[at+9],"team":b.decode_s8(at+10),"grounded":bool(b[at+11]&1),"headlights":bool(b[at+11]&2),"pilot":b.decode_s64(at+12),"life":b.decode_u32(at+20),"position":_vector(b,at+24),"velocity":_vector(b,at+36),"direction":_vector(b,at+48),"normal":_vector(b,at+60),"yaw":b.decode_float(at+72),"hp":b.decode_float(at+76),"visual_y":b.decode_float(at+80),"reload_at":b.decode_float(at+84),"next":b.decode_float(at+88),"shot_at":b.decode_float(at+92),"rounds":b[at+96],"remaining":b[at+97]}
   elif kind==10:row.merge({"team":b.decode_s8(at+20),"position":_vector(b,at+21),"direction":_vector(b,at+33),"hp":b.decode_float(at+45),"ammo":b[at+49],"shot_at":b.decode_float(at+50),"target_vehicle":b.decode_u64(at+54),"target":b.decode_s64(at+62),"target_life":b.decode_u32(at+70)})
   elif kind==11:row.merge({"strike":bool(b[at+8]),"team":b.decode_s8(at+21),"start":_vector(b,at+22),"direction":_vector(b,at+34),"target":_vector(b,at+46),"length":b.decode_float(at+58),"at":b.decode_float(at+62),"until":b.decode_float(at+66),"impact_at":b.decode_float(at+70),"step":b.decode_float(at+74),"delivered":b[at+78]})
   elif kind==12:row.merge({"life":b.decode_u32(at+20),"team":b.decode_s8(at+24),"kind":b[at+25],"position":_vector(b,at+26),"velocity":_vector(b,at+38),"age":b.decode_float(at+50)})
   elif kind==13:row={"kind":b[at+8],"actor":b.decode_s64(at+9),"life":b.decode_u32(at+17),"entity":b.decode_u64(at+21),"position":_vector(b,at+29),"direction":_vector(b,at+41),"at":b.decode_float(at+53),"value":b.decode_float(at+57),"detail":b.decode_s16(at+61)}
   out[name][key]=row
  at+=size
 return true
static func _finite(value:Variant)->bool:
 if value is float:return is_finite(value)
 if value is Vector3:return value.is_finite()
 if value is Transform3D:return value.is_finite()
 if value is Dictionary:
  for v in value.values():
   if not _finite(v):return false
 elif value is Array:
  for v in value:
   if not _finite(v):return false
 return true
