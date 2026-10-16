extends SceneTree
func _initialize()->void:
 var output:=ProjectSettings.globalize_path("res://native_server/cooked")
 var args:=OS.get_cmdline_user_args()
 if args.has("--world-dir"):output=args[args.find("--world-dir")+1]
 var path:=output.path_join("world.json");var metadata=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not metadata is Dictionary:push_error("Cook the world first");quit(1);return
 metadata.avatars=preload("res://tools/standalone_server/bundled_avatars.gd").cook(output)
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(metadata))
 var receipt_path:=output.path_join("receipt.json");var receipt=JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
 if not receipt is Dictionary:push_error("Missing cooked world receipt");quit(1);return
 receipt["world.json"]={"sha256":FileAccess.get_sha256(path),"size":FileAccess.get_file_as_bytes(path).size()}
 FileAccess.open(receipt_path,FileAccess.WRITE).store_string(JSON.stringify(receipt,"  "))
 print("CQ_BUNDLED_AVATAR_CATALOG ",JSON.stringify({"avatars":metadata.avatars.size(),"bytes":metadata.avatars.reduce(func(sum,row):return sum+int(row.size),0)}));quit()
