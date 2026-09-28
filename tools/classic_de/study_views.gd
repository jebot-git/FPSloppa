extends "res://tools/classic_de/verify.gd"
## Native scene captures of the four changed tactical features.
func views():
	match data.id:
		"de_nuke_rebuilt":data.views=[{"name":"study-hut","eye":[461,286,86],"look":[426,320,70]}]
		"de_inferno_rebuilt":data.views=[{"name":"study-apartments","eye":[474,571,155],"look":[574,571,155]}]
		"de_train_rebuilt":data.views=[{"name":"study-upper-hall","eye":[182,335,155],"look":[182,442,118]}]
		"de_aztec_rebuilt":data.views=[{"name":"study-canal-ramp","eye":[264,248,-180],"look":[216,231,83]}]
	await super.views()
