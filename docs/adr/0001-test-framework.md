# ADR 0001: In-house headless test runner instead of GUT or gdUnit4

Status: accepted (Phase 0)

The plan asked Phase 0 to pick GUT or gdUnit4. We use a ~60 line runner (`tests/test_runner.gd` +
`tests/test_case.gd`), the same pattern as the owner's other Godot project.

- No third-party addon to download, pin or upgrade with Godot.
- Any `test_*` method in `tests/unit/` or `tests/integration/` runs; `make test ONLY=x` filters.
- `tools/logcheck.sh` fails the run on any SCRIPT ERROR, so a script that fails to compile can't hide behind a green count.
- `make test` runs the files in several headless processes at once (`tools/run_tests.py`, 2026-10-07): each takes the
  next file nobody has claimed, longest first, so one slow file never holds up a fixed share. A file's output stays
  together, and the run also fails when a process stops part-way or a file never ran. A file longer than half a
  process's share goes out a test at a time (the runner's --split), so the long tests run side by side. `JOBS=n` sets how many
  processes; `JOBS=1` is the single process, and a failing run prints each troubled process's files in order so
  `make test JOBS=1 FILES=...` replays it. Tests in one process still share autoloads, so a test leaves no state
  another needs; the runner takes out of the Compendium whatever a file added to it (fixture places and the like), and puts
  ModeController, the pause, the time scale, the save slot and GameState back as a fresh process has them.
- Golden saves (P4, 2026-10-07): `tests/saves` keeps saves written by older builds (each chapter's start, kept by the
  playthrough tests under `make golden-saves`, and some of the owner's own), and `test_golden_saves` loads them all in
  every run through `SaveSystem.upgrade`. A change to the save format bumps `GameState.SAVE_VERSION` and adds an
  upgrade step; the old saves stay (tests/saves/README.md).
- Layout checks (P5, 2026-10-07): `test_layout` opens every screen at 1080p, 1440p, a small window, 16:10 and 4:3
  with a late golden save's party and fails when text or a button reaches past the window, is wider or taller than a
  list that doesn't scroll that way, or is cut short with no ellipsis (`tests/support/layout_check.gd`). Spills found
  when it arrived wait in its KNOWN list for the lane that owns the screen; an entry fails once its spill is gone.

Revisit if we need mocking, parameterized tests or JUnit output for a hosted CI.
