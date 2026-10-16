extends Node
## Frontend adapter. Authority, admission and server services live in cq-server.
const PROTOCOL="fpsloppa-cq-native-1"
const Codec=preload("res://deathmatch/native/authority_protocol.gd")
var game
var link
var active:=false
var generation:=0
var sequence:=0
var catalog:Dictionary={}
var endpoint:=""
var requested_hash:=""
var download:Dictionary={}
var download_queue:Array[String]=[]
var upload:Dictionary={}
var selected:=""
var weather_seed:=0
func setup(arena)->void:game=arena
func reset()->void:
 generation+=1;active=false
 if link:link.close()
 link=null;catalog.clear();requested_hash="";download.clear();download_queue.clear();upload.clear();sequence=0;selected=""
func start(player_name:String,address:String,port:int,spectator:bool)->void:
 if game.active or game.loading.blocking:return
 if not preload("res://deathmatch/native/runtime.gd").available("FPSNativeClient"):game.status("Rebuild the native client extension to connect to standalone CQ.");return
 reset();active=true;var attempt:=generation
 game.nickname=game.clean_name(player_name);game.joining_as_spectator=spectator
 game.loading.begin();game.menu_open=true
 if game.hud:game.hud.show_menu(true)
 game.connect_deadline=game.clock+120;game.status("Preparing Jungle Frontier…")
 await get_tree().process_frame
 if attempt!=generation:return
 game.map_loading=true
 if not game._load_map("voxel_jungle"):game.disconnect_game("Cannot prepare CQ map.");return
 game.map_loading=false
 var host:=address.strip_edges()
 if not host.is_valid_ip_address():
  var query:=IP.resolve_hostname_queue_item(host,IP.TYPE_IPV4)
  if query==IP.RESOLVER_INVALID_ID:game.disconnect_game("Cannot resolve server.");return
  while IP.get_resolve_item_status(query) in [IP.RESOLVER_STATUS_WAITING,IP.RESOLVER_STATUS_NONE]:
   await get_tree().process_frame
   if attempt!=generation:IP.erase_resolve_item(query);return
  host=IP.get_resolve_item_address(query);IP.erase_resolve_item(query)
 if not host.is_valid_ip_address():game.disconnect_game("Cannot resolve server.");return
 endpoint=host+":"+str(port);link=ClassDB.instantiate("FPSNativeClient")
 if link.connect_host(host,clampi(port,1024,65535))!=OK:game.disconnect_game("Cannot connect to standalone CQ server.");return
 game.status("Connecting to %s…"%endpoint)
func _process(_delta:float)->void:
 if not active or not link:return
 for event in link.poll():
  if not active:return
  var data:Dictionary=event.get("data",{})
  match int(event.type):
   -1:game.disconnect_game("Standalone server disconnected.");return
   0:
    var config:=ConfigFile.new();config.load("user://cq_native_profiles.cfg")
    link.send_control(1,{"protocol":PROTOCOL,"map_sha256":game.map_sha,"name":game.nickname,"spectator":game.joining_as_spectator,"resume":config.get_value("sessions",endpoint,"")})
   2:
    if data.get("protocol")!=PROTOCOL or data.get("map_sha256")!=game.map_sha:game.disconnect_game("Standalone server map/protocol mismatch.");return
    link.activate(int(data.id));game.multiplayer.multiplayer_peer=link.scene_peer()
    game.map_epoch=int(data.epoch);game.max_clients=int(data.capacity);game.clock=float(data.time);game.resident.epoch=game.map_epoch;game.resident.enabled=true
    game.time_limit=float(data.round_seconds);game.voice.policy(bool(data.voice),str(data.hostname));game.announcer.policy(false)
    weather_seed=int(data.weather_seed)
    _catalog(data.assets)
    var config:=ConfigFile.new();config.load("user://cq_native_profiles.cfg");config.set_value("sessions",endpoint,data.resume);config.save("user://cq_native_profiles.cfg")
    link.send_control(3,{})
   4:game.disconnect_game(data.get("reason","Connection rejected."));return
   5:_roster(data.players)
   6:
    if game.active and not game.map_loading:game.resident.receive_frame(Codec.decode_frame(event.bytes),float(event.origin),game.map_epoch)
   9:game._announcement(str(data.name)+": "+str(data.text),true)
   10:
    var bytes:PackedByteArray=event.bytes
    if bytes.size()>=16:game.voice._receive_audio(bytes.decode_s64(0),bytes.decode_u32(8),bytes.slice(13),bytes[12]>0,bytes[12])
   12:
    var hash:String=data.hash
    if hash!=requested_hash or not catalog.has(hash) or int(data.size)!=int(catalog[hash].size) or not download.is_empty():continue
    download={"hash":hash,"size":int(data.size),"bytes":PackedByteArray()}
   13:
    var bytes:PackedByteArray=event.bytes
    if download.is_empty() or bytes.size()<4 or bytes.decode_u32(0)!=download.bytes.size() or download.bytes.size()+bytes.size()-4>download.size:game.disconnect_game("Invalid avatar transfer.");return
    download.bytes.append_array(bytes.slice(4))
   14:_finish_avatar(data.hash)
   16:
    if data.get("busy",false) and upload.get("hash","")==data.hash:upload.retry=Time.get_ticks_msec()+2000
    elif data.get("upload",false) and upload.get("hash","")==data.hash:upload.allowed=true
    elif upload.get("hash","")==data.hash:
     link.send_control(17,{"hash":data.hash});upload.clear()
   18:
    if is_instance_valid(game.destruction):game.destruction.receive_state(game.map_epoch,int(data.revision),bool(data.enabled),PackedInt32Array(data.broken),Vector3(data.get("at",[0,0,0])[0],data.get("at",[0,0,0])[1],data.get("at",[0,0,0])[2]),bool(data.get("animate",false)),PackedInt32Array(data.collapsed))
   21:game._pong(int(data.stamp))
   22:
    game.votes.view=data.get("vote",{});game.votes.enabled=bool(data.get("votes_enabled",false))
   24:_catalog(data.assets)
 if not active:return
 _transfers()
