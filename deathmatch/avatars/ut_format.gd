extends RefCounted
## Script-free UT99 container. Validate before texture allocation or networking admission.
const MAX_BYTES:=25_000_000
static func integer(value:Variant,low:int,high:int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floor(float(value)) and value>=low and value<=high
static func read(path:String) -> Dictionary:
	if ClassDB.class_exists("FPSClientServices") and not OS.get_cmdline_user_args().has("--gdscript-avatar-format"):
		return ClassDB.class_call_static("FPSClientServices","avatar_read",path)
	return read_reference(path)

static func read_reference(path:String) -> Dictionary:
	var f:=FileAccess.open(path,FileAccess.READ)
	if not f:return {"error":"Cannot open avatar."}
	var size:=f.get_length()
	if size<16 or size>MAX_BYTES:return {"error":"Avatar must be between 16 bytes and 25 MB."}
	if f.get_buffer(4).get_string_from_ascii()!="UTAV" or f.get_32()!=1 or f.get_32()!=size:return {"error":"Expected a UT99 .utavatar container (version 1)."}
	var length:=f.get_32()
	if length<2 or length>2_000_000 or length>size-16:return {"error":"Invalid avatar manifest length."}
	var m=JSON.parse_string(f.get_buffer(length).get_string_from_utf8())
	if not m is Dictionary:return {"error":"Invalid avatar manifest."}
	for field in ["title","author","license"]:
		if not m.get(field) is String or m[field].length()>256:return {"error":"Invalid avatar credit."}
	for field in ["vertices","frames","width","height","position_bytes","skin_bytes","skin_width","skin_height","reference"]:
		if not integer(m.get(field),0,MAX_BYTES):return {"error":"Invalid avatar dimension: "+field}
	if m.vertices<3 or m.vertices>4096 or m.frames<1 or m.frames>4096 or m.vertices*m.frames>1_048_576:return {"error":"Avatar geometry limits exceeded."}
	if m.width!=512 or m.height!=ceili(float(m.vertices*m.frames)/512) or m.position_bytes!=m.width*m.height*16 or m.reference>=m.frames:return {"error":"Invalid animation texture layout."}
	if m.skin_width<1 or m.skin_width>2048 or m.skin_height<1 or m.skin_height>2048 or m.skin_bytes<32 or 16+length+m.position_bytes+m.skin_bytes!=size:return {"error":"Invalid skin or payload bounds."}
	if not m.get("corners") is Array or m.corners.size()<3 or m.corners.size()>24576 or m.corners.size()%3!=0:return {"error":"Invalid triangles."}
	for c in m.corners:
		if not c is Array or c.size()!=3 or not integer(c[0],0,int(m.vertices)-1):return {"error":"Invalid triangle vertex."}
		for uv in [c[1],c[2]]:
			if not (uv is float or uv is int) or not is_finite(float(uv)) or uv<0 or uv>1:return {"error":"Invalid texture coordinate."}
	if not m.get("clips") is Array or m.clips.is_empty() or m.clips.size()>256:return {"error":"Invalid animation sequences."}
	var names:={}
	for clip in m.clips:
		if not clip is Dictionary or not clip.get("name") is String or clip.name.is_empty() or clip.name.length()>60 or names.has(clip.name):return {"error":"Invalid animation name."}
		names[clip.name]=true
		if not integer(clip.get("start"),0,int(m.frames)-1) or not integer(clip.get("count"),1,int(m.frames)) or clip.start+clip.count>m.frames:return {"error":"Animation outside frame data."}
		if not (clip.get("fps") is float or clip.get("fps") is int) or not is_finite(float(clip.fps)) or clip.fps<1 or clip.fps>60:return {"error":"Invalid animation rate."}
	if not m.get("bounds") is Array or m.bounds.size()!=6:return {"error":"Invalid animated bounds."}
	for n in m.bounds:
		if not (n is float or n is int) or not is_finite(float(n)) or absf(float(n))>20:return {"error":"Invalid animated bounds."}
	var lower:=Vector3(m.bounds[0],m.bounds[1],m.bounds[2]);var extent:=Vector3(m.bounds[3],m.bounds[4],m.bounds[5])
	if extent.x<0 or extent.y<0 or extent.z<0:return {"error":"Invalid bound extent."}
	if m.has("arm_profile"):
		if not m.arm_profile is Dictionary or m.arm_profile.size()!=2 or not m.get("arm_weights") is Array or m.arm_weights.size()!=int(m.vertices):return {"error":"Invalid arm-only profile."}
		for side in ["left","right"]:
			if not m.arm_profile.get(side) is Array or m.arm_profile[side].size()!=3:return {"error":"Invalid arm landmarks."}
			for point in m.arm_profile[side]:
				if not point is Array or point.size()!=3:return {"error":"Invalid arm landmark."}
				for value in point:
					if not (value is float or value is int) or not is_finite(float(value)) or absf(float(value))>3:return {"error":"Invalid arm landmark coordinate."}
			var points:Array=m.arm_profile[side]
			for i in 2:
				var first:=Vector3(points[i][0],points[i][1],points[i][2]);var second:=Vector3(points[i+1][0],points[i+1][1],points[i+1][2])
				if first.distance_to(second)<.02 or first.distance_to(second)>1:return {"error":"Invalid arm segment length."}
		for value in m.arm_weights:
			if not (value is float or value is int) or not is_finite(float(value)) or absf(float(value))>2:return {"error":"Invalid arm weight."}
	if m.has("ik_profile"):
		var ik=m.ik_profile
		if not ik is Dictionary or (ik.size()!=6 and ik.size()!=7) or not m.get("ik_weights") is Array or m.ik_weights.size()!=int(m.vertices):return {"error":"Invalid constrained IK profile."}
		if ik.has("head_correction"):
			var q=ik.head_correction
			if not q is Array or q.size()!=4:return {"error":"Invalid IK head bind rotation."}
			var norm:=0.0
			for value in q:
				if not (value is float or value is int) or not is_finite(float(value)):return {"error":"Invalid IK head bind rotation."}
				norm+=float(value)*float(value)
			if absf(norm-1)>.001:return {"error":"IK head bind rotation must be normalized."}
		for side in ["left","right"]:
			if not ik.get(side) is Array or ik[side].size()!=3:return {"error":"Invalid IK arm."}
			for point in ik[side]:
				if not valid_ik_point(point):return {"error":"Invalid IK arm landmark."}
			for i in 2:
				var p=ik[side][i];var q=ik[side][i+1]
				var distance:=Vector3(p[0],p[1],p[2]).distance_to(Vector3(q[0],q[1],q[2]))
				if distance<.02 or distance>1:return {"error":"Invalid IK arm length."}
		for key in ["neck","head","eye"]:
			if not valid_ik_point(ik.get(key)):return {"error":"Invalid IK head landmark."}
		var n=ik.neck;var h=ik.head;var e=ik.eye
		if Vector3(n[0],n[1],n[2]).distance_to(Vector3(h[0],h[1],h[2]))<.02 or Vector3(h[0],h[1],h[2]).distance_to(Vector3(e[0],e[1],e[2]))<.02:return {"error":"Collapsed IK neck/head."}
		if not ik.get("sockets") is Array or ik.sockets.size()!=int(m.frames):return {"error":"Invalid animated IK sockets."}
		for row in ik.sockets:
			if not row is Array or row.size()!=9:return {"error":"Invalid animated socket row."}
			for v in row:
				if not (v is float or v is int) or not is_finite(float(v)) or absf(float(v))>10:return {"error":"Invalid animated socket coordinate."}
		for w in m.ik_weights:
			if not w is Array or w.size()!=3 or not integer(w[0],0,3):return {"error":"Invalid IK region."}
			for v in [w[1],w[2]]:
				if not (v is float or v is int) or not is_finite(float(v)) or v<0 or v>1:return {"error":"Invalid IK influence."}
	if m.has("base_model") and (not m.base_model is String or m.base_model not in ["Soldier","Commando","SGirl","FCommando","Boss"]):return {"error":"Invalid base model identity."}
	var raw:=f.get_buffer(m.position_bytes)
	for i in int(m.vertices*m.frames):
		var p:=Vector3(raw.decode_float(i*16),raw.decode_float(i*16+4),raw.decode_float(i*16+8))
		if not p.is_finite() or p.x<lower.x-.001 or p.y<lower.y-.001 or p.z<lower.z-.001 or p.x>lower.x+extent.x+.001 or p.y>lower.y+extent.y+.001 or p.z>lower.z+extent.z+.001 or p.abs().x>10 or p.abs().y>10 or p.abs().z>10:return {"error":"Invalid animated vertex or bounds."}
	var skin:=f.get_buffer(m.skin_bytes)
	if skin.slice(0,8).hex_encode()!="89504e470d0a1a0a" or skin.slice(12,16).get_string_from_ascii()!="IHDR":return {"error":"Expected an embedded PNG skin."}
	var width:=(int(skin[16])<<24)+(int(skin[17])<<16)+(int(skin[18])<<8)+skin[19]
	var height:=(int(skin[20])<<24)+(int(skin[21])<<16)+(int(skin[22])<<8)+skin[23]
	if width!=m.skin_width or height!=m.skin_height:return {"error":"Skin dimensions differ from manifest."}
	return {"manifest":m,"positions":raw,"skin":skin,"size":size}
static func inspect(path:String) -> Dictionary:
	if ClassDB.class_exists("FPSClientServices") and not OS.get_cmdline_user_args().has("--gdscript-avatar-format"):
		return ClassDB.class_call_static("FPSClientServices","avatar_inspect",path,"")
	return inspect_reference(path)

static func inspect_reference(path:String) -> Dictionary:
	var decoded:=read_reference(path)
	if decoded.has("error"):return decoded
	var m:Dictionary=decoded.manifest
	var reach:Dictionary=m.get("ik_profile",{}).duplicate(true)
	if reach.has("sockets"):reach.sockets=[reach.sockets[int(m.reference)]]
	return {"size":decoded.size,"title":m.title,"author":m.author,"license":m.license,"version":"UT99 vertex 1","vertices":m.vertices,"frames":m.frames,"triangles":int(m.corners.size()/3),"base_model":m.get("base_model",""),"reach_profile":reach}

static func valid_ik_point(value:Variant) -> bool:
	if not value is Array or value.size()!=3:return false
	for v in value:
		if not (v is float or v is int) or not is_finite(float(v)) or absf(float(v))>3:return false
	return true
