extends SceneTree
## Run in an empty project with -- <absolute server .gdextension manifest>.
func _initialize():
 var args:=OS.get_cmdline_user_args()
 if args.is_empty():push_error("Supply the isolated server extension manifest");quit(1);return
 var status:=GDExtensionManager.load_extension(args[0])
 if status!=GDExtensionManager.LOAD_STATUS_OK or not ClassDB.class_exists("FPSCodec") or ClassDB.class_exists("FPSPose"):
  push_error("Expected the dedicated server extension only");quit(1);return
 var codec=ClassDB.instantiate("FPSCodec")
 var command:Dictionary={"seq":5,"move":Vector2.RIGHT,"fire":true,"weapon":6}
 var packed:PackedByteArray=codec.pack_input(command)
 var raw:PackedByteArray=packed.slice(5).decompress(packed.decode_u32(1),FileAccess.COMPRESSION_FASTLZ)
 if codec.decode(raw)!=command:push_error("Server input codec round trip");quit(1);return
 var records:Array=[[0,2,1.0],[1,"kind","dm"],[4,0,[],[],[]]]
 var encoded:Array=codec.encode_records(records)
 var packets:Dictionary=codec.pack_records(encoded,[1,1,1.0])
 if packets.invalid or packets.normal.size()!=1 or not packets.large.is_empty():push_error("Server batch packing");quit(1);return
 packed=packets.normal[0]
 var decoded=bytes_to_var(packed.slice(5).decompress(packed.decode_u32(1),FileAccess.COMPRESSION_FASTLZ))
 if decoded[3]!=encoded:push_error("Server packet contents");quit(1);return
 var row:Array=[1,Vector3.ZERO,Vector3.ZERO,0.,0.,100,0,false,6,[1,2,3,4],[6],0,0,0,1,0.,false,0.,{},0.,false,Vector2.ZERO]
 var other:Array=row.duplicate(true);other[0]=2
 var snapshot:Array=[[row,other],PackedByteArray(),600.,0.,"",20,600.,[],[],1,{"kind":"dm","locomotion":{},"movement_ack":{}},{},1.,0]
 var groups:Dictionary=codec.snapshot_records(snapshot,1,{},{},{})
 if groups.personal.size()!=2:push_error("Server recipient records");quit(1);return
 var private_row:Array=codec.decode(groups.personal[1].slice(1))
 if not private_row[2][9].is_empty() or private_row[4]!=-1:push_error("Server recipient privacy");quit(1);return
 var traces=ClassDB.instantiate("FPSProjectiles")
 if not traces.has_method("trace_structures") or traces.trace_structures({"test":{"position":Vector3.ZERO}},Vector3(0,1,2),Vector3(0,1,-2),INF,0.).get("key")!="test":
  push_error("Server special structure trace");quit(1);return
 print("NATIVE_SERVER_CODEC_RESULT ",JSON.stringify({"passed":true,"bytes":packed.size()}));quit()
