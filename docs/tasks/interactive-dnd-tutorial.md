# Interactive D&D tutorial — implementation plan

Written before application-code changes. Branch: `codex/interactive-dnd-tutorial`. Worktree: `/Users/ashwinmahesh/Documents/CurseOfStrahdGame-dnd-tutorial`.

## Goal and player experience

Teach a person who has never played Dungeons & Dragons enough to explore, understand outcomes, take turns, use spells and recover in this game. The tutorial is optional, practical and replayable. It reuses existing locations, characters, icons, panels, animations, effects and sounds. There is no new generated art or voice production.

After choosing a party and difficulty for New Game, the player sees a short invitation with “Learn the basics”, “Start campaign” and “Back”. The tutorial uses a small prepared practice party. Completing or leaving it returns to the pending campaign start without losing the chosen party, custom character, bench or difficulty. A “Learn to play” title-screen entry launches the same practice without starting a campaign afterward.

Each lesson has a short explanation, one clear action, a highlighted relevant control or world target, and feedback from what actually happened. An acknowledgement button moves between completed lessons; it never substitutes for the requested practice action. Players can repeat a lesson, skip ahead if stuck, or leave training. Training is untimed and mistakes are recoverable.

## Curriculum

The implementation will group these topics into short exploration and combat exercises. Each exercise introduces unfamiliar words before using them; advanced details are available without becoming prerequisites.

1. **Welcome and the party:** D&D is a game of choices, dice and characters with different strengths. You control the whole party. Explain that the practice characters and supplies are separate from the campaign.
2. **Explore:** move a character on an existing map using the real navigation controls. Explain camera movement, selectable party members, nearby objects and the difference between free exploration and combat turns.
3. **Read a character:** open the actual character sheet. Explain hit points (how much harm you can take), Armor Class (how hard you are to hit), ability scores, modifiers and proficiency. Highlight the related information rather than expecting the learner to memorize the sheet.
4. **Try a check:** make an actual ability/skill check through the rules engine. Explain d20 + relevant bonus versus Difficulty Class, success/failure and why a failure is not a broken control. Explain advantage/disadvantage as two d20s keeping the higher/lower result. Use original explanatory wording.
5. **A conversation with checks:** talk with Ismark using the real dialogue UI. Choose the speaking hero, ask an ordinary question, or try Persuasion/Insight against DC 10. Read the genuine roll and its success/failure reply. Both outcomes complete practice.
6. **Objects and inventory:** interact with a practice object and inspect/use the actual inventory screen or its existing item controls. Teach where items, equipment and healing supplies live. Use a safe practice interaction and clear feedback.
7. **Recovery:** practice a real rest on the isolated party and show changed HP/resources. Explain the different purposes of short and long rests, limited healing resources, spell preparation and campaign restrictions. Preserve campaign time and supplies.
8. **Combat orientation:** introduce initiative/turn order, the selected actor, party portraits, enemy targets, the combat log, and the current resource indicators. Explain that one square is five feet.
9. **Movement:** require a real move and show the movement allowance change. Explain that moving and taking an Action are separate and that terrain/range matter.
10. **Weapon attack:** require a real weapon attack through the usual HUD/targeting. Explain attack roll versus AC, hit/miss and damage dice. Both a hit and a miss satisfy the exercise. Point to the log for the actual calculation.
11. **Bonus Action:** use the fighter’s real Second Wind on a wounded practice character. Show healing and Bonus Action/resource consumption. Explain that a Bonus Action is an ability-specific option, not any second Action.
12. **End turn:** use the normal End Turn control, observe a harmless legal opponent turn and return to a refreshed player turn. Explain which resources return each turn.
13. **Reaction:** cause a real opportunity-attack decision when a practice opponent leaves melee reach. The normal reaction prompt must resolve a genuine pending Encounter decision. Explain that reactions happen outside your own turn and are limited. Accept either deliberate response.
14. **Cantrip and saving throw:** cast an existing cantrip through real targeting. Explain repeatable cantrips and a target’s saving throw against a spell DC. A successful enemy save also completes the learning action.
15. **Spell slots and healing:** cast a real healing spell on a wounded ally; show HP restoration and the slot decrease. Explain spell level versus character level, range and limited slots.
16. **Concentration:** cast an existing concentration spell such as Bless; show the concentration state and explain one spell at a time, checks after damage and ending/replacing it.
17. **Apply what you learned:** a small, recoverable practice battle using the same controls, without step-by-step restrictions. Provide reminders and a restart path. Explain zero HP/death saves and help for fallen allies without requiring the learner to lose.
18. **Ready for the campaign:** summarize where to find the character sheet, inventory, journal, rest, tooltips and combat log. Give a simple decision sequence: select a hero, check movement and resources, choose an action, inspect the result, then end the turn. Continue into the already-selected campaign or return to the title for replay.

If investigation reveals a specific exercise cannot safely reuse an existing screen, the lesson will use the existing rules API and render its genuine result, documenting the distinction. It must not simulate a successful action or display a fabricated reaction.

## Architecture and isolation

