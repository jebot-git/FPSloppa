extends Logger
## Callbacks may run on mixer/loader threads. Drain on the main thread only.
var mutex:=Mutex.new()
var entries: Dictionary={}
var dropped:=0
func _log_error(function: String,file: String,line: int,code: String,rationale: String,_notify: bool,error_type: int,_traces: Array[ScriptBacktrace]) -> void:
	var key:=str(error_type)+file+str(line)+code+rationale
	mutex.lock()
	if entries.has(key):entries[key].count+=1
	elif entries.size()<128:entries[key]={"type":error_type,"function":function.left(160),"file":file.left(256),"line":line,"message":(rationale if not rationale.is_empty() else code).left(1024),"count":1}
	else:dropped+=1
	mutex.unlock()
func drain() -> Array:
	mutex.lock();var result:=entries.values();entries.clear()
	if dropped>0:result.append({"message":"Additional engine diagnostics dropped","count":dropped});dropped=0
	mutex.unlock();return result
