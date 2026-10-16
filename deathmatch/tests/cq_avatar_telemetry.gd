extends SceneTree
class Kernel extends RefCounted:
 func metrics()->Dictionary:return {"elapsed_us":500.,"tracked":3,"registered":5,"models":1,"updated":5}
var failures:Array=[]
func check(ok:bool,label:String)->void:
 if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var batch=load("res://deathmatch/avatars/native_batch.gd").new();batch.kernel=Kernel.new();batch.name="NativeAvatarBatch";root.add_child(batch);batch.set_process(false)
 var stats=load("res://deathmatch/performance/frame_stats.gd").new();root.add_child(stats);stats.set_process(false);stats.warmup=0
 stats.previous_us=Time.get_ticks_usec()-15000;stats._process(.015)
 check(stats.avatar_batch_cpu==[.5] and stats.avatar_batch_tracked_peak==3,"batch CPU and tracking count collected in frame window")
 check(stats.avatar_batch_counters.registered==5 and stats.avatar_batch_counters.models==1,"batch population available for live diagnosis")
 stats.previous_us=Time.get_ticks_usec()-11000000;stats._process(.1)
 check(stats.avatar_batch_cpu.is_empty() and stats.avatar_batch_tracked_peak==0,"window resets timing population without accumulating old peaks")
 stats.free();batch.free();print("CQ_AVATAR_TELEMETRY ",JSON.stringify({"checks":3,"failures":failures}));quit(0 if failures.is_empty() else 1)
