extends RefCounted
## Synchronous nested scopes. Self time still includes uninstrumented engine work.
static var rows:Dictionary={}
static var stack:Array=[]
static func begin(_name:String) -> void:stack.append([Time.get_ticks_usec(),0])
static func end(name:String) -> void:
	var entry:Array=stack.pop_back();var elapsed:int=Time.get_ticks_usec()-entry[0]
	if not stack.is_empty():stack.back()[1]+=elapsed
	if not rows.has(name):rows[name]=[0,0,0,0]
	var row:Array=rows[name];row[0]+=elapsed;row[1]+=1;row[2]=maxi(row[2],elapsed);row[3]+=elapsed-entry[1]
static func reset() -> void:rows.clear();stack.clear()
