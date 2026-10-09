shader_type spatial;
// The big d20's emerald (ui/dice/d20_die.gd, docs/ui/d20_roll.md): a cut gem that seems lit from inside. Each facet
// bends the view into the stone a different way and shows a darker or lighter patch of green, so the facets flicker
// between the gem's depths and its bright heart as the die turns (three back facets behind each face, D20Mesh); faces
// turned to the viewer let more light through, clearest in their middles; the rims sink to the stone's deep green. Two studio lights flash on whichever facets
// mirror them, and the ground-off edges catch a pale glint. `sweep` runs a band of light across the die when it lands,
// `flash` lights it all at once, and `dim` greys out the die not kept. Colours come from the UI palette (D20Die).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec3 deep : source_color = vec3(0.012, 0.145, 0.102);
uniform vec3 body : source_color = vec3(0.043, 0.416, 0.259);
uniform vec3 bright : source_color = vec3(0.122, 0.659, 0.416);
uniform vec3 light : source_color = vec3(0.384, 0.89, 0.651);
uniform vec3 glint : source_color = vec3(0.824, 0.984, 0.902);
uniform vec3 flash_color : source_color = vec3(0.824, 0.984, 0.902);
uniform float flash : hint_range(0.0, 2.0) = 0.0;
uniform float sweep = -9.0;
uniform float dim : hint_range(0.0, 1.0) = 0.0;

// The back facet seen through this part of the face (D20Mesh), in view space.
varying vec3 back_n;

void vertex() {
	back_n = (MODELVIEW_MATRIX * vec4(CUSTOM0.xyz, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float facing = clamp(dot(n, v), 0.0, 1.0);
	float edge = COLOR.g;
	float rim_d = UV.x * (1.0 - edge);
	// Into the stone: a patch of its depths or of its heart, by where the view bends to.
	vec3 r = refract(-v, normalize(back_n), 0.64);
	float inner = 0.5 + 0.5 * sin(r.x * 6.5 + 1.3 + COLOR.r * 0.8) * sin(r.y * 6.0 + 0.5);
	vec3 col = mix(deep * 0.35, body, smoothstep(0.12, 0.72, inner));
	col = mix(col, bright, smoothstep(0.62, 0.98, inner) * 0.85);
	col *= mix(0.35, 1.1, facing) * mix(1.2, 0.72, rim_d);
	col = mix(col, light, pow(max(inner, 0.0), 10.0) * facing * 0.2);
	// The studio lights mirrored in the facets: a broad softbox up to the left, a small hard lamp up to the right.
	vec3 refl = reflect(-v, n);
	float box = smoothstep(0.86, 0.975, dot(refl, normalize(vec3(-0.5, 0.62, 0.6))));
	float lamp = smoothstep(0.955, 0.99, dot(refl, normalize(vec3(0.55, 0.55, 0.63))));
	vec3 lit = col + glint * box * mix(0.55, 1.0, edge) + glint * lamp * 0.9 + glint * edge * 0.08;
	// The landing's band of light, crossing the die on screen from lower left to upper right.
	vec3 centre = (VIEW_MATRIX * vec4(NODE_POSITION_WORLD, 1.0)).xyz;
	float along = dot((VERTEX - centre).xy, normalize(vec2(1.0, 1.0)));
	float band = exp(-pow((along - sweep) * 3.2, 2.0));
	lit += glint * band * (0.5 + 0.5 * facing);
	lit += flash_color * flash * (0.35 + 0.65 * facing);
	float grey = dot(lit, vec3(0.299, 0.587, 0.114));
	lit = mix(lit, vec3(grey) * 0.55, dim * 0.8);
	ALBEDO = col * 0.12 * (1.0 - dim * 0.6);
	EMISSION = lit;
	ROUGHNESS = mix(0.08, 0.05, edge);
	SPECULAR = 0.9;
	METALLIC = 0.0;
}
