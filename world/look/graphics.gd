class_name Graphics
extends RefCounted
## How much work the renderer does for the Modern finish (Improvement Ideas W2, W17): anti-aliasing, the resolution
## the 3D world is drawn at, how sharp and soft the shadows are and how many lamps cast them, reflections, contact
## shadows and bounced light, the haze that catches light and the depth of field, by a preset the player picks (Low,
## Medium or High; GameSettings "graphics"; Settings shows LABELS). The bar is 60 frames a second at 1080p on the
## owner's Mac Mini (Apple M6) on High (docs/art/atmosphere.md "Graphics presets"). The Classic finish keeps the
## renderer as it was when the owner froze it (2026-10-07), whatever the preset.
##
## Edges: MSAA smooths the edges of 3D shapes, and SMAA after it smooths the ink lines the screen pass draws round
## them (MSAA can't reach those: they're drawn per pixel after the scene). SMAA only blends along stair-stepped edges,
## so the character sprites, already smooth from their own shader, keep their detail; TAA would blur them, and so
## would any temporal upscaling, so Low draws the world smaller and upscales it spatially: Apple's MetalFX on the
## Mac's Metal renderer, FSR 1 elsewhere.

const PRESETS: Array[String] = ["low", "medium", "high"]
const DEFAULT_PRESET := "high"
const LABELS := {"low": "Low", "medium": "Medium", "high": "High"}

## Per preset:
## - msaa: samples on 3D edges (2x on High: 4x cost 1.4 to 2.9 ms more at 1080p for little SMAA doesn't already do);
##   edge_aa: the screen-space pass over the finished picture (SMAA or the cheaper FXAA).
## - scale: the share of the window's resolution the 3D world is drawn at (below 1 upscaled spatially).
## - sun_map: the sun and moon's shadow map (pixels a side), shared by its splits; sun_splits: 2 or 4 bands from near
##   to far, each with its own share of the map, so shadows near the party are sharp (2 on every preset: fitted to
##   what the camera sees, two are sharp enough, and each split draws the scene's shadow casters again, about 4.7 ms
##   at 1080p in the village and on the road); sun_soft: the shadows soften with distance from what casts them
##   (Atmosphere.SUN_SIZE).
## - lamp_atlas: the shadow atlas every other light draws into (pixels a side); lamp_shadows: how many lights
##   nearest the party cast shadows (Atmosphere picks them); lamp_soft: their shadows soften with distance by the
##   light's size (Atmosphere.LIGHT_KINDS), else they're evenly soft.
## - filter: soft shadow filtering for both (RenderingServer.ShadowQuality).
## - reflections: steps of the screen-space reflections on polished and wet surfaces (0 = none).
## - swaying: how many of the shadow-casting flames nearest the party sway as they flicker, stirring their shadows
##   (each redraws its shadow map every frame).
## - ao: contact shadows' quality and whether they're worked out at half resolution; bounce: light bounced off walls
##   (SSIL), off (-1) or its quality.
## - haze: the volumetric haze's grid (cells across and deep; 0 = no haze: the window shafts' cones still show).
## - dof: the depth of field's blur quality (RenderingServer.DOFBlurQuality).
## - sprite_shadows: the characters cast shadows from the lights (W6, the animations thread reads it).
const SPECS := {
	"low": {"msaa": Viewport.MSAA_DISABLED, "edge_aa": Viewport.SCREEN_SPACE_AA_FXAA, "scale": 0.75,
		"sun_map": 2048, "sun_splits": 2, "sun_soft": false, "lamp_atlas": 2048, "lamp_shadows": 2,
		"lamp_soft": false, "filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "reflections": 0, "swaying": 0,
		"ao": RenderingServer.ENV_SSAO_QUALITY_LOW, "ao_half": true, "bounce": -1, "haze": 0,
		"dof": RenderingServer.DOF_BLUR_QUALITY_VERY_LOW, "sprite_shadows": false},
	"medium": {"msaa": Viewport.MSAA_DISABLED, "edge_aa": Viewport.SCREEN_SPACE_AA_SMAA, "scale": 1.0,
		"sun_map": 4096, "sun_splits": 2, "sun_soft": true, "lamp_atlas": 4096, "lamp_shadows": 6,
		"lamp_soft": true, "filter": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, "reflections": 32, "swaying": 2,
		"ao": RenderingServer.ENV_SSAO_QUALITY_MEDIUM, "ao_half": true, "bounce": -1, "haze": 48,
		"dof": RenderingServer.DOF_BLUR_QUALITY_LOW, "sprite_shadows": true},
	"high": {"msaa": Viewport.MSAA_2X, "edge_aa": Viewport.SCREEN_SPACE_AA_SMAA, "scale": 1.0,
		"sun_map": 4096, "sun_splits": 2, "sun_soft": true, "lamp_atlas": 8192, "lamp_shadows": 8,
		"lamp_soft": true, "filter": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "reflections": 56, "swaying": 2,
		"ao": RenderingServer.ENV_SSAO_QUALITY_HIGH, "ao_half": true,
		"bounce": RenderingServer.ENV_SSIL_QUALITY_MEDIUM, "haze": 64, "dof": RenderingServer.DOF_BLUR_QUALITY_MEDIUM,
		"sprite_shadows": true},
}
## The renderer as Classic was frozen with: no anti-aliasing, full resolution, the sun's 4096 map in two splits, no
## lamp shadows, Godot's default filtering, contact shadows and depth of field, no reflections, bounce or haze.
## (project.godot holds High's settings for scenes that open without a place.)
const CLASSIC := {"msaa": Viewport.MSAA_DISABLED, "edge_aa": Viewport.SCREEN_SPACE_AA_DISABLED, "scale": 1.0,
	"sun_map": 4096, "sun_splits": 2, "sun_soft": false, "lamp_atlas": 4096, "lamp_shadows": 0, "lamp_soft": false,
	"filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "reflections": 0, "swaying": 0,
	"ao": RenderingServer.ENV_SSAO_QUALITY_MEDIUM, "ao_half": true, "bounce": -1, "haze": 0,
	"dof": RenderingServer.DOF_BLUR_QUALITY_MEDIUM, "sprite_shadows": false}


