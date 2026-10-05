// Final look pass (plan §4.1): cartoon outlines from depth and normal edges, then every pixel snapped
// to the Strahd palette with optional ordered dithering. Drawn on a full-screen quad (see
// world/look/post_process.gd). UI lives on CanvasLayers, which draw after this, so it is exempt.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
// N x 1 strip from art/palette/strahd_palette.png, read raw (sRGB values).
uniform sampler2D palette_tex : filter_nearest;
uniform int palette_size = 46;
uniform bool quantize = true;
uniform float dither_strength : hint_range(0.0, 0.2) = 0.045;
// Pixel size of the art grid. 1 = native; 2 makes chunkier pixels.
uniform float pixel_size : hint_range(1.0, 6.0) = 2.0;
uniform bool outlines = true;
uniform float outline_width : hint_range(0.5, 4.0) = 1.5;
uniform float depth_threshold = 0.06;
uniform float normal_threshold = 0.55;
uniform vec3 outline_color : source_color = vec3(0.051, 0.039, 0.071);

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

void fragment() {
	vec2 vp = VIEWPORT_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / pixel_size);
	vec2 uv = (cell + 0.5) * pixel_size / vp;
	vec3 col = to_srgb(texture(screen_tex, uv).rgb);

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
			if (dot(n0, normal_at(uv + offs[i])) < normal_threshold && d0 < 60.0) {
				edge = max(edge, 0.85);
			}
		}
		col = mix(col, to_srgb(outline_color), edge);
	}

	if (quantize) {
		int bi = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
		col += (BAYER[bi] / 16.0 - 0.5) * dither_strength;
		float best = 1e9;
		vec3 pick = col;
		for (int i = 0; i < palette_size; i++) {
			vec3 p = texelFetch(palette_tex, ivec2(i, 0), 0).rgb;
			float dist = colour_distance(col, p);
			if (dist < best) {
				best = dist;
				pick = p;
			}
		}
		col = pick;
	}
	ALBEDO = to_linear(col);
}
