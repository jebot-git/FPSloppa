extends SceneTree
const UTX=preload("res://deathmatch/avatars/utx.gd")
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize() -> void:
	var fixtures:={"Soldierskins":"Soldier","commandoskins":"Commando","SGirlSkins":"SGirl","FCommandoSkins":"FCommando","BossSkins":"Boss"}
	for package in fixtures:
		var path:String="res://test-results/ut99/base/source/Textures/"+package+".utx"
		var result:=UTX.read(path)
		check(not result.has("error"),"Parse stock "+package+": "+str(result.get("error","OK")))
		if result.has("error"):continue
		var extracted=JSON.parse_string(FileAccess.get_file_as_string("res://test-results/ut99/base/"+fixtures[package]+"/result.json"))
		var equal:=true;var compared:=0
		for png in extracted.textures:
			var name:String=png.get_file().get_basename().to_lower()
			if not result.textures.has(name):equal=false;continue
			var image:=UTX.image(result.textures[name]);var expected:=Image.load_from_file(png)
			if image==null:equal=false;continue
			var stride:=3 if expected.get_format()==Image.FORMAT_RGB8 else 4
			if expected.get_format() not in [Image.FORMAT_RGB8,Image.FORMAT_RGBA8]:expected.convert(Image.FORMAT_RGBA8);stride=4
			if image.get_size()!=expected.get_size():equal=false;continue
			var a:=image.get_data();var b:=expected.get_data()
			var tolerance:=0 if result.textures[name].format==0 else 1
			# DXT decoders can round interpolated color channels by one byte.
			for i in image.get_width()*image.get_height():
				if abs(int(a[i*4])-int(b[i*stride]))>tolerance or abs(int(a[i*4+1])-int(b[i*stride+1]))>tolerance or abs(int(a[i*4+2])-int(b[i*stride+2]))>tolerance:
					print("PIXEL_MISMATCH ",name," native=",a.slice(i*4,i*4+4)," extracted=",b.slice(i*stride,i*stride+stride));equal=false;break
			compared+=1
		check(equal,"Native UTX RGB matches prior converter exports: "+package+" ("+str(compared)+" textures)")
	var custom:=UTX.read("res://test-results/ut99/SoldierSkinsDictator.utx")
	check(not custom.has("error"),"World Leaders skin package parses")
	check(UTX.parse(PackedByteArray()).has("error"),"Truncated UTX rejected")
	var bytes:=FileAccess.get_file_as_bytes("res://test-results/ut99/SoldierSkinsDictator.utx")
	var bad:=bytes.duplicate();bad.encode_u32(16,0xffffffff)
	check(UTX.parse(bad).has("error"),"Oversized name table rejected before allocation")
	bad=bytes.duplicate();bad.encode_u32(28,0xffffffff)
	check(UTX.parse(bad).has("error"),"Invalid import count rejected")
	print("UTX_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