static func preset() -> String:
	var p := str(GameSettings.value("graphics", DEFAULT_PRESET))
	return p if p in PRESETS else DEFAULT_PRESET


## `save` false changes it for this run only (captures). The window changes now, and so does the place on screen.
static func set_preset(p: String, save: bool = true) -> void:
	if not p in PRESETS:
		return
	GameSettings.set_value("graphics", p, save)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		apply(tree.root)
		tree.call_group(Atmosphere.GROUP, "apply_graphics")


## Single settings put over the preset's for a run (tools/capture/look_capture.gd's bench times each one).
static var overrides: Dictionary = {}


## The settings in force: the preset's in the Modern finish, Classic's own otherwise.
static func spec() -> Dictionary:
	if not Look.modern():
		return CLASSIC
	if overrides.is_empty():
		return SPECS[preset()] as Dictionary
	var s := (SPECS[preset()] as Dictionary).duplicate()
	s.merge(overrides, true)
	return s


## Sets the window's 3D rendering to the current preset (Atmosphere calls it as each place opens), and puts the
## frame-time meter (F3) on the window.
static func apply(vp: Viewport) -> void:
	var s := spec()
	vp.msaa_3d = s["msaa"] as Viewport.MSAA
	vp.screen_space_aa = s["edge_aa"] as Viewport.ScreenSpaceAA
	var scale := float(s["scale"])
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if scale < 1.0:
		var metal := RenderingServer.get_current_rendering_driver_name() == "metal"
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_SPATIAL if metal else Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = scale
	vp.positional_shadow_atlas_size = int(s["lamp_atlas"])
	vp.positional_shadow_atlas_16_bits = true
	RenderingServer.directional_shadow_atlas_set_size(int(s["sun_map"]), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(s["filter"] as RenderingServer.ShadowQuality)
	RenderingServer.positional_soft_shadow_filter_set_quality(s["filter"] as RenderingServer.ShadowQuality)
	RenderingServer.environment_set_ssao_quality(s["ao"] as RenderingServer.EnvironmentSSAOQuality, bool(s["ao_half"]),
		0.5, 2, 50.0, 300.0)
	if int(s["bounce"]) >= 0:
		RenderingServer.environment_set_ssil_quality(s["bounce"] as RenderingServer.EnvironmentSSILQuality, true, 0.5, 4,
			50.0, 300.0)
	if int(s["haze"]) > 0:
		RenderingServer.environment_set_volumetric_fog_volume_size(int(s["haze"]), int(s["haze"]))
	RenderingServer.camera_attributes_set_dof_blur_quality(s["dof"] as RenderingServer.DOFBlurQuality, true)
	if vp is Window and not vp.has_meta(FrameMeter.NODE_NAME):
		vp.set_meta(FrameMeter.NODE_NAME, true)   # once, though the meter only joins at the end of the frame
		vp.add_child.call_deferred(FrameMeter.new())


static func lamp_shadows() -> int:
	return int(spec()["lamp_shadows"])


static func sun_splits() -> int:
	return int(spec()["sun_splits"])


static func sun_soft() -> bool:
	return bool(spec()["sun_soft"])


static func lamp_soft() -> bool:
	return bool(spec()["lamp_soft"])


static func reflection_steps() -> int:
	return int(spec()["reflections"])


static func swaying_flames() -> int:
	return int(spec()["swaying"])


## Whether the characters cast shadows from the lights (W6).
static func sprite_shadows() -> bool:
	return bool(spec()["sprite_shadows"])


## Whether light bounces off walls (SSIL) in the Modern finish.
static func bounce() -> bool:
	return int(spec()["bounce"]) >= 0


## Whether the volumetric haze is on in the Modern finish.
static func haze() -> bool:
	return int(spec()["haze"]) > 0
