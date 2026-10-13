extends "res://tools/vrm_to_mdl/match_compare.gd"
func source_models() -> Array:
	var models: Array=JSON.parse_string(FileAccess.get_file_as_string("res://test-results/ranger-match/input-models.json"))
	var sources: Array=[]
	for model in models:
		sources.append({"name":model.name,"path":model.path,"metadata":{"source":{"hash":model.hash,"title":model.title}}})
	return sources
func finish() -> void:
	await super.finish()
