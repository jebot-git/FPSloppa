extends RefCounted
## Deterministic source: no full-resolution world array or mesh is constructed.
const EXTENT := 2048.0
const TILE := 32.0
const GRID := 64
const SAMPLES := 65
const COARSE_SAMPLES := 129
const TYPES := ["town", "factory", "port", "military"]
const PAD_HEIGHTS := [14.0, 18.0, 2.4, 24.0]
const PAD_RADII := [100.0, 90.0, 110.0, 104.0]

static func site_at(x: int, z: int) -> Dictionary:
	var kind := posmod(x + z, 4)
	return {"kind": kind, "name": TYPES[kind], "position": Vector3(-768.0 + x * 512.0, PAD_HEIGHTS[kind], -768.0 + z * 512.0)}

static func sites() -> Array:
	var result: Array = []
	for z in 4:
		for x in 4: result.append(site_at(x, z))
	return result

static func surface(wx: float, wz: float) -> Vector4:
	var sx := clampi(floori((wx + 1024.0) / 512.0), 0, 3)
	var sz := clampi(floori((wz + 1024.0) / 512.0), 0, 3)
	var kind := posmod(sx + sz, 4)
	var lx := wx - (-768.0 + sx * 512.0)
	var lz := wz - (-768.0 + sz * 512.0)
	var distance := maxf(absf(lx), absf(lz))
	var pad := 1.0 - smoothstep(PAD_RADII[kind], PAD_RADII[kind] + 40.0, distance)
	var rough := sin(wx * .018 + wz * .014) * 2.5
	var natural := 18.0 + sin(wx * .006) * cos(wz * .005) * 9.0 + rough
	var height := lerpf(natural, PAD_HEIGHTS[kind], pad)
	var shade := .5 + .5 * sin(wx * .065 + sin(wz * .07) * 2.0)
	var color := Color(.24, .34, .19).lerp(Color(.42, .40, .25), shade * .55)
	if pad > .99:
		color = [Color(.45, .43, .34), Color(.42, .42, .39), Color(.52, .46, .33), Color(.36, .39, .29)][kind]
	# Roads continue between repeated settlements, with dashed center markings.
	if absf(lx) < 6.0 or absf(lz) < 6.0:
		color = Color(.21, .23, .23)
		if (absf(lx) < .3 and fmod(absf(wz), 12.0) < 6.0) or (absf(lz) < .3 and fmod(absf(wx), 12.0) < 6.0):
			color = Color(.77, .72, .46)
	# Each port has an actual below-water basin south of the quay, not painted water.
	if kind == 2:
		var water := (1.0 - smoothstep(105.0, 130.0, absf(lx))) * smoothstep(55.0, 85.0, lz) * (1.0 - smoothstep(190.0, 220.0, lz))
		height = lerpf(height, -3.0, water)
		color = color.lerp(Color(.25, .32, .30), water)
	return Vector4(height, color.r, color.g, color.b)

static func generate_tile(coord: Vector2i) -> Dictionary:
	var begin := Time.get_ticks_usec()
	var heights := PackedFloat32Array()
	var colors := PackedByteArray()
	heights.resize(SAMPLES * SAMPLES)
	colors.resize(SAMPLES * SAMPLES * 4)
	var origin := Vector2(coord) * TILE - Vector2.ONE * EXTENT * .5
	for z in SAMPLES:
		for x in SAMPLES:
			var value := surface(origin.x + x * .5, origin.y + z * .5)
			var i := z * SAMPLES + x
			heights[i] = value.x
			colors[i * 4] = roundi(value.y * 255.0)
			colors[i * 4 + 1] = roundi(value.z * 255.0)
			colors[i * 4 + 2] = roundi(value.w * 255.0)
			colors[i * 4 + 3] = 255
	return {"coord": coord, "heights": heights.to_byte_array(), "colors": colors, "generation_ms": (Time.get_ticks_usec() - begin) / 1000.0}

static func coarse_images() -> Array[Image]:
	var heights := Image.create(COARSE_SAMPLES, COARSE_SAMPLES, false, Image.FORMAT_RF)
	var colors := Image.create(COARSE_SAMPLES, COARSE_SAMPLES, false, Image.FORMAT_RGBA8)
	for z in COARSE_SAMPLES:
		for x in COARSE_SAMPLES:
			var value := surface(x * 16.0 - 1024.0, z * 16.0 - 1024.0)
			heights.set_pixel(x, z, Color(value.x, 0, 0))
			colors.set_pixel(x, z, Color(value.y, value.z, value.w))
	return [heights, colors]