- Introduce a dedicated tutorial session/scene and a small explicit lesson controller. Lesson state is local and is not added to campaign saves; no save-version change.
- The menu retains ownership of the pending campaign choices. Reuse its existing campaign-start function after training.
- Construct fresh practice characters, a local StoryState and a local DiceRoller. Never reuse selected campaign Character instances.
- Reuse LocationView with a copied existing location definition. Remove campaign exits, encounter triggers, quests and unrelated narration from the copy before creating the training view.
- Reuse CombatView directly with Encounter, ActionCatalog, ArenaBoard, CombatToken and CameraRig. Do not enter combat via LocationFights, because its round-start path writes saves.
- Give combat presentation a minimal observer hook for performed events where needed. Tutorial progression observes commands/results after normal presentation; it does not drain or mutate the view’s event queue.
- If scripted opponent behavior is needed, expose an optional callback that defaults to the existing AI. Practice opponents still call the normal encounter movement/action/turn APIs.
- Restore mode, pause state, camera/input ownership, music and any scoped dice changes on every exit. Do not open normal campaign Save/Load/Quit screens from practice.
- A lesson can restart from a fresh fixture, restoring its required actors/resources. Wrong actions must not permanently prevent progression.
- Keep new APIs small and generic. Rules remain pure and typed; UI text explains values computed by the existing rules engine.

## Coaching UI and accessibility

- Build with UiKit/UiParts, Look palette and existing assets. Use the current UI design language.
- Show lesson number, title, brief concept, one objective and completion feedback. Longer explanations are secondary/scrollable.
- Resolve highlight rectangles from actual controls at runtime. A public HUD anchor method avoids copying private layout assumptions. Recompute after resize, UI scaling and panel changes.
- Only the current action or target accepts pointer input; the rest of the screen is dimmed and blocked. Readable statistics and dialogue have separate apertures that remain unclickable. Temporary controller scopes cover coach confirmations, while active combat retains its normal controller targeting.
- Keep controls outside essential gameplay targets; clamp to the viewport. Support the project’s tested aspect ratios and larger reading text.
- Use InputActions and PadGlyphs for the active bindings/device, rather than hardcoded keyboard instructions.
- Provide controller and keyboard access to continue/retry/skip/exit. Escape/Back exposes a safe tutorial menu, not campaign saving.
- Respect reduced-motion options; progress feedback must not depend on color, flashing or animation.
- Do not auto-advance past explanations before the learner can read them. An attack miss or resisted cantrip is useful feedback and cannot stall the lesson.

## Parallel ownership

1. **Session/integration (primary agent):** tutorial host, exploration/check/inventory/recovery exercises, menu invitation/replay, state isolation, integration and PR.
2. **Combat workstream:** actual practice encounters and event-based lesson progression, minimal CombatView observer/opponent hooks and CombatHud highlight anchors; focused combat tests.
3. **Coaching workstream:** reusable tutorial coach/highlight UI, keyboard/controller behavior and responsive layout; layout-test additions.
4. **Validation workstream:** independent scenario tests, capture fixture and eventual review of end-to-end flow/isolation. Coordinate interface contracts before writing fixtures.

All agents work in the one new worktree. Each owns distinct files. No agent edits main, creates extra worktrees or commits another agent’s unfinished changes.

## Verification

- Add meaningful tests for requested actions versus unrelated actions, hit/miss outcomes, resisted cantrips, real resource spending, reaction accept/decline, retry and skip.
- Test new-game prompt, back/skip/complete/replay paths and preservation of selected party/custom hero/difficulty.
- Compare campaign state, selected save slot and save files before/after tutorial sessions; training must not award achievements or mutate campaign state.
- Test dismissal/scene teardown while presentation is active, no stale callbacks, no stuck pause or mode, and safe cancellation.
- Add the new screens/panels to test_layout.gd at the existing viewport sizes and large text.
- Exercise real input where practical, including controller navigation and combat targeting. Internal method tests alone do not establish usability.
- Add a reusable capture scene and run the actual game through the no-focus offscreen capture tool. Inspect invitation, exploration, combat highlights, reaction, healing and completion at normal and constrained sizes.
- Run make import after new class names, focused relevant tests during development, then make check with a clean log. Run validate when content/rules documentation changes. Do not run the entire historical test suite without a relevant reason.
- Review the final diff for unintended assets, temporary files, global state writes, save-format changes and regressions to ordinary combat/menu behavior.

## Delivery

Commit the tutorial, tests, capture fixture and this plan to the new branch. Write a concise build note with implementation and validation evidence into the existing Obsidian project vault. Remove only our temporary diagnostic files, retain useful review captures, and keep the branch/worktree available for review. Push the feature branch, create a pull request against main, and attach the PR to this task. Do not merge or push main.

## Requested refinement: guided scenarios and dialogue

The owner added an eighteenth lesson: a sample conversation with real Persuasion and Insight checks, ordinary questions, speaker selection, and different success/failure responses. Then the owner requested a standard walkthrough presentation: highlight the next actionable control/target, dim all other areas and prevent interaction outside the current step. Implement exact spotlight apertures, native control focus restrictions, command guards for alternate inputs, and a visible confirmation for multi-target Bless. Keep retry/skip/exit available during all screens. The final practice battle is unrestricted so the player can apply the lessons. Validate pointer blocking, controller reachability, popup restrictions, and multi-step action/target changes in addition to the earlier plan.

## Implemented walkthrough details

The character sheet contains two guided reading steps over actual HP/AC and ability/save/skill widgets, followed by an explicit Back to practice action. Combat lessons progress from the highlighted hotbar action to its valid target; Bless has a separate confirmation. Reaction and End Turn prompts restrict controller focus to the highlighted choices. All alternate command routes are gated during lessons; the final practice battle uses normal AI and unrestricted controls.

Runtime verification uses the actual game through the repository's offscreen capture runner, with separate capture saves/settings. Automated tests exercise mouse apertures, controller targeting and confirmation, success/failure dialogue branches, actual resource changes, teardown, campaign/save isolation, and preservation of the turn-based exploration preference. Screenshots cover both 1600×900 defaults and 1024×768 with maximum UI/text scaling. Final validation results and the PR are recorded in the Obsidian build log.
