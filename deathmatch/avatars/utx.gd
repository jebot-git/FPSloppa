extends RefCounted
## Texture-only Unreal Engine 1 package reader. Never loads Unreal objects/scripts.
## Native format facts checked against the previous converter's UE Viewer reader.
const MAX_BYTES:=25_000_000
class Reader:
	var bytes:PackedByteArray
	var at:=0
	var end:=0
	var error:=""
	func _init(data:PackedByteArray,start:int=0,finish:int=-1):bytes=data;at=start;end=data.size() if finish<0 else finish
	func take(count:int) -> PackedByteArray:
		if count<0 or at<0 or at+count>end:error="Truncated or out-of-range UTX data.";at=end;return PackedByteArray()
		var value:=bytes.slice(at,at+count);at+=count;return value
	func byte() -> int:
		if at>=end:error="Truncated UTX byte.";return 0
		var value:=bytes[at];at+=1;return value
	func u32() -> int:
		var raw:=take(4);return raw.decode_u32(0) if raw.size()==4 else 0
	func compact() -> int:
		var first:=byte();var value:=first&63;var shift:=6;var more:=bool(first&64)
		for i in 4:
			if not more:break
			var b:=byte()
			if i==3 and b>15:error="Invalid UTX compact index.";return 0
			value|=(b&127)<<shift;shift+=7;more=bool(b&128)
		if more or value>2147483647:error="Invalid UTX compact index.";return 0
		return -value if first&128 else value
	func name(table:Array) -> String:
		var index:=compact()
		if index<0 or index>=table.size():error="Invalid UTX name reference.";return ""
		return table[index]
static func properties(r:Reader,names:Array) -> Dictionary:
	var values:={}
	for _i in 256:
		var name:=r.name(names)
		if not r.error.is_empty():return {}
		if name=="None":return values
		var info:=r.byte();var kind:=info&15
		if kind==0:r.error="Invalid UTX property type.";return {}
		if kind==10:r.name(names) # Struct name, then size tag.
		var size_code:=(info>>4)&7
		var size:int=[1,2,4,12,16,0,0,0][size_code]
		if size_code==5:size=r.byte()
		elif size_code==6:
			var lo:=r.byte();size=lo|(r.byte()<<8)
		elif size_code==7:size=r.u32()
		if kind==3:values[name]=bool(info&128);continue # Boolean is in the tag.
		if info&128:
			var index:=r.byte()
			if index&128:
				r.byte()
				if index&64:r.byte();r.byte()
		if size>1_048_576:r.error="UTX property exceeds limit.";return {}
		var data:=r.take(size)
		if not r.error.is_empty():return {}
		if name=="Palette" and kind==5:
			var object_ref:=Reader.new(data);values[name]=object_ref.compact()
			if not object_ref.error.is_empty():r.error=object_ref.error;return {}
		elif name=="Format" and kind==1 and data.size()==1:values[name]=data[0]
	r.error="UTX property count exceeds limit.";return {}
static func read(path:String) -> Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if not file:return {"error":"Cannot open UTX skin package."}
	if file.get_length()<36 or file.get_length()>MAX_BYTES:return {"error":"UTX skin package must be between 36 bytes and 25 MB."}
	return parse(file.get_buffer(file.get_length()),path.get_file())
