// How the Modern finish's world takes each light (Improvement Ideas W3), shared by lit.gdshader and lit_world.gdshader.
//
// Diffuse: Lambert lifted towards the light (lit^0.75), the painted look: the outer part of a lamp's pool and a face
// turning away from the moon stay a little brighter than physics would have them, so pools of light read wide and
// warm, but nothing flattens into one band as Classic's cel ramp does, and relief shows wherever light falls.
// Specular: GGX with Schlick's Fresnel and height-correlated Smith visibility (as Godot's own), so a lamp leaves a
// highlight that is small and bright on polished stone and broad and faint on rough plaster, and glints off the worn
// tops of cobbles where the texture says the surface is smoother.
//
// Lamps light a third more than their energy says, as Classic's cel ramp lifted them: their pools of light read warm
// and wide against the shade. The sun and moon leave half the highlight a lamp would: a broad sky light glancing off a
// whole street reads as a grey haze over it, while a lamp's glints on the stones near it make a street look wet.
//
// Godot multiplies DIFFUSE_LIGHT by the albedo afterwards; LIGHT_COLOR already holds the light's energy times PI.
uniform float specular : hint_range(0.0, 1.0) = 0.5;

const float LIT_LIFT = 0.75;
const float LAMP_GAIN = 1.35;
const float SKY_SPECULAR = 0.5;

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float lit = ndl * ATTENUATION;
	DIFFUSE_LIGHT += pow(lit, LIT_LIFT) * LIGHT_COLOR / PI * (LIGHT_IS_DIRECTIONAL ? 1.0 : LAMP_GAIN);
	// Specular only on the lit side (a light can't glint off a face turned away from it).
	vec3 h = normalize(VIEW + LIGHT);
	float ndh = clamp(dot(NORMAL, h), 0.0, 1.0);
	float ndv = clamp(dot(NORMAL, VIEW), 1e-4, 1.0);
	float ldh = clamp(dot(LIGHT, h), 0.0, 1.0);
	float a = max(ROUGHNESS * ROUGHNESS, 0.002);
	float a2 = a * a;
	float dd = ndh * ndh * (a2 - 1.0) + 1.0;
	float d = a2 / (PI * dd * dd);
	float vis = 0.5 / (ndl * sqrt(ndv * ndv * (1.0 - a2) + a2) + ndv * sqrt(ndl * ndl * (1.0 - a2) + a2));
	vec3 f0 = mix(vec3(0.16 * specular * specular), ALBEDO, METALLIC);
	vec3 f = f0 + (1.0 - f0) * pow(1.0 - ldh, 5.0);
	float sky = LIGHT_IS_DIRECTIONAL ? SKY_SPECULAR : 1.0;
	SPECULAR_LIGHT += ndl * d * vis * f * LIGHT_COLOR * ATTENUATION * SPECULAR_AMOUNT * sky * step(1e-4, ndl);
}
