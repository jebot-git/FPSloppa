extends RefCounted
## Real plugin encoder, deterministic tone input; no production fallback codec.
static func encoder() -> TwovoipOpusEncoder:
	var enc:=TwovoipOpusEncoder.new()
	assert(enc.initialize(48000,48000,1,TwovoipOpusEncoder.DENOISER_DISABLED,TwovoipOpusEncoder.AGC_DISABLED,960)==OK)
	assert(enc.create_opus_encoder(24000,5,true))
	return enc
static func packet(enc: TwovoipOpusEncoder,offset: int=0) -> PackedByteArray:
	var frames:=PackedVector2Array()
	for i in range(960):frames.append(Vector2.ONE*sin((i+offset)*TAU*440/48000.0)*.25)
	assert(enc.process_chunk(frames)==960)
	return enc.encode_chunk(PackedByteArray([0,0]))
