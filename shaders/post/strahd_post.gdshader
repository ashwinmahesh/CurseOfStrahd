// Final look pass (plan §4.1): cartoon outlines from depth and normal edges, the place's atmosphere, then every
// pixel snapped to the Strahd palette. Drawn on a full-screen quad (Look.make_post_process). UI lives on
// CanvasLayers and character sprites draw after this, so both are exempt and stay clear.
//
// The atmosphere (world/look/atmosphere.gd sets it per place and time of day, docs/art/atmosphere.md) works on the
// world position behind each pixel, so it is the same from frame to frame and never adds grain: shadows of clouds
// drifting over the ground, a layer of ground mist that drifts with the wind (lit by the lanterns standing in it),
// the wall of the Mists at a map's edge, the place's colour grade and a vignette. All of it happens before the
// palette snap, so it comes out as flat bands of palette colours like the rest of the world.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
// N x 1 strip from art/palette/strahd_palette.png, read raw (sRGB values).
uniform sampler2D palette_tex : filter_nearest;
uniform int palette_size = 46;
uniform bool quantize = true;
// The modern finish (Look.modern, docs/plans/ui_polish.md): mist, cloud shadows, ground patches and the land's fade
// come out smooth instead of in flat bands, and light brighter than white (flames, lanterns) is passed on so the
// glow can bloom it.
uniform bool soft_bands = false;
uniform bool keep_hdr = false;
uniform bool keep_greys = false;
uniform float dither_strength : hint_range(0.0, 0.2) = 0.045;
// Pixel size of the art grid. 1 = native; 2 makes chunkier pixels.
uniform float pixel_size : hint_range(1.0, 6.0) = 2.0;
uniform bool outlines = true;
uniform float outline_width : hint_range(0.5, 4.0) = 1.5;
// The Modern finish (Improvement Ideas W15) keeps the world's ink lines to silhouettes against what's behind them, and
// lighter, or leaves them off, so the 2D characters' ink stands apart from the lit 3D world: no lines where faces
// meet at an angle, and the lines' strength.
uniform bool outline_creases = true;
uniform float outline_strength : hint_range(0.0, 1.0) = 1.0;
uniform float depth_threshold = 0.06;
uniform float normal_threshold = 0.55;
uniform vec3 outline_color : source_color = vec3(0.051, 0.039, 0.071);

