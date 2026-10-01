extends Node
## Transport feasibility probe, not the gameplay AI. Sends ordinary player inputs.
var game
var options:Dictionary
var sequence:=0
var sent:=0
var bytes_sent:=0
var active_seconds:=0.0
var accumulator:=0.0
var distance:=0.0
var previous:=Vector3.INF
var maximum_shots:=0
var first_ammo:Array=[]
var last_ammo:Array=[]
func _ready():run.call_deferred()
func _physics_process(delta:float):
 if not is_instance_valid(game):return
 game.clock+=delta
 if not game.active:return
 var mine:int=game.multiplayer.get_unique_id()
 if not game.players.has(mine) or not game.replication.player_rows.has(mine):return
 var row:Array=game.replication.player_rows[mine]
 var point:Vector3=row[1]
 if previous!=Vector3.INF and previous.distance_to(point)<5:distance+=previous.distance_to(point)
 previous=point;last_ammo=row[9].duplicate()
 if first_ammo.is_empty():first_ammo=last_ammo.duplicate()
 var locomotion:Dictionary=game.replication.state[10].get("locomotion",{}).get(mine,{})
 var shots:=0
 for count in locomotion.get("shot_counts",{}).values():shots+=int(count)
 maximum_shots=maxi(maximum_shots,shots)
 active_seconds+=delta;accumulator+=delta
 if accumulator<1.0/30:return
 accumulator=fmod(accumulator,1.0/30);sequence+=1
 var weapon:int=2 if 2 in row[10] else int(row[8])
 var command:Dictionary={"seq":sequence,"map_epoch":game.map_epoch,"move":Vector2(0,-1),"yaw":floor(active_seconds/3.0)*PI*.5,"pitch":0.0,"fire":true,"weapon":weapon,"slow":false,"respawn":true,"jump":fmod(active_seconds,2.0)<.08,"input_blocked":false}
 game.input_delivery.sample(command,int(row[14]),game.clock)
 game.fire_delivery.sample(command,int(row[14]),game.clock)
 game.input_delivery.annotate(command,game.clock)
 game.fire_delivery.annotate(command,game.clock)
 var packet:PackedByteArray=game.input_delivery.pack(command)
 game._input_packet.rpc_id(1,packet)
 sent+=1;bytes_sent+=packet.size()
func run():
 options=JSON.parse_string(OS.get_cmdline_user_args()[0])
 game=load("res://deathmatch/arena.tscn").instantiate();get_tree().root.add_child(game)
 # The probe directly sends input; it never runs authoritative AI or local movement.
 game.set_physics_process(false)
 game.start_join("External controller probe",options.get("host","127.0.0.1"),int(options.get("port",29883)))
 var deadline:=Time.get_ticks_msec()+45000
 while active_seconds<12:
  if Time.get_ticks_msec()>deadline:
   push_error("External controller connection/capture timed out");game.disconnect_game();game.queue_free();await get_tree().process_frame;get_tree().quit(1);return
  await get_tree().process_frame
 set_physics_process(false)
 var result:Dictionary={"scope":"Scripted external controller over ordinary client ENet protocol; not the existing bot AI","protocol":game.PROTOCOL,"map":game.current_map,"peer":game.multiplayer.get_unique_id(),"seconds":active_seconds,"input_packets":sent,"input_payload_bytes":bytes_sent,"authoritative_distance_m":distance,"authoritative_shot_count":maximum_shots,"initial_ammo":first_ammo,"final_ammo":last_ammo,"server_ai_present_on_client":is_instance_valid(game.bots),"received_packets":game.replication.stats.received_packets}
 FileAccess.open(options.output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("EXTERNAL_CONTROLLER_RESULT ",JSON.stringify(result))
 game.disconnect_game();game.queue_free();await get_tree().process_frame;await get_tree().process_frame
 get_tree().quit(0 if distance>.5 and maximum_shots>0 else 2)
