// The light the colossi at the Amber Temple's doors give off (Amber Temple Look Plan step 8, AmberColossus): the seam of
// amber round the Sentinel's dais (and the cracks that run across it), the soft halo of its eyes, and the warm wedge of
// light that spills from the doors' seams onto the snow. Each is one quad added over the scene, never lit; one material
// per piece, because the strength and the breath are set on each from code.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

// 0 the dais seam (a flat square), 1 the eyes' halo (faces the camera), 2 the doors' wedge (a flat trapezoid whose UV runs
// across in x and away from the doors in y).
uniform int kind = 0;
uniform vec3 colour : source_color = vec3(1.0, 0.7, 0.25);
uniform float strength : hint_range(0.0, 4.0) = 1.0;
// How far the cracks across the dais have run (0 none, 1 right to the edge), and which way they fall.
uniform float crack : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
// The slow breath of the amber: how deep it goes and how fast it turns.
uniform float breath = 0.25;
uniform float pace = 0.9;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (kind == 1) {
		// The halo always faces the camera, wherever it looks from.
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
}

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void fragment() {
	vec2 p = UV - 0.5;
	float t = TIME;
	float swell = 1.0 - breath + breath * (0.5 + 0.5 * sin(t * pace + seed * 6.28));
	float a = 0.0;
	if (kind == 0) {
		// A seam of amber just inside the dais's edge, its haze spilling out onto the stone, and, as it wakes or breaks,
		// cracks running from the middle toward the edge.
		float d = 0.5 - max(abs(p.x), abs(p.y));
		float line = smoothstep(0.014, 0.0, abs(d - 0.03));
		float haze = smoothstep(0.09, 0.0, abs(d - 0.02)) * 0.35;
		a = (line + haze) * swell;
		if (crack > 0.0) {
			float r = length(p) * 2.0;
			float ang = atan(p.y, p.x);
			float rays = 0.0;
			for (int k = 0; k < 7; k++) {
				float fk = float(k);
				float want = fk * 0.8976 + hash11(fk + seed * 13.0) * 0.5;
				float diff = ang - want;
				diff = atan(sin(diff), cos(diff));
				float wobble = 0.1 * sin(r * 13.0 + fk * 2.7) + 0.06 * sin(r * 29.0 + fk);
				float reach = crack * (0.75 + 0.5 * hash11(fk + 5.0));
				float width = 0.035 * (1.0 - 0.5 * r);
				rays += smoothstep(width, 0.0, abs(diff + wobble) * r) * step(r, reach) * smoothstep(0.0, 0.12, r);
			}
			// A ring round the middle where it first gives, so it reads as a break and not a drawing.
			float ring = smoothstep(0.03, 0.0, abs(r - 0.3 * crack)) * crack;
			a += (rays + ring * 0.6) * 1.1;
		}
	} else if (kind == 1) {
		// A soft glow, brighter at its heart, that the eyes sit in.
		float r = length(p) * 2.0;
		a = pow(smoothstep(1.0, 0.0, r), 2.2) * swell;
	} else {
		// A wedge: bright at the doors' seams and fading out over the snow, with a narrower, hotter ray down the middle
		// where the two leaves meet and a little drift along the edges.
		float across = 1.0 - abs(UV.x - 0.5) * 2.0;
		float along = 1.0 - UV.y;
		float body = pow(clamp(along, 0.0, 1.0), 1.5) * smoothstep(0.0, 0.7, across);
		float ray = pow(clamp(along, 0.0, 1.0), 2.2) * smoothstep(0.22, 0.0, abs(UV.x - 0.5));
		float drift = 0.85 + 0.15 * sin(t * 0.7 + UV.y * 5.0 + UV.x * 3.0 + seed * 6.28);
		a = (body * 0.7 + ray * 0.9) * drift * swell;
	}
	ALBEDO = colour * a * strength;
}
