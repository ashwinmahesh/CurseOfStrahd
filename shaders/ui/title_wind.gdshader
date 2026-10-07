shader_type canvas_item;
// Wind in the title screen's pines (ui/menu/title_ambience.gd): inside the forest rectangles of the key art, the dark
// tree silhouettes are nudged sideways by a slow sway that varies along x, stronger in gusts. Only dark pixels move
// (the trees and their ink), so the mist and sky around them stay put. No noise, no grain.

uniform float gust = 0.5;
// Up to six forest areas, each as (min uv, max uv).
uniform vec4 forests[6];
uniform int forest_count = 0;
// The largest sideways nudge, in UV (about two pixels of the art).
uniform float amp = 0.0014;

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec4 orig = texture(TEXTURE, UV);
	float w = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= forest_count) {
			break;
		}
		vec4 r = forests[i];
		vec2 q = (UV - r.xy) / (r.zw - r.xy);
		vec2 edge = min(q, 1.0 - q);
		w = max(w, smoothstep(0.0, 0.08, min(edge.x, edge.y)));
	}
	if (w <= 0.0) {
		COLOR = orig;
	} else {
		float sway = sin(TIME * 1.6 + UV.x * 85.0) * 0.6 + sin(TIME * 2.7 + UV.x * 33.0 + UV.y * 20.0) * 0.4;
		float dx = amp * w * (0.35 + gust) * sway;
		vec4 moved = texture(TEXTURE, UV + vec2(dx, 0.0));
		float dark = max(1.0 - smoothstep(0.09, 0.2, lum(moved.rgb)), 1.0 - smoothstep(0.09, 0.2, lum(orig.rgb)));
		COLOR = mix(orig, moved, dark);
	}
}
