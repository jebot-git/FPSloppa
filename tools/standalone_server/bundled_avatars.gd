extends RefCounted
## Cook the same manifest the client picker uses, including non-stock bundled skins.
static func cook(output:String)->Array:
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/avatars/models/manifest.json"))
 assert(manifest is Array)
 var result:Array=[];var seen:Dictionary={}
 DirAccess.make_dir_recursive_absolute(output.path_join("avatars"))
 for row in manifest:
  var path:String=row.path;var hash_value:String=FileAccess.get_sha256(path)
  assert(hash_value==row.hash,"Bundled avatar source/hash mismatch: "+path)
  if seen.has(hash_value):continue
  seen[hash_value]=true
  var parsed:Dictionary=preload("res://deathmatch/avatars/ut_format.gd").read(path)
  assert(not parsed.has("error"),str(parsed.get("error","")))
  var bytes:PackedByteArray=FileAccess.get_file_as_bytes(path)
  FileAccess.open(output.path_join("avatars/"+hash_value+".utavatar"),FileAccess.WRITE).store_buffer(bytes)
  result.append({"hash":hash_value,"size":bytes.size(),"filename":path.get_file(),"reach":parsed.manifest.get("ik_profile",{})})
 return result
