extends SceneTree
var failures: Array=[]
func _initialize():call_deferred("run")
func check(value: bool,label: String):
 print("PASS " if value else "FAIL ",label)
 if not value:failures.append(label)
func packet(value: float) -> PackedByteArray:
 var b:=StreamPeerBuffer.new();b.big_endian=true
 for s in ["/tracking/trackers/2/position",",fff"]:
  var bytes:PackedByteArray=s.to_utf8_buffer();bytes.append(0)
  while bytes.size()%4:bytes.append(0)
  b.put_data(bytes)
 b.put_float(value);b.put_float(.1);b.put_float(0)
 return b.data_array
func run():
 var tracking=load("res://deathmatch/vr/tracking.gd").new();root.add_child(tracking)
 tracking.osc_port=19108;tracking.start_osc();tracking.set_process(false)
 var sender:=PacketPeerUDP.new();sender.set_dest_address("127.0.0.1",19108)
 # Sustained full-body-equivalent traffic plus a short loading burst.
 for batch in range(8):
  for i in range(96):sender.put_packet(packet(float(batch*96+i)/1000))
  await create_timer(.015).timeout
  tracking._process(.015)
 var deadline:=Time.get_ticks_msec()+60
 while Time.get_ticks_msec()<deadline and tracking.udp.get_available_packet_count()>0:
  tracking._process(.016);await process_frame
 check(tracking.udp.get_available_packet_count()==0,"High-rate OSC traffic catches up without a persistent backlog")
 check(absf(tracking.osc.samples.get("left_foot",{}).get("position",Vector3.ZERO).x-.767)<.001,"Latest foot target survives the burst")
 sender.close();tracking.free()
 print("OSC_BURST_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
