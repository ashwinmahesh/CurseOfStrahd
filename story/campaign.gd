class_name Campaign
extends RefCounted
## The campaign module the story engine asks (CampaignModule): the script named in data/campaign.json, loaded on first
## use, or the base module (a game with no campaign facts) when there is no file. Tests put their own in with use().

const CONFIG := "res://data/campaign.json"

static var _module: CampaignModule


static func module() -> CampaignModule:
	if _module == null:
		_module = _load()
	return _module


## Puts `m` in place of the configured module; null goes back to the configured one.
static func use(m: CampaignModule) -> void:
	_module = m


static func _load() -> CampaignModule:
	if FileAccess.file_exists(CONFIG):
		var cfg := JSON.parse_string(FileAccess.get_file_as_string(CONFIG)) as Dictionary
		var script := load(str(cfg.get("module", ""))) as GDScript
		if script != null:
			return script.new() as CampaignModule
	return CampaignModule.new()
