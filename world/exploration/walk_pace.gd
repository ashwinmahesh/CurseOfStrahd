class_name WalkPace
extends RefCounted
## The one setting for how fast everyone walks while exploring (owner 2026-10-18: characters and NPCs 25% faster).
## Every walking speed outside a fight is its old value scaled by this: the party's and its followers' squares
## (LocationView.STEP_TIME, SNEAK_STEP_TIME), townsfolk on their rounds (NpcRoutes), a lead's walk (LocationLead), the
## gray-box room's party and villager. Walk cycles and footsteps follow, as both are paced to the step time
## (DirectionalSprite.set_step_time). A fight's squares (CombatView.STEP_TIME) keep their own pace and the Settings
## combat speed; time spent standing (a route's `pause`) is left alone.
const FASTER := 1.25