// --- Atmosphere (all off by default, so scenes without an Atmosphere look as before) ---
// The time the drifting things are at (Atmosphere sets it, so captures can hold it still).
uniform float atmo_time = 0.0;
// The land past the map fades into the sky colour: the map's rectangle on the ground (x0, z0, x1, z1), how far out the
// fade starts and how far it takes.
uniform vec4 land_rect = vec4(0.0);
uniform vec2 land_fade = vec2(4.0, 14.0);
uniform vec3 land_color : source_color = vec3(0.1, 0.08, 0.12);
// Ground mist: a layer `mist_height` deep over the ground (y = 0), patchy where the noise is thin.
uniform float mist_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 mist_color : source_color = vec3(0.6, 0.55, 0.7);
uniform float mist_height = 1.2;
uniform float mist_floor = -0.4;
// Outdoors the mist lies on past the land around the map; indoors the dark around the rooms stays clear.
uniform bool mist_beyond = true;
uniform float mist_cover : hint_range(0.0, 1.0) = 0.5;
uniform float mist_scale = 0.12;
uniform vec2 mist_wind = vec2(0.25, 0.08);
uniform float mist_thickness = 1.6;
uniform float mist_bands = 3.0;
// How much the streaks are drawn out along the wind (1 = round patches).
uniform float mist_stretch = 0.5;
// How strong the thin strands of mist are.
uniform float mist_wisps = 0.9;
// Where on the map the mist gathers (one texel per square, 0..1 in red): by the trees and in the hollows.
uniform sampler2D mist_mask : filter_linear, repeat_disable;
uniform bool use_mist_mask = false;
// The ground under the mist where a map isn't level (natural elevation, raised props): its height at each square's
// middle in world units, one texel per square like the mask. The mist lies over raised ground as over level ground,
// and past the map's edge it settles back toward the land's level.
uniform sampler2D ground_height : filter_linear, repeat_disable;
uniform bool use_ground_height = false;
// The wall of the Mists: thick fog past a line on the ground (xz direction pointing out of the map, the distance of
// the line from the origin along it, how far it takes to thicken).
uniform vec4 mist_wall = vec4(0.0, 0.0, 0.0, 0.0);
uniform float mist_wall_height = 6.0;
uniform vec3 mist_wall_color : source_color = vec3(0.54, 0.54, 0.59);
// Lanterns and fires lighting the mist around them: xyz position, w reach; colour rgb (sRGB), a strength.
uniform int glow_count = 0;
uniform vec4 glow_pos[8];
uniform vec4 glow_col[8];
// Broad light and dark patches over level ground (0 = none).
uniform float ground_variation : hint_range(0.0, 1.0) = 0.0;
// Cloud shadows sweeping the ground (0 = none).
uniform float cloud_strength : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_scale = 0.035;
uniform vec2 cloud_wind = vec2(0.6, 0.25);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.55;
// Grade: exposure, contrast and saturation, then a gradient map through the place's shadow and light colours.
uniform float exposure = 1.0;
uniform float contrast = 1.0;
uniform float saturation = 1.0;
uniform vec3 grade_shadows : source_color = vec3(0.5);
uniform vec3 grade_lights : source_color = vec3(0.5);
uniform float grade_amount : hint_range(0.0, 1.0) = 0.0;
// The Modern finish's grade (Improvement Ideas W16) in place of the gradient map: the shade is pulled towards the
// place's shadow colour and drained of colour and its blacks deepened, while lit ground keeps the colour of what
// lights it, so lamplight pools warm against cool shade instead of one hue washing over the whole scene.
uniform bool tone_split = false;
// The colour the shade takes (the place's own, Atmosphere.MODERN_TONE and the mood's "tone"), and how strongly.
uniform vec3 tone_shade : source_color = vec3(0.11, 0.18, 0.3);
uniform float tone_amount : hint_range(0.0, 1.0) = 0.55;
// How much colour the shade keeps (lit ground keeps all of its), how deep the blacks sink, and the brightness where
// shade turns into light.
uniform float tone_shade_saturation : hint_range(0.0, 1.5) = 0.6;
uniform float tone_black : hint_range(0.0, 0.2) = 0.03;
uniform float tone_pivot : hint_range(0.05, 1.0) = 0.42;
// Barovia's sky (Improvement Ideas W13, the Modern finish; Atmosphere sets it by the time of day): seen where the view
// looks out over the land past everything (the camera tilted toward the horizon, lane 8's CameraRig.horizon). A
// gradient from the land's haze at the horizon up to the sky colour, a low ceiling of cloud drifting with the wind,
// lit from beneath towards the moon or the low sun, and the moon glowing through where the cloud is thin. Never clear.
uniform bool sky_on = false;
uniform vec3 sky_zenith : source_color = vec3(0.1, 0.12, 0.2);
uniform vec3 sky_cloud_lit : source_color = vec3(0.5, 0.48, 0.55);
uniform vec3 sky_cloud_shade : source_color = vec3(0.15, 0.14, 0.2);
// Towards the moon or the sun (world space), its colour, and how strongly it shows (0 by day: only a brighter patch).
uniform vec3 sky_moon_dir = vec3(0.3, 0.6, -0.7);
uniform vec3 sky_moon_colour : source_color = vec3(0.85, 0.9, 0.95);
uniform float sky_moon = 1.0;
uniform float sky_cover : hint_range(0.0, 1.0) = 0.7;
uniform vec2 sky_wind = vec2(0.6, 0.25);
// The screen's edges sink towards this colour.
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform vec3 vignette_color : source_color = vec3(0.051, 0.039, 0.071);

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 view = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -view.z / view.w;
}

vec3 normal_at(vec2 uv) {
	return texture(normal_tex, uv).xyz * 2.0 - 1.0;
}

