# ADR 0001: In-house headless test runner instead of GUT or gdUnit4

Status: accepted (Phase 0)

The plan asked Phase 0 to pick GUT or gdUnit4. We use a ~60 line runner (`tests/test_runner.gd` +
`tests/test_case.gd`), the same pattern as the owner's other Godot project.

- No third-party addon to download, pin or upgrade with Godot.
- Any `test_*` method in `tests/unit/` or `tests/integration/` runs; `make test ONLY=x` filters.
- `tools/logcheck.sh` fails the run on any SCRIPT ERROR, so a script that fails to compile can't hide behind a green count.

Revisit if we need mocking, parameterized tests or JUnit output for a hosted CI.
