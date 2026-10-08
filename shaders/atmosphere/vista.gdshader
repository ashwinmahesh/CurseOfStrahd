// The mountains round the valley (Vista, Improvement Ideas W13): a ring far past the map's edge painted as four
// ridges, the farthest palest, each fading into the haze the screen pass gives the land past the edge (`haze`, its
// land colour, matched each frame), with light along the ridge tops, snow on the high peaks and a fringe of trees on
// the nearer ridges. Seen when the camera tilts toward the horizon past its farthest zoom. It draws after the screen
// pass (a blended pass), so the land's fade doesn't swallow it; nearer land and trees still hide it.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec3 centre = vec3(0.0);
uniform vec3 haze : source_color = vec3(0.4, 0.4, 0.46);
uniform vec3 shade : source_color = vec3(0.07, 0.07, 0.1);
uniform vec3 rim : source_color = vec3(0.6, 0.6, 0.66);
uniform vec3 snow : source_color = vec3(0.78, 0.8, 0.86);
// Each ridge from the farthest: x its height, y how far it rises above that, z how rough, w how far into the haze.
uniform vec4 ridge0 = vec4(24.0, 14.0, 2.0, 0.78);
uniform vec4 ridge1 = vec4(13.0, 9.0, 3.4, 0.6);
uniform vec4 ridge2 = vec4(5.0, 5.0, 6.0, 0.4);
uniform vec4 ridge3 = vec4(-1.0, 3.0, 9.0, 0.22);
uniform float snow_line = 33.0;
uniform float treeline = 0.9;
// Where the ring sinks into the haze (its foot, out of sight behind the land).
uniform float foot = -10.0;
uniform float glow = 0.0;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// A ridge line round the ring: noise sampled on a circle (so it closes on itself), folded into sharp peaks.
float ridge(vec4 r, vec2 dir, float seed) {
	vec2 p = dir * r.z + vec2(seed * 7.31, seed * 3.17);
	float n = 0.0;
	float a = 0.55;
	for (int i = 0; i < 5; i++) {
		float v = vnoise(p);
		float k = 1.0 - abs(v * 2.0 - 1.0);
		n += a * k * k;
		p *= 2.07;
		a *= 0.48;
	}
	return r.x + r.y * (n - 0.3) * 2.0;
}

// Spruce tops along a ridge: narrow spikes, denser on the nearer ridges.
float trees(vec2 dir, float n, float seed) {
	float a = atan(dir.y, dir.x) * n + seed;
	float k = fract(a);
	float spike = 1.0 - abs(k * 2.0 - 1.0);
	float tall = 0.5 + vnoise(vec2(floor(a), seed)) * 0.8;
	return spike * spike * tall;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 d = normalize(wpos.xz - centre.xz + vec2(1e-4));
	float h = wpos.y;
	vec4 rs[4] = vec4[](ridge0, ridge1, ridge2, ridge3);
	vec3 col = vec3(0.0);
	bool covered = false;
	for (int i = 0; i < 4; i++) {
		float top = ridge(rs[i], d, float(i) + 1.0);
		if (i >= 2 && treeline > 0.0) {
			top += trees(d, 520.0 + float(i) * 260.0, float(i)) * treeline * (i == 3 ? 1.6 : 1.1);
		}
		if (h < top) {
			covered = true;
			float below = top - h;
			vec3 c = mix(shade, haze, rs[i].w);
			// The sky's light along the ridge's crest, fading down its face.
			c = mix(c, rim, (1.0 - smoothstep(0.0, 0.8 + rs[i].y * 0.05, below)) * 0.3 * rs[i].w);
			// Snow on the far, high peaks: caps that break into streaks down their faces, rock showing between.
			float above = h - snow_line + vnoise(vec2(atan(d.y, d.x) * 30.0, 0.5)) * 3.0;
			if (i <= 1 && above > 0.0) {
				float streak = smoothstep(0.4, 0.62, vnoise(vec2(atan(d.y, d.x) * 140.0, h * 0.6)));
				float cover = max(streak, smoothstep(1.5, 4.0, above)) * smoothstep(0.0, 0.8, above);
				c = mix(c, mix(snow, haze, rs[i].w * 0.55), 0.75 * cover);
			}
			col = c;
		}
	}
	if (!covered) {
		discard;
	}
	// The foot sinks into the haze, as the land past the edge does.
	col = mix(col, haze, 1.0 - smoothstep(foot, foot + 12.0, h));
	ALBEDO = col + haze * glow;
	ALPHA = 1.0;
}
