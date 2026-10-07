class_name SkirmishState
extends StoryState
## The story state the game's own party screens see while the Character Lab has them open (the level-up screen, the
## sheet, the inventory): one hero, and a level cap the Lab sets anywhere up to 20 instead of the campaign's
## milestones. Nothing in it is saved.

## The level the level-up screen may take the hero to.
var lab_target := 1


func target_level() -> int:
	return clampi(lab_target, 1, HeroLab.MAX_LEVEL)
