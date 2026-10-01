extends RefCounted
## Lifecycle cues supplement reports; embedded pump/reload tails stay in those reports.
## Quiet firearm idle is intentional. No invented pre-fire delay changes gameplay.
static func for_weapon(rules:String,slot:int) -> Dictionary:
	if rules=='doom':
		if slot==1:return {'select':'saw_ready','idle':'saw_idle','stop':'saw_settle'}
		# BFG startup already plays on accepted trigger, before its .86s launch.
		return {}
	if rules=='ut99':
		match slot:
			0:return {'select':'energy_select','charge_start':'hammer_start','charge_loop':'hammer_charge','cancel':'pressure_release'}
			1:return {'select':'energy_select','charge_start':'bio_valve','charge_loop':'bio_charge','cancel':'bio_settle','after':'bio_settle','after_at':.55}
			5:return {'select':'rifle_draw','run':'rotor_run','stop':'rotor_stop'}
			6:return {'select':'rifle_draw','charge_start':'rocket_load','stage':'rocket_load','stages':6,'after':'launcher_close','after_at':.58}
			7:return {'select':'energy_select','run':'pulse_run','stop':'pulse_stop'}
			2,9:return {'select':'pistol_draw' if slot==2 else 'rifle_draw'}
			_:return {'select':'energy_select'}
	if rules=='quake':
		if slot==8:return {'start':'lightning_start','run':'lightning_run','stop':'lightning_stop'}
		return {}
	if rules=='tf_flame':return {'start':'flame_ignite','stop':'flame_out'}
	if rules=='tribes':
		match slot:
			0,1:return {'select':'energy_select','after':'plasma_vent','after_at':.60}
			2:return {'select':'rifle_draw','start':'rotor_start','run':'rotor_run','stop':'rotor_stop'}
			3:return {'select':'energy_select','after':'disc_reseat','after_at':.52}
			4:return {'select':'rifle_draw','after':'launcher_close','after_at':.55}
			5:return {'select':'energy_select','after':'laser_reset','after_at':.58}
			6:return {'select':'energy_select','start':'lightning_start','run':'elf_run','stop':'lightning_stop'}
			7:return {'select':'rifle_draw','after':'mortar_reseat','after_at':.54}
			8:return {'select':'energy_select','run':'repair_run','stop':'pressure_release'}
			11:return {'select':'energy_select'}
		return {}
	if rules in ['cs16','tf_sniper']:
		if slot==0:return {}
		if slot==9:return {'select':'rifle_draw','after':'bolt_cycle','after_at':.42,'manual_after':false}
		return {'select':'pistol_draw' if slot in [1,2,10] else 'rifle_draw'}
	return {}
