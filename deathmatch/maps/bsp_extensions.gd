extends RefCounted
## Bounded raw BSPX access. Never deserializes resources or follows external paths.
static func directory(path: String) -> Dictionary:
	var f:=FileAccess.open(path,FileAccess.READ)
	if not f or f.get_length()<124 or f.get_length()>25_000_000:return {}
	if not f.get_32() in [29,0x32505342,0x42535032]:return {}
	var end:=124
	for i in 15:
		var at:=f.get_32();var size:=f.get_32()
		if at+size>f.get_length():return {}
		end=maxi(end,at+size)
	end=(end+3)&~3
	if end+8>f.get_length():return {}
	f.seek(end)
	if f.get_buffer(4).get_string_from_ascii()!="BSPX":return {}
	var count:=f.get_32()
	if count>64 or end+8+count*32>f.get_length():return {"error":"Invalid BSPX directory."}
	var rows: Dictionary={}
	for i in count:
		var key:=f.get_buffer(24).get_string_from_ascii();var at:=f.get_32();var size:=f.get_32()
		if key.is_empty() or rows.has(key) or at<end+8+count*32 or at+size>f.get_length():return {"error":"Invalid BSPX extension bounds."}
		rows[key]=Vector2i(at,size)
	return rows
static func read(path: String,key: String,limit: int) -> PackedByteArray:
	var rows:=directory(path)
	if rows.has("error") or not rows.has(key) or rows[key].y>limit:return PackedByteArray()
	var f:=FileAccess.open(path,FileAccess.READ)
	f.seek(rows[key].x)
	return f.get_buffer(rows[key].y)
