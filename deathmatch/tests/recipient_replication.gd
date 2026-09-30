extends SceneTree
const Rep=preload("res://tools/native_study/personal_replication_reference.gd")
const Codec=preload("res://deathmatch/network/snapshot_codec.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 if not ok:failures.append(label);push_error(label)
func deliver(sender,receiver,state,recipient,cache:Dictionary={}) -> Array:
 var packets:Dictionary=sender.packets(state,recipient,cache)
 packets.normal.reverse()
 for bytes in packets.normal+packets.large:check(receiver.receive(bytes,1),"accept personalized packet")
 return receiver.flush()
func _initialize():
 var mode:Dictionary={"kind":"dm","scores":[0,0],"bases":[],"flags":[],"hill":Vector3.ZERO,"owner":-1,"friendly_fire":false,"limit":20,"locomotion":{},"movement_ack":{},"cs16":{}}
 var state:Array=[[],PackedByteArray(),600.,0.,"",20,600.,[],[],1,mode,{},1.,0]
 for id in [1,2,3]:
  var pose:Dictionary=Poses.neutral()
  state[0].append([id,Vector3((id-1)*50,0,0),Vector3.ZERO,0.,0.,100,50,false,6,[100,50,20,100],[0,2,6],0,0,30,1,0.,false,.4,pose,.2,false,Vector2.ZERO])
  mode.locomotion[id]={"height":1.65,"grounded":true,"fire_ack":id,"shot_counts":{"0:1":2},"fire_results":[],"jetpack_owned":true}
  mode.movement_ack[id]=id*100
  mode.cs16[id]=[1,6,30,0,false,0,0,0,0,0,0,0]
 mode.tribes={"players":{}}
 mode.defusal={"accounts":{},"utility":{"inventory":{}}}
 for id in [1,2,3]:
  mode.tribes.players[id]={"class":"heavy","next":"heavy","pack":"ammo","next_pack":"ammo","guns":[3,2,4,1,7],"ammo":[10,10,10,10,10,10,10,10,10,10,10,10],"kit":true,"paid":123,"beacons":3,"grenade":10,"fallback":false}
  mode.defusal.accounts[id]=[1200,true,true,2,"Private purchase"]
  mode.defusal.utility.inventory[id]=[[1,2,1],0,true,false,-1]
 # Native/reference policy, bytes and cadence must agree over changes and loss.
 var native=Rep.new();var reference=Rep.new();reference.native_packing_enabled=false
 for tick in 90:
  var sample:Array=state.duplicate(true);sample[12]=tick/30.
  sample[0][1][1]=Vector3(50. if tick<40 else 10.,0,sin(tick*.1))
  if tick>=60:sample[0][1][14]=2
  if tick>=75:sample[0][1][18]={}
  var n:Dictionary=native.packets(sample,1);var r:Dictionary=reference.packets(sample,1)
  check(n==r,"native/reference exact recipient packets tick "+str(tick))
  check(native.pose_sent==reference.pose_sent,"native/reference cadence state")
 var before: Array=state.duplicate(true)
 var a=Rep.new();var b=Rep.new();var ar=Rep.new();var br=Rep.new();var shared:Dictionary={}
 var av:=deliver(a,ar,state,1,shared);var bv:=deliver(b,br,state,2,shared)
 check(state==before,"projection does not mutate source/demo state")
 for row in av[0]:
  check(row[9]==([100,50,20,100] if row[0]==1 else [0,0,0,0]),"owner-only ammunition")
  check(row[10]==([0,2,6] if row[0]==1 else []),"owner-only inventory")
  check(av[10].movement_ack[row[0]]==(100 if row[0]==1 else -1),"owner-only movement receipt")
  check(av[10].locomotion[row[0]].has("shot_counts")== (row[0]==1),"owner-only firing receipts")
 check(br.player_rows[2][9]==[100,50,20,100] and br.player_rows[1][9]==[0,0,0,0],"shared cache never leaks another owner's row")
 check(av[10].cs16[2][2]==0 and bv[10].cs16[2][2]==30,"CS magazine privacy preserves own count")
 check(av[10].tribes.players[2].ammo==[0,0,0,0,0,0,0,0,0,0,0,0] and av[10].tribes.players[1].ammo[0]==10,"Tribes ammunition is private")
 check(av[10].tribes.players[2].paid==0 and not av[10].tribes.players[2].kit and av[10].tribes.players[2].beacons==0,"Tribes consumables are private")
 check(preload("res://deathmatch/tribes/arsenal.gd").valid_loadout("light",av[10].tribes.players[2].guns,"energy"),"redacted future loadout remains valid")
 check(av[10].defusal.accounts[2][0]==0 and av[10].defusal.accounts[1][0]==1200,"DE funds are private")
 check(av[10].defusal.utility.inventory[2][0]==[0,0,0] and av[10].defusal.utility.inventory[2][2],"DE grenade counts private, visible priming retained")
 var previous:Dictionary=ar.player_rows[2][18].duplicate(true)
 state[12]+=.033;state[0][1][1].z+=.1;state[0][1][18].head.origin.y+=.1
 var packets:Dictionary=a.packets(state,1)
 var omitted:=false
 for bytes in packets.normal+packets.large:
  for record_bytes in Codec.unpack(bytes)[3]:
   var record=Codec.decode(record_bytes)
   if record[0]==2 and record[1]==2:omitted=record[2][18]==null
  ar.receive(bytes,1)
 check(omitted,"distant pose omitted between refreshes")
 ar.flush();check(ar.player_rows[2][18]==previous and ar.player_rows[2][1]==state[0][1][1],"body progresses while pose is held")
 # Drop a refresh, then recover from the next independent full pose.
 state[12]+=.21;a.packets(state,1)
 state[12]+=.21;deliver(a,ar,state,1)
 check(ar.player_rows[2][18].head.origin.distance_to(state[0][1][18].head.origin)<.001,"lost pose refresh recovers")
 state[12]+=.033;state[0][1][14]+=1;state[0][1][18]={};deliver(a,ar,state,1)
 check(ar.player_rows[2][18].is_empty(),"new life/tracking loss clears old pose immediately")
 state[0][1][18]=Poses.neutral();state[0][1][1]=Vector3(2,0,0);state[12]+=.033;deliver(a,ar,state,1)
 check(not ar.player_rows[2][18].is_empty(),"approach refreshes pose immediately")
 state[0].pop_back();state[12]+=.033;deliver(a,ar,state,1)
 check(not a.pose_sent.has(3) and not ar.player_rows.has(3),"departure prunes receiver and cadence state")
 print("RECIPIENT_REPLICATION_RESULT ",JSON.stringify({"failures":failures}));quit(0 if failures.is_empty() else 1)
