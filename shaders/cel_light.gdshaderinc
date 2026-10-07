// The world's lighting, shared by the cel shaders. Classic (look_soft 0): two or three hard bands, the 1990s cartoon
// the palette pass snaps. Modern (look_soft 1, Look.modern): a soft ramp, so a lantern's light falls off smoothly
// instead of in rings and faces turn gently into shade (docs/plans/ui_polish.md).
global uniform float look_soft;

float cel_band(float lit, float mid_tone, float shadow_floor) {
	float hard = lit > 0.5 ? 1.0 : (lit > 0.12 ? mid_tone : (lit > 0.02 ? shadow_floor : 0.0));
	float soft = smoothstep(0.0, 0.62, lit) * 0.88 + lit * 0.12;
	return mix(hard, soft, look_soft);
}
