extends Node
## Per-instance visual action. Sleeps at rest; never changes weapon timing or aim.
var parts: Array=[]
var lamps: Array=[]
var elapsed:=1.0
var duration:=.2
var heat:=0.0
var spin:=0.0
var angle:=0.0
var charge:=0.0
var slot:=0
var rules:=""
func _ready():set_process(elapsed<duration or heat>0 or spin>0 or charge>0)
func setup(model: Node3D,index: int,profile: String):
	name="WeaponMechanism";slot=index;rules=profile
	for node in model.find_children('*','Node3D',true,false):
		if node.has_meta('motion'):parts.append({'node':node,'rest':node.transform,'kind':node.get_meta('motion'),'amount':node.get_meta('amount')})
		if rules=='ut99' and slot==0 and str(node.name) in ['Impact face','Impact face rim','Pneumatic piston']:
			parts.append({'node':node,'rest':node.transform,'kind':'ram','amount':Vector3(0,0,.085)})
		if node is MeshInstance3D and node.has_meta('emission_color'):
			for surface in node.mesh.get_surface_count():
				var source=node.get_active_material(surface)
				if not source is StandardMaterial3D or not source.emission_enabled:continue
				var material:StandardMaterial3D=source.duplicate();material.emission=node.get_meta('emission_color');material.albedo_color=material.emission;material.emission_energy_multiplier=.6
				if material.has_meta('fpsloppa_filter_variants'):material.remove_meta('fpsloppa_filter_variants')
				node.set_surface_override_material(surface,material);lamps.append({'mesh':node,'surface':surface,'material':material})
	set_process(false)
func shot(cycle: float=.2):
	elapsed=0;duration=clampf(cycle,.10,1.35);heat=minf(1,heat+.28);spin=minf(1,spin+.65);set_process(true);pose()
func charging(value: float):
	value=clampf(value,0,1)
	if is_equal_approx(value,charge):return
	charge=value;set_process(true);pose()
func _process(delta: float):
	elapsed+=delta;heat=move_toward(heat,0,delta*.65);spin=move_toward(spin,0,delta*1.4)
	angle=fposmod(angle+delta*(spin*36+charge*12),TAU);pose()
	if elapsed>=duration and heat==0 and spin==0 and charge==0:set_process(false)
func pose():
	var phase:=clampf(elapsed/duration,0,1)
	var stroke:=sin(phase*PI)
	for p in parts:
		var node:Node3D=p.node;node.transform=p.rest
		match p.kind:
			'spin':node.transform.basis=p.rest.basis*Basis(p.amount.normalized(),angle)
			'vent':node.position+=p.amount*maxf(heat,charge)
			'ram':node.position+=p.amount*(charge-stroke)
			'hinge':node.rotation+=p.amount*stroke
			'bolt':
				node.rotation.z-=sin(clampf(phase/.25,0,1)*PI*.5)*.55 if phase<.5 else sin(clampf((1-phase)/.25,0,1)*PI*.5)*.55
				node.position+=p.amount*sin(clampf((phase-.2)/.65,0,1)*PI)
			'pump':node.position+=p.amount*sin(clampf((phase-.18)/.72,0,1)*PI)
			_:node.position+=p.amount*stroke
	for lamp in lamps:
		# Settings may replace a material after construction; keep the pulse local.
		var active=lamp.mesh.get_active_material(lamp.surface)
		if active!=lamp.material:
			lamp.material=active.duplicate()
			if lamp.material.has_meta('fpsloppa_filter_variants'):lamp.material.remove_meta('fpsloppa_filter_variants')
			lamp.mesh.set_surface_override_material(lamp.surface,lamp.material)
		lamp.material.emission_energy_multiplier=.6+charge*1.4+heat*.65+maxf(0,1-elapsed/.12)*1.8
