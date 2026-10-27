# iOS engine-split review follow-up — 27 October 2026

The review of MR #5 requires a coordinated engine/game port after the physical move. The previously qualified
1.0.1 (4401) source and Apple VALID receipt remain historical evidence for the old layout; they do not qualify
this migration. No new upload, public App Review submission or merge is part of this follow-up.

The original `codex/ios-support-foundation` branch is preserved. The candidate host is
`codex/ios-support-on-core`, based on game main `d62004a76d1aa1e1768a7f8c2ff403fb263a9140`.
The engine candidate is `codex/ios-support`, based on engine main `ff162caf4e948ee1d49bc1b321361334ba00ab0d`.
Every changed path was classified by its current repository, and the three-way inputs and complete manifest are
preserved under `/Volumes/StrahdLanes/strahd-builds/ios-engine-port-20261027`.

Reusable mobile input, UI, accessibility projection, lifecycle, rendering, atomic saves and command recovery move
into the engine, with its unit tests. The host keeps its icon, identity, native iOS adapter, signing/export/listing
tools, campaign screens, capture tooling, native UI journeys and campaign integration tests. Moved resource paths
use `res://addons/dnd_core/...`; current campaign-module and look hooks are retained. The host registers its active
campaign scene with the engine's `campaign_world` group. Shared save-transfer validation no longer needs a campaign
pregen, the native adapter registers `MobileIOS`, and share names use the host title. Both desktop and mobile defeat
copy comes from `CampaignModule.defeat_text()`, so the engine gains no new campaign-name baseline allowance.

Mobile inventory retains current-main Attuned tags, inactive attunement warnings, framed rarity icons, rarity tags,
mark/type/search filtering and the rarity filter, with a touch-safe multi-selection page and empty-result recovery.
The shop retains Potions categories and rarity edges. Save format stays 2; issued preview version-3 saves keep their
read alias. Checkpoints, story autosaves, command continuation, round-start retry and Honour retain separate policies.

The iOS workflow recursively checks out and verifies the pinned engine. Export rejects an uninitialized checkout
before allocating a stage and records both source revisions. Its texture, atlas-size and simulator ETC2 policies
cover both host and engine artwork. The iOS preset keeps main's engine test exclusions. The quick-check planner now
finds changed engine tests and the moved compile test, which explicitly compiles engine scripts as well as the host.

Validation status is recorded in `continuation.md` and the source-pinned result files in the evidence directory.
Prepared offscreen macOS screenshots, native simulator journeys and physical-device results remain separate.
The native XCTest suite retains every previous assertion and timeout and adds an inventory rarity-filter recovery
journey for both device idioms. Physical-device performance, controller and assistive-technology sign-off remain open.

Landing order: publish and review the engine PR first. Keep game MR #5 a draft; do not publish a game gitlink to an
unmerged engine commit. After the engine lands, pin its merged commit in the host, update/rebase MR #5 and record the
final pair of revisions with its qualification. Desktop distribution of the project-path change stays coordinated
with the full-download engine-split batch. A future authorized new iOS upload must use at least marketing version
1.0.2; the existing 1.0.1 (4401) upload must not be repeated.
