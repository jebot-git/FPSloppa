extends SceneTree
const Host=preload("res://tools/authority_core/host.gd")
var clients:Array=[]
var deadline:=0
func option(flag:String,fallback:String)->String:
 var args:=OS.get_cmdline_user_args();var i:=args.find(flag);return args[i+1] if i>=0 and i+1<args.size() else fallback
func _initialize()->void:run.call_deferred()
func run()->void:
 var hz:=int(option("--tick-hz","30"))
 if hz not in [30,60]:push_error("Fixture rate must be 30 or 60 Hz");quit(1);return
 Engine.physics_ticks_per_second=hz;Engine.max_fps=120
 var server:=option("--role","server")=="server";var count:=int(option("--players","32"));var seconds:=float(option("--seconds","120"));var port:=int(option("--port","27929"));var address:=option("--address","127.0.0.1")
 deadline=Time.get_ticks_msec()+int((seconds+50)*1000)
 var client_count:=int(option("--client-count",str(count)))
 for index in (1 if server else client_count):
  var branch:=Node.new();branch.name="Peer%d"%index;root.add_child(branch)
  var api:=SceneMultiplayer.new();api.server_relay=false;set_multiplayer(api,branch.get_path())
  var host:=Host.new();host.name="Authority";branch.add_child(host);host.setup(server,count,seconds,option("--report",""))
  var peer:=ENetMultiplayerPeer.new();var error:=peer.create_server(port,128,3) if server else peer.create_client(address,port,3)
  if error!=OK:push_error("ENet open failed "+str(error));quit(1);return
  api.multiplayer_peer=peer
  if not server:clients.append(host)
func _process(_dt:float)->bool:
 if Time.get_ticks_msec()>deadline:push_error("driver timeout");quit(1);return false
 if not clients.is_empty():
  var done:=true
  for c in clients:done=done and c.finalising
  if done and clients[0].transport_closed:
   var admitted:=0;var frames:=0;var bad:=0;var disconnected:=0;var minimum:=2147483647;var minimum_inputs:=2147483647;var total_inputs:=0;var transport:Array=[]
   for c in clients:admitted+=int(c.life>0);frames+=maxi(0,c.received-c.received_baseline);bad+=c.bad_frames;disconnected+=c.disconnected;minimum=mini(minimum,maxi(0,c.received-c.received_baseline));minimum_inputs=mini(minimum_inputs,c.sequence-maxi(0,c.sequence_baseline));total_inputs+=c.sequence-maxi(0,c.sequence_baseline);transport.append(c.transport_stats)
   print("AUTHORITY_CLIENTS ",JSON.stringify({"admitted":admitted,"players":clients.size(),"frames":frames,"minimum_frames":minimum,"bad_frames":bad,"disconnected":disconnected,"minimum_inputs_sent":minimum_inputs,"total_inputs_sent":total_inputs,"transport":transport}))
   quit(0 if admitted==clients.size() and minimum>10 and bad==0 and disconnected==0 else 1)
 return false
