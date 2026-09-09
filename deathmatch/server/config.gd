extends RefCounted
const DEFAULTS={"sv_hostname":"Entryway Arena","net_ip":"*","net_port":7777,"sv_maxclients":8,"fraglimit":20,"timelimit":10,"sv_voice":1,"map":"lqdm1"}
const RANGES={"net_port":Vector2i(1024,65535),"sv_maxclients":Vector2i(1,8),"fraglimit":Vector2i(1,100),"timelimit":Vector2i(1,60),"sv_voice":Vector2i(0,1)}

static func parse(source: String) -> Dictionary:
	var values:=DEFAULTS.duplicate()
	var line_number:=0
	for raw in source.split("\n"):
		line_number+=1
		var lex:=tokens(raw)
		if lex.has("error"): return {"error":"Line %d: %s"%[line_number,lex.error]}
		var words: Array=lex.words
		if words.is_empty(): continue
		var key: String
		var value: String
		if words[0] in ["set","seta","sets"] and words.size()==3:
			key=words[1]; value=words[2]
		elif words[0]=="map" and words.size()==2:
			key="map"; value=words[1]
		else: return {"error":"Line %d: expected set/seta/sets <name> <value>, or map <id>."%line_number}
		if not DEFAULTS.has(key): return {"error":"Line %d: unsupported setting %s."%[line_number,key]}
		if RANGES.has(key):
			if not value.is_valid_int(): return {"error":"Line %d: %s requires an integer."%[line_number,key]}
			var number:=value.to_int()
			if number<RANGES[key].x or number>RANGES[key].y: return {"error":"Line %d: %s is out of range."%[line_number,key]}
			values[key]=number
		else:
			if value.is_empty() or value.length()>80: return {"error":"Line %d: empty or excessive value."%line_number}
			values[key]=value
	return {"values":values}

static func tokens(line: String) -> Dictionary:
	var words: Array=[]
	var word:=""
	var quoted:=false
	var started:=false
	var i:=0
	while i<line.length():
		var c:=line[i]
		if not quoted and (c=="#" or (c=="/" and i+1<line.length() and line[i+1]=="/")): break
		if c=='"': quoted=not quoted; started=true
		elif c=="\\" and quoted and i+1<line.length() and line[i+1] in ['"',"\\"]:
			i+=1; word+=line[i]
		elif not quoted and c in [" ","\t","\r"]:
			if started: words.append(word); word=""; started=false
		elif not quoted and c==";": return {"error":"Semicolon commands are not supported."}
		else: word+=c; started=true
		i+=1
	if quoted: return {"error":"Unclosed quote."}
	if started: words.append(word)
	return {"words":words}

static func read_config(path: String) -> Dictionary:
	var f:=FileAccess.open(path,FileAccess.READ)
	if not f: return {"error":"Cannot read server config: "+path}
	if f.get_length()>65536: return {"error":"Server config exceeds 64 KiB."}
	return parse(f.get_as_text())