func _catalog(rows:Array)->void:
 for row in rows:
  var hash:String=row.get("hash","")
  if game.avatars.Library.valid_hash(hash) and int(row.get("size",0))>=16 and int(row.get("size",0))<=25_000_000:catalog[hash]=row
func _roster(rows:Array)->void:
 var legacy:Array=[];var choices:Dictionary={}
 for row in rows:
  var id:=int(row.id);var hash:String=row.avatar
  legacy.append([id,row.name,posmod(id,8),Vector3.ZERO,0.,bool(row.spectator),int(row.team)])
  if catalog.has(hash):
   choices[id]={"hash":hash,"size":int(catalog[hash].size)}
   if not game.avatars.library.entries.has(hash) and not download_queue.has(hash) and download.get("hash","")!=hash:download_queue.append(hash)
 for id in game.players:
  if not rows.any(func(row):return int(row.id)==id):game._peer_left(id);game.voice.remove_peer(id)
 game.avatars.choices=choices;game.avatars.library.pinned=choices.values().map(func(row):return row.hash)
 game._roster(legacy)
 game.weather._receive_seed(game.map_epoch,weather_seed)
 for id in choices:game.avatars.queue_avatar(id)
func action(kind:int,a:int=0,b:int=0,c:int=0)->void:
 if not active or not link:return
 var state:Dictionary=game.local_state()
 if state.is_empty():return
 if kind==10:action(11,-1);action(12);return
 sequence+=1;link.send_control(8,{"life":int(state.serial),"seq":sequence,"kind":kind,"a":a,"b":b,"c":c})
func voice(serial:int,bytes:PackedByteArray,scope:int)->void:
 if not link:return
 var data:=PackedByteArray();data.resize(5);data.encode_u32(0,serial);data[4]=scope;data.append_array(bytes);link.send_bytes(10,data,2,false)
func offer(hash:String)->void:
 if not link or not game.avatars.library.entries.has(hash):return
 if catalog.has(hash):link.send_control(17,{"hash":hash});return
 if not upload.is_empty():return
 var row:Dictionary=game.avatars.library.entries[hash]
 upload={"hash":hash,"path":row.path,"size":int(row.size),"offset":0,"allowed":false};link.send_control(15,{"hash":hash,"size":int(row.size)})
func _transfers()->void:
 if not upload.is_empty() and upload.get("retry",0)>0 and Time.get_ticks_msec()>=upload.retry:
  upload.retry=0;link.send_control(15,{"hash":upload.hash,"size":upload.size})
 if requested_hash.is_empty() and download.is_empty() and not download_queue.is_empty():
  var hash:String=download_queue.pop_front()
  if not game.avatars.library.entries.has(hash):requested_hash=hash;link.send_control(11,{"hash":hash})
 if not upload.is_empty() and upload.allowed:
  var f:=FileAccess.open(upload.path,FileAccess.READ)
  if not f:upload.clear();return
  f.seek(upload.offset);var bytes:=f.get_buffer(mini(32768,upload.size-upload.offset));var packet:=PackedByteArray();packet.resize(4);packet.encode_u32(0,upload.offset);packet.append_array(bytes)
  link.send_bytes(23,packet,3,true);upload.offset+=bytes.size()
  if upload.offset==upload.size:upload.allowed=false
func _finish_avatar(hash:String)->void:
 if download.is_empty() or download.hash!=hash or download.bytes.size()!=download.size:game.disconnect_game("Incomplete avatar transfer.");return
 var path:String=game.avatars.Library.CACHE+hash+".native.tmp";var file:=FileAccess.open(path,FileAccess.WRITE)
 if not file:download.clear();return
 file.store_buffer(download.bytes);file.close();download.clear();requested_hash="";var epoch:=generation
 game.avatars.disk.submit(game.avatars.Jobs.model_file.bind(path,hash,game.avatars.Library.CACHE,true),func(info):
  DirAccess.remove_absolute(path)
  if generation!=epoch:return
  if info.has("error"):game.disconnect_game(info.error);return
  game.avatars.library.entries[hash]=info
  for id in game.avatars.choices:
   if game.avatars.choices[id].hash==hash:game.avatars.queue_avatar(id))
