extends SceneTree
func _initialize():run.call_deferred()
func run():
	var runtime=preload("res://deathmatch/native/runtime.gd");runtime.backend()
	var source=preload("res://deathmatch/tests/native_network_packing.gd").new();var reports:Array=[]
	for count in [1,2,4,6]:
		var replication=preload("res://deathmatch/network/replication.gd").new();replication.async_encoder=ClassDB.instantiate("FPSBackend");replication.async_encoder.set_workers(count)
		replication.epoch=1;var times:Array=[]
		for tick in 100:
			var snapshot:Array=source.snapshot(64,24,true,tick)
			for row in snapshot[0]:row[18].erase("body")
			if not replication.queue_packets(snapshot):push_error("Unexpected busy queue");quit(1);return
			var result:Array=[];var deadline:=Time.get_ticks_msec()+5000
			while result.is_empty() and Time.get_ticks_msec()<deadline:
				await process_frame;result=replication.poll_packets()
			if result.is_empty():push_error("Encoder timeout");quit(1);return
			if tick>=10:times.append(result[0].encode_usec/1000.)
		times.sort();reports.append({"workers":count,"median_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)]});replication.reset()
	source.free();runtime.backend().shutdown();runtime.backend_instance=null
	print("NATIVE_WORKER_BENCH_RESULT ",JSON.stringify(reports));quit()
