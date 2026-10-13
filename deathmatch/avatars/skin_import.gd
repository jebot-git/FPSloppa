extends RefCounted
const Format=preload("res://deathmatch/avatars/ut_format.gd")
const UTX=preload("res://deathmatch/avatars/utx.gd")
const RULES={"Soldier":{"suffixes":["1","2","3","4"],"face":"4"},"Commando":{"suffixes":["1","2","3","4"],"face":"2"},"SGirl":{"suffixes":["1","2","3","4"],"face":"4"},"FCommando":{"suffixes":["1","2","4"],"face":"4"},"Boss":{"suffixes":["1","2","3","4","4"],"face":"4"}}
static func groups(package:Dictionary,model:String) -> Array:
	if not RULES.has(model) or package.has("error") or not package.get("textures") is Dictionary:return []
	var result:Array=[];var rule:Dictionary=RULES[model]
	for name in package.textures:
		if not name.ends_with("1"):continue
		var prefix:String=name.left(name.length()-1);var complete:=true
		for suffix in rule.suffixes:
			if suffix!=rule.face and not package.textures.has(prefix+suffix):complete=false
		if complete and not faces(package,model,prefix).is_empty():result.append(prefix)
	result.sort();return result
static func faces(package:Dictionary,model:String,group:String) -> Array:
	if not RULES.has(model) or package.has("error") or not package.get("textures") is Dictionary:return []
	var prefix:String=group+RULES[model].face;var result:Array=[]
	for name in package.textures:
		if name.begins_with(prefix) and not name.contains("t_"):
			result.append(name)
	result.sort();return result
# UTX textures do not contain a definitive player-model reference. Only score
# prepared models whose required slots exist; expose ambiguity to the player.
static func recognize(package:Dictionary,available:Array,fallback:String="Soldier") -> Dictionary:
	var candidates:Array=[]
	for model in RULES:
		if available.has(model) and not groups(package,model).is_empty():candidates.append(model)
	if candidates.is_empty():return {"model":fallback if available.has(fallback) else (available[0] if not available.is_empty() else ""),"confidence":"unknown","reason":"No compatible texture layout found. Choose a base model manually.","candidates":candidates}
	var filename:String=package.get("filename","").to_lower()
	var named:=""
	# Test female names first: FCommando also contains Commando.
	for pair in [["fcommando","FCommando"],["sgirl","SGirl"],["commando","Commando"],["boss","Boss"],["soldier","Soldier"]]:
		if filename.contains(pair[0]):named=pair[1];break
	if candidates.has(named):return {"model":named,"confidence":"likely","reason":"Package name and texture slots match.","candidates":candidates}
	if candidates.size()==1:return {"model":candidates[0],"confidence":"likely","reason":"Only this prepared model matches the texture layout.","candidates":candidates}
	# Commando's face is slot 2; the others use slot 4. Named face variants
	# distinguish its layout even when a package has been renamed.
	if candidates.has("Commando"):
		var face2:=0;var face4:=0
		for group in groups(package,"Commando"):
			for name in package.textures:
				if name.contains("t_"):continue
				if name.begins_with(group+"2") and name.length()>group.length()+1:face2+=1
				if name.begins_with(group+"4") and name.length()>group.length()+1:face4+=1
		if face2>0 and face4==0:return {"model":"Commando","confidence":"likely","reason":"Named face variants use Commando's slot 2.","candidates":candidates}
	var chosen:String=fallback if candidates.has(fallback) else candidates[0]
	return {"model":chosen,"confidence":"ambiguous","reason":"Several models share these texture slots. Check the model or override it.","candidates":candidates}
static func build(package:Dictionary,template:Dictionary,group:String,face:String,output:String) -> Dictionary:
	var model:String=template.get("base_model","")
	if not groups(package,model).has(group) or not faces(package,model,group).has(face):return {"error":"Select a complete skin family and matching face for this base model."}
	var decoded:=Format.read(template.path)
	if decoded.has("error"):return decoded
	var m:Dictionary=decoded.manifest.duplicate(true);var rule:Dictionary=RULES[model];var count:int=rule.suffixes.size()
	var columns:=ceili(sqrt(count));var cell:int=int(m.skin_width)/columns
	if cell<8 or int(m.skin_width)%columns!=0 or m.skin_height!=ceili(float(count)/columns)*cell:return {"error":"Invalid prepared base model atlas layout."}
	var atlas:=Image.create(int(m.skin_width),int(m.skin_height),false,Image.FORMAT_RGBA8);atlas.fill(Color.BLACK)
	var selected:Array=[]
	for i in count:
		var name:String=face if rule.suffixes[i]==rule.face else group+rule.suffixes[i]
		var image:=UTX.image(package.textures[name])
		if image==null:return {"error":"Cannot decode selected UTX skin texture."}
		image.resize(cell-4,cell-4,Image.INTERPOLATE_LANCZOS)
		# Opaque atlas, matching the template UV padding and mipmap boundaries.
		var data:=image.get_data()
		for pixel in image.get_width()*image.get_height():data[pixel*4+3]=255
		image=Image.create_from_data(cell-4,cell-4,false,Image.FORMAT_RGBA8,data)
		var x: int=(i%columns)*cell;var y:int=(i/columns)*cell;var size:=cell-4
		atlas.blit_rect(image,Rect2i(0,0,size,size),Vector2i(x+2,y+2))
		for padding in 2:
			atlas.blit_rect(image,Rect2i(0,0,size,1),Vector2i(x+2,y+padding));atlas.blit_rect(image,Rect2i(0,size-1,size,1),Vector2i(x+2,y+cell-1-padding))
			atlas.blit_rect(image,Rect2i(0,0,1,size),Vector2i(x+padding,y+2));atlas.blit_rect(image,Rect2i(size-1,0,1,size),Vector2i(x+cell-1-padding,y+2))
		for cx in 2:
			for cy in 2:atlas.fill_rect(Rect2i(x+(cell-2 if cx else 0),y+(cell-2 if cy else 0),2,2),image.get_pixel(size-1 if cx else 0,size-1 if cy else 0))
		selected.append(name)
	var png:=atlas.save_png_to_buffer()
	m.skin_bytes=png.size();m.title=("UTX · "+package.filename+" · "+face).left(256);m.author="UT99 base model: Epic Games / Digital Extremes; user-supplied skin";m.license="Original model and imported skin author terms apply"
	m.base_model=model;m.source_skin_hash=package.sha256;m.skin_textures=selected
	var metadata:=JSON.stringify(m,"",true,true).to_utf8_buffer()
	var total:int=16+metadata.size()+decoded.positions.size()+png.size()
	if total>Format.MAX_BYTES:return {"error":"Imported skin avatar exceeds 25 MB."}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if not file:return {"error":"Cannot save imported skin."}
	file.store_buffer("UTAV".to_ascii_buffer());file.store_32(1);file.store_32(total);file.store_32(metadata.size());file.store_buffer(metadata);file.store_buffer(decoded.positions);file.store_buffer(png);file.close()
	return {"path":output,"model":model,"skin_textures":selected,"source_skin_hash":package.sha256}