static func parse(bytes:PackedByteArray,filename:String="skin.utx") -> Dictionary:
	if bytes.size()<36 or bytes.size()>MAX_BYTES:return {"error":"UTX size exceeds limits."}
	var r:=Reader.new(bytes)
	if r.u32()!=0x9E2A83C1:return {"error":"Expected a classic UT99 UTX skin package."}
	var version_word:=r.u32();var version:=version_word&65535
	if version<61 or version>69 or version_word>>16!=0:return {"error":"Unsupported UTX version; use classic UT99 packages (61–69)."}
	r.u32()
	var name_count:=r.u32();var name_offset:=r.u32();var export_count:=r.u32();var export_offset:=r.u32();var import_count:=r.u32();var import_offset:=r.u32()
	if name_count<1 or name_count>8192 or export_count<1 or export_count>2048 or import_count>4096:return {"error":"UTX object table exceeds limits."}
	for offset in [name_offset,export_offset,import_offset]:
		if offset<36 or offset>=bytes.size():return {"error":"Invalid UTX table offset."}
	var names:Array=[];r.at=name_offset
	for _i in name_count:
		var name:=""
		if version<64:
			var chars:=PackedByteArray()
			for _j in 1024:
				var b:=r.byte()
				if b==0:break
				chars.append(b)
			if chars.size()>=1024:return {"error":"UTX name exceeds limit."}
			name=chars.get_string_from_ascii()
		else:
			var length:=r.compact()
			if length<1 or length>1024:return {"error":"Unsupported or oversized UTX name."}
			var data:=r.take(length)
			if data.size()!=length or data[-1]!=0:return {"error":"Invalid UTX name termination."}
			name=data.slice(0,length-1).get_string_from_ascii()
		r.u32();names.append(name)
		if not r.error.is_empty():return {"error":r.error}
	var imports:Array=[];r.at=import_offset
	for _i in import_count:
		r.name(names);r.name(names);r.u32();imports.append(r.name(names))
		if not r.error.is_empty():return {"error":r.error}
	var exports:Array=[];r.at=export_offset
	for _i in export_count:
		var class_ref:=r.compact();r.compact();r.u32();var name:=r.name(names);var flags:=r.u32();var size:=r.compact();var offset:=r.compact() if size>0 else 0
		if not r.error.is_empty():return {"error":r.error}
		if size<0 or offset<0 or offset+size>bytes.size() or (size>0 and offset<36):return {"error":"Invalid UTX export bounds."}
		var type:String=imports[-class_ref-1] if class_ref<0 and -class_ref<=imports.size() else ""
		exports.append({"type":type,"name":name,"flags":flags,"offset":offset,"size":size})
	var palettes:={};var textures:={};var pixel_budget:=0
	for i in exports.size():
		var object:Dictionary=exports[i]
		if object.type not in ["Palette","Texture"]:continue
		if object.flags&0x02000000:return {"error":"Stateful UTX objects are not supported."}
		var sub:=Reader.new(bytes,object.offset,object.offset+object.size)
		var props:=properties(sub,names)
		if not sub.error.is_empty():return {"error":sub.error}
		if object.type=="Palette":
			if sub.compact()!=256:return {"error":"Expected a 256-color UT99 palette."}
			palettes[i+1]=sub.take(1024)
		else:
			var count:=sub.compact()
			if count<1 or count>12:return {"error":"Invalid UTX mip count."}
			var top:={}
			for level in count:
				if version>61:sub.u32() # Lazy-array end marker; actual reads stay inside export.
				var length:=sub.compact()
				if length<1 or length>16_777_216:return {"error":"UTX mip exceeds limit."}
				var pixels:=sub.take(length);var width:=sub.u32();var height:=sub.u32();sub.byte();sub.byte()
				if width<1 or height<1 or width>2048 or height>2048:return {"error":"UTX texture dimensions exceed 2048 pixels."}
				if level==0:top={"pixels":pixels,"width":width,"height":height,"format":int(props.get("Format",0)),"palette":int(props.get("Palette",0)),"name":object.name}
			var format:int=top.format
			var expected:int=top.width*top.height if format==0 else ceili(top.width/4.0)*ceili(top.height/4.0)*(8 if format==3 else 16) if format in [3,7,8] else -1
			if expected<0:return {"error":"Unsupported UTX texture format; use paletted P8 or DXT1/3/5 skin textures."}
			if top.pixels.size()!=expected:return {"error":"UTX mip size does not match texture format."}
			pixel_budget+=int(top.width)*int(top.height)*4
			if pixel_budget>64_000_000 or textures.size()>=512:return {"error":"UTX decoded texture budget exceeded."}
			if textures.has(object.name.to_lower()):return {"error":"Duplicate UTX texture name."}
			textures[object.name.to_lower()]=top
		if not sub.error.is_empty():return {"error":sub.error}
	for name in textures:
		var t:Dictionary=textures[name]
		if t.format==0:
			if not palettes.has(t.palette):return {"error":"UTX references an external or missing palette."}
			t.palette=palettes[t.palette]
	if textures.is_empty():return {"error":"UTX contains no supported skin textures."}
	return {"textures":textures,"filename":filename.get_basename().left(80),"sha256":hash_bytes(bytes),"version":version}
static func hash_bytes(bytes:PackedByteArray) -> String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
static func image(texture:Dictionary) -> Image:
	if texture.format==0:
		var raw:=PackedByteArray();raw.resize(texture.width*texture.height*4)
		var pixels:PackedByteArray=texture.pixels;var palette:PackedByteArray=texture.palette
		for i in pixels.size():
			var color:=int(pixels[i])*4;var offset:=i*4
			raw[offset]=palette[color];raw[offset+1]=palette[color+1];raw[offset+2]=palette[color+2];raw[offset+3]=255
		return Image.create_from_data(texture.width,texture.height,false,Image.FORMAT_RGBA8,raw)
	var format:int={3:Image.FORMAT_DXT1,7:Image.FORMAT_DXT3,8:Image.FORMAT_DXT5}[texture.format]
	var result:=Image.create_from_data(texture.width,texture.height,false,format,texture.pixels)
	if result.decompress()!=OK:return null
	result.convert(Image.FORMAT_RGBA8);return result