vec3 to_srgb(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(12.92 * c, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// Weighted RGB distance ("redmean") — cheap and closer to perception than plain RGB.
float colour_distance(vec3 a, vec3 b) {
	float r = (a.r + b.r) * 0.5;
	vec3 d = a - b;
	return (2.0 + r) * d.r * d.r + 4.0 * d.g * d.g + (3.0 - r) * d.b * d.b;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// The Modern finish's noise (Improvement Ideas W17): the same smooth value noise read from a tile of random values
// (Look.noise_texture) in one filtered fetch instead of four hashes, which made the mist, cloud shadows and ground
// patches a fifth of the frame. Classic keeps the hashes (frozen).
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform bool fast_noise = false;
const float NOISE_SIZE = 256.0;

// Smooth value noise in 0..1.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	if (fast_noise) {
		// Bilinear filtering between the lattice values at the smoothstepped position is the same smooth interpolation.
		return texture(noise_tex, (i + u + 0.5) / NOISE_SIZE).r;
	}
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = vnoise(p) * 0.55;
	v += vnoise(p * 2.03 + 17.1) * 0.3;
	v += vnoise(p * 4.11 + 41.7) * 0.15;
	return v;
}

// How deep into the Mists' wall a point is (0 outside), its edge billowing.
float wall_amount(vec3 p) {
	if (mist_wall.w <= 0.0) {
		return 0.0;
	}
	float wobble = (fbm(vec2(dot(p.xz, vec2(-mist_wall.y, mist_wall.x)) * 0.12, atmo_time * 0.03)) - 0.5) * 7.0;
	return smoothstep(0.0, mist_wall.w, dot(p.xz, mist_wall.xy) - mist_wall.z + wobble);
}

// How much mist a point holds (0..1+): thick near the ground, patchy by the noise, most where the map's mist mask
// says (by the trees, in the hollows), solid past the Mists' wall.
// The ground's height under a point (0 on a level map; ground_height where it isn't, settling to 0 past the edge).
float ground_at(vec2 xz) {
	if (!use_ground_height || land_rect.z <= land_rect.x) {
		return 0.0;
	}
	float g = texture(ground_height, (xz - land_rect.xy) / (land_rect.zw - land_rect.xy)).r;
	vec2 out2 = max(land_rect.xy - xz, xz - land_rect.zw);
	return g * (1.0 - smoothstep(0.0, 8.0, max(max(out2.x, out2.y), 0.0)));
}

float mist_density(vec3 p) {
	float above = (p.y - ground_at(p.xz) - mist_floor) / max(mist_height - mist_floor, 0.01);
	float wall = wall_amount(p);
	float top = mix(1.0, mist_wall_height / max(mist_height, 0.01), wall);
	float h = clamp(1.0 - above / top, 0.0, 1.0);
	float weight = 1.0;
	if (use_mist_mask && land_rect.z > land_rect.x) {
		weight = texture(mist_mask, (p.xz - land_rect.xy) / (land_rect.zw - land_rect.xy)).r;
	}
	// Streaks drawn out along the wind, drifting with it.
	vec2 wd = normalize(mist_wind + vec2(1e-4, 0.0));
	vec2 q = vec2(dot(p.xz, wd) * mist_stretch, dot(p.xz, vec2(-wd.y, wd.x)));
	float n = fbm((q + vec2(length(mist_wind) * atmo_time * mist_stretch, 0.0)) * mist_scale);
	float cover = mist_cover * mix(0.45, 1.25, weight);
	float patch = smoothstep(1.0 - cover - 0.22, 1.0 - cover + 0.22, n) * mix(0.55, 1.0, weight);
	// Thin strands along the ridges of a finer noise: the wisps that make it read as mist rather than shade.
	float r = 1.0 - abs(fbm((q * 2.3 + vec2(length(mist_wind) * atmo_time * mist_stretch * 1.7, 5.0)) * mist_scale) * 2.0 - 1.0);
	float wisp = pow(r, 6.0) * smoothstep(0.15, 0.6, weight + patch);
	return h * h * max(patch * 0.75 + wisp * mist_wisps, wall * 1.6);
}

// The sky along a view direction (sRGB, before the grade): see sky_on.
vec3 sky_colour(vec3 d) {
	float up = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(to_srgb(land_color), to_srgb(sky_zenith), pow(smoothstep(0.0, 0.6, up), 0.7));
	vec3 md = normalize(sky_moon_dir);
	float c = dot(d, md);
	float disc = smoothstep(0.9993, 0.9997, c) * sky_moon;
	float halo = pow(max(c, 0.0), 40.0) * 0.35 * mix(0.4, 1.0, sky_moon);
	col += to_srgb(sky_moon_colour) * halo;
	// The cloud ceiling: the ray's point on a flat layer overhead, so the cloud shrinks into the distance.
	vec2 p = d.xz / (d.y + 0.12) * 0.9 + sky_wind * atmo_time * 0.02;
	float n = fbm(p) * 0.75 + fbm(p * 2.7 + 13.1) * 0.25;
	float density = smoothstep(1.0 - sky_cover - 0.15, 1.0 - sky_cover + 0.3, n);
	float towards = clamp(dot(normalize(d.xz + 1e-4), normalize(md.xz + 1e-4)) * 0.5 + 0.5, 0.0, 1.0);
	float lit = smoothstep(0.35, 0.8, n) * 0.5 + towards * 0.5 * halo * 4.0;
	vec3 cloud = mix(to_srgb(sky_cloud_shade), to_srgb(sky_cloud_lit), clamp(lit, 0.0, 1.0));
	// The moon shows through thin cloud; thick cloud hides it.
	col = mix(col + to_srgb(sky_moon_colour) * disc * (1.0 - density * 0.85), cloud, density * smoothstep(0.0, 0.15, d.y));
	return col;
}

void fragment() {
	vec2 vp = VIEWPORT_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / pixel_size);
	vec2 uv = (cell + 0.5) * pixel_size / vp;
	vec3 lin_in = texture(screen_tex, uv).rgb;
	vec3 col = to_srgb(lin_in);
	vec3 excess = max(lin_in - vec3(1.0), vec3(0.0));
	float raw_depth = texture(depth_tex, uv).r;
	bool empty = raw_depth <= 0.0;

	if (outlines) {
		vec2 o = outline_width * pixel_size / vp;
		float d0 = linear_depth(uv, INV_PROJECTION_MATRIX);
		vec3 n0 = normal_at(uv);
		vec2 offs[4] = vec2[](vec2(o.x, 0.0), vec2(-o.x, 0.0), vec2(0.0, o.y), vec2(0.0, -o.y));
		float edge = 0.0;
		for (int i = 0; i < 4; i++) {
			float d = linear_depth(uv + offs[i], INV_PROJECTION_MATRIX);
			// Only the nearer side draws the line, so outlines hug silhouettes instead of doubling.
			if ((d - d0) / max(d0, 0.001) > depth_threshold) {
				edge = 1.0;
			}
			if (outline_creases && dot(n0, normal_at(uv + offs[i])) < normal_threshold && d0 < 60.0) {
				edge = max(edge, 0.85);
			}
		}
		col = mix(col, to_srgb(outline_color), edge * outline_strength);
	}

	// The world point behind this pixel, and the camera.
	vec4 vpos = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, max(raw_depth, 1e-6), 1.0);
	vpos.xyz /= vpos.w;
	vec3 wpos = (INV_VIEW_MATRIX * vec4(vpos.xyz, 1.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 sky_dir = vec3(0.0, -1.0, 0.0);
	if (empty) {
		// Past everything: carry the ray down to the ground so the mist still lies there.
		vec3 dir = normalize(wpos - cam);
		sky_dir = dir;
		wpos = cam + dir * ((mist_floor - cam.y) / min(dir.y, -0.05));
	}
	// How much of this pixel is open sky (0 below the horizon and for anything drawn).
	float sky_amount = (sky_on && empty) ? smoothstep(-0.02, 0.1, sky_dir.y) : 0.0;

	// Water marks itself with zero roughness: it keeps its own colours through the grade and the ground patches.
	float own_colour = empty ? 0.0 : 1.0 - step(0.08, texture(normal_tex, uv).a);

	// Light on the surfaces first (patches of light and shade, cloud shadows, the grade), then what hangs in the air
	// in its own palette colours (the land fading into the sky, the mist), then the vignette.
	if (ground_variation > 0.0 && !empty && own_colour < 0.5) {
		// Broad light and dark patches over the ground so its texture doesn't read as tiles.
		vec3 wn = (INV_VIEW_MATRIX * vec4(normal_at(uv), 0.0)).xyz;
		if (wn.y > 0.8) {
			vec2 gp = wpos.xz * 0.07 + 31.0;
			float g = fbm(gp + vec2(fbm(gp * 2.3 + 1.7), fbm(gp * 2.3 + 6.2)) * 1.4);
			float step_g = soft_bands ? (g - 0.5) * 0.9 : floor(g * 4.0) / 3.0 - 0.5;
			col *= 1.0 + step_g * ground_variation;
		}
	}

	if (cloud_strength > 0.0 && !empty) {
		// Domain-warped, so the shadows have ragged cloud edges rather than round blots.
		vec2 cp = wpos.xz * cloud_scale + cloud_wind * atmo_time * cloud_scale;
		float c = fbm(cp + vec2(fbm(cp * 2.0 + 3.3), fbm(cp * 2.0 + 9.1)) * 1.2);
		float shade = soft_bands ? smoothstep(1.0 - cloud_cover - 0.05, 1.0 - cloud_cover + 0.14, c)
			: step(1.0 - cloud_cover, c) * 0.6 + step(1.0 - cloud_cover + 0.08, c) * 0.4;
		col *= 1.0 - cloud_strength * shade;
	}

	col *= exposure;
	col = (col - 0.5) * contrast + 0.5;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	if (tone_split) {
		col = max(col - tone_black, vec3(0.0)) / (1.0 - tone_black);
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		float lit = smoothstep(tone_pivot * 0.3, tone_pivot * 1.6, lum);
		float chroma = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
		// Warm light (a lantern's pool, a fire, a lit window) keeps its own colour, as does anything strongly
		// coloured and water: only the cool shade takes the place's shadow colour.
		float warm = smoothstep(0.015, 0.09, col.r - col.b);
		float keep = max(max(smoothstep(0.12, 0.35, chroma), warm), own_colour * 0.8);
		vec3 sh = to_srgb(tone_shade);
		vec3 tint = sh / max(dot(sh, vec3(0.299, 0.587, 0.114)), 0.05);
		col = mix(col, col * tint, clamp(tone_amount * (1.0 - lit) * (1.0 - keep * 0.75), 0.0, 1.0));
		float l2 = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(l2), col, mix(tone_shade_saturation, 1.0, max(lit, keep)));
	} else if (grade_amount > 0.0) {
		// A gradient map: brightness runs from the vignette's near-black through the place's shadow colour to its
		// light colour, so a scene keeps to one family of hues. Strongly coloured light (a lantern, a fire) keeps
		// more of its own colour.
		vec3 sh = to_srgb(grade_shadows);
		vec3 li = to_srgb(grade_lights);
		vec3 duo = l < 0.3 ? mix(to_srgb(vignette_color), sh, l / 0.3) : (l < 0.75 ? mix(sh, li, (l - 0.3) / 0.45) : mix(li, vec3(0.96, 0.93, 0.84), (l - 0.75) / 0.25));
		float chroma = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
		col = mix(col, duo, grade_amount * (1.0 - smoothstep(0.2, 0.45, chroma) * 0.6) * (1.0 - own_colour * 0.8));
	}

	if (land_rect.z > land_rect.x) {
		// How far outside the map this point lies (0 on it), wavy so the edge of what can be seen isn't a ruler line.
		vec2 o = max(max(land_rect.xy - wpos.xz, wpos.xz - land_rect.zw), vec2(0.0));
		float out_d = length(o) + (vnoise(wpos.xz * 0.21) - 0.5) * 3.0;
		float f = empty ? 1.0 : smoothstep(land_fade.x, land_fade.x + land_fade.y, out_d);
		col = mix(col, to_srgb(land_color), soft_bands ? f : floor(f * 4.0 + 0.5) / 4.0);
	}

	if (sky_amount > 0.0) {
		col = mix(col, sky_colour(sky_dir), sky_amount);
	}

	if (mist_strength > 0.0 && (!empty || mist_beyond) && sky_amount < 1.0) {
		// March the part of the view ray inside the mist layer (from where it comes down through the top to the
		// surface), so the mist floats over the ground and shifts with the camera like a real layer.
		vec3 dir = wpos - cam;
		// The layer's top over the ground there (raised ground carries its mist up with it).
		float ground = ground_at(wpos.xz);
		float top = mist_height + ground;
		if (mist_wall.w > 0.0) {
			top = max(top, mist_wall_height + ground);
		}
		float t0 = clamp((top - cam.y) / min(dir.y, -1e-4), 0.0, 1.0);
		vec3 a = cam + dir * t0;
		float len = length(wpos - a);
		float tau = 0.0;
		vec3 glow = vec3(0.0);
		const int STEPS = 4;
		for (int i = 0; i < STEPS; i++) {
			vec3 p = mix(a, wpos, (float(i) + 0.5) / float(STEPS));
			float dn = mist_density(p);
			tau += dn;
			for (int j = 0; j < glow_count; j++) {
				float r = length(p - glow_pos[j].xyz) / max(glow_pos[j].w, 0.01);
				float k = clamp(1.0 - r, 0.0, 1.0);
				glow += glow_col[j].rgb * glow_col[j].a * k * k * dn;
			}
		}
		tau *= len / float(STEPS);
		float m = 1.0 - exp(-tau * mist_thickness);
		// Flat bands, like the rest of the cel look.
		if (!soft_bands) {
			m = floor(m * mist_bands + 0.35) / mist_bands;
		}
		// The Mists themselves are a flat pale wall nothing is seen through, inked along its billowing edge like the
		// cartoon clouds it stands for.
		float wa = wall_amount(wpos);
		float in_wall = step(0.5, wa);
		m = max(m, in_wall);
		vec3 mc = mix(to_srgb(mist_color) + glow / float(STEPS), to_srgb(mist_wall_color), in_wall);
		// Over water the mist thins so the lake keeps its face.
		// Under an open sky, the mist past everything thins out toward the horizon instead of painting the gaps
		// between the far trees.
		float out_there = (sky_on && empty) ? smoothstep(-0.005, -0.08, sky_dir.y) : 1.0;
		float strength = mix(mist_strength * (1.0 - own_colour * 0.55), 1.0, in_wall) * (1.0 - sky_amount) * out_there;
		col = mix(col, mc, clamp(m * strength, 0.0, 1.0));
		if (mist_wall.w > 0.0) {
			float fw = max(fwidth(wa), 1e-4);
			col = mix(col, to_srgb(outline_color), 1.0 - smoothstep(fw * 0.8, fw * 1.8, abs(wa - 0.5)));
		}
	}

	if (vignette > 0.0) {
		vec2 q = (uv - 0.5) * vec2(vp.x / vp.y, 1.0);
		float v = smoothstep(0.45, 1.05, length(q) * 1.15);
		col = mix(col, to_srgb(vignette_color), v * vignette * (1.0 - sky_amount * 0.7));
	}

	if (quantize) {
		int bi = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
		col += (BAYER[bi] / 16.0 - 0.5) * dither_strength;
		float best = 1e9;
		vec3 pick = col;
		// Greys stay on the grey ramp (as the sprite pipeline keeps them): a near-neutral colour between two greys
		// would otherwise snap to a brown, which reads as a muddy ring where a grey fades.
		float chroma = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
		float grey_bias = keep_greys ? 1.0 - smoothstep(0.03, 0.09, chroma) : 0.0;
		for (int i = 0; i < palette_size; i++) {
			vec3 p = texelFetch(palette_tex, ivec2(i, 0), 0).rgb;
			float dist = colour_distance(col, p);
			float pc = max(p.r, max(p.g, p.b)) - min(p.r, min(p.g, p.b));
			dist += grey_bias * max(pc - 0.07, 0.0) * 0.5;
			if (dist < best) {
				best = dist;
				pick = p;
			}
		}
		col = pick;
	}
	ALBEDO = to_linear(col) + (keep_hdr ? excess * 0.85 : vec3(0.0));
}
