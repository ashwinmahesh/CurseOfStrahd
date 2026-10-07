// Weather on the Modern world's surfaces (Improvement Ideas W12), shared by lit.gdshader and lit_world.gdshader. The
// place's weather sets the global uniforms (Atmosphere): rain wets everything, darker and glossier, with puddles in the
// low places of the ground ringing with drops; snow settles on what faces up above the ground (roofs, ledges, wall
// tops, barrels). (The party's footprints in snow and mud are decals, Atmosphere._footprints.)
// (world_wet is declared in lit_light.gdshaderinc, which every shader including this one includes first.)
global uniform float world_snow;
global uniform float world_time;
// The sky's light the place reflects (Atmosphere, by the time of day): puddles take it at a glancing angle.
global uniform vec4 world_sky;

// Snow, a little blue (between the palette's frost and moonlight, so it doesn't glare in the dark tone).
const vec3 WS_SNOW = vec3(0.68, 0.75, 0.82);

float ws_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float ws_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(ws_hash(i), ws_hash(i + vec2(1.0, 0.0)), u.x), mix(ws_hash(i + vec2(0.0, 1.0)), ws_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Rings spreading where raindrops land in a puddle: the slope they give the surface.
vec2 ws_rain_slope(vec2 p) {
	vec2 cell = floor(p * 3.0);
	vec2 f = fract(p * 3.0);
	vec2 slope = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cell + vec2(float(i), float(j));
			float t = fract(world_time * 1.1 + ws_hash(c));
			vec2 d = f - vec2(float(i), float(j)) - vec2(ws_hash(c + 3.1), ws_hash(c + 7.7));
			float r = length(d);
			float wave = cos((r - t * 0.5) * 45.0) * smoothstep(0.06, 0.0, abs(r - t * 0.5)) * (1.0 - t);
			slope += (r > 0.0001 ? d / r : vec2(0.0)) * wave;
		}
	}
	return slope;
}

// How much of a puddle a ground point is: the low places of a slow noise, on level ground near the floor.
float ws_puddle(vec3 p, bool top) {
	if (world_wet <= 0.0 || !top || p.y > 0.3) {
		return 0.0;
	}
	float n = ws_noise(p.xz * 0.7) * 0.65 + ws_noise(p.xz * 2.1 + 9.1) * 0.35;
	return smoothstep(0.61, 0.65, n) * world_wet;
}

// How much snow lies on a point: on faces turned up, thickest on the flattest, broken by noise. Above the ground
// (roofs, ledges, wall tops, barrels) it settles even in light snow; on the ground it lies in drifts that join up as
// the snow gets heavier (Atmosphere.SNOW_GROUND: where it lies, footprints show).
float ws_snow(vec3 p, vec3 wn) {
	if (world_snow <= 0.0) {
		return 0.0;
	}
	float up = smoothstep(0.55, 0.85, wn.y);
	if (p.y < 0.25) {
		float drift = ws_noise(p.xz * 0.55) * 0.65 + ws_noise(p.xz * 2.3 + 4.7) * 0.35;
		return up * smoothstep(1.05 - world_snow * 0.8, 1.15 - world_snow * 0.6, drift + 0.25);
	}
	float n = ws_noise(p.xz * 2.1 + p.y * 3.0);
	return up * smoothstep(0.75 - world_snow * 0.6, 0.95 - world_snow * 0.5, n + up * 0.3);
}
