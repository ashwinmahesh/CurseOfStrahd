"""Build-boundary tests: staging isolation, artifact accounting, and honest failure reporting."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("ios_build", Path(__file__).resolve().parents[2] / "tools/release/ios.py")
ios = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ios)


class IosBuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "source"
        self.source.mkdir()
        self.output = self.root / "output"
        (self.source / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Game"\n')
        (self.source / "export_presets.cfg").write_text(
            '[preset.1]\nname="iOS"\nplatform="iOS"\ninclude_filter="*.dialogue"\n'
            '[preset.1.options]\napplication/export_project_only=true\n')
        for name in ["core/game.gd", "narrative/story.dialogue", "art/sprites/hero.png",
                     "art/sprites/hero.png.import", "audio/voice/clip.mp3", "tests/saves/chapter.json",
                     "art/generated/unshipped.png", ".godot/imported/desktop.ctex", "tools/dev.gd"]:
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("source content\n")

    def prepare(self, **options):
        with patch.object(ios, "probe", return_value=""):
            return ios.prepare(self.source, self.output, options.get("team", "ABCDEFGHIJ"),
                               "app.example.game", "1.2.3", "7", options.get("simulator", False))

    def test_stage_keeps_dynamic_resources_but_not_desktop_cache_or_generation_inputs(self):
        stage = self.prepare()
        for path in ["narrative/story.dialogue", "audio/voice/clip.mp3", "tests/saves/chapter.json",
                     "art/sprites/hero.png.import"]:
            self.assertTrue((stage / path).is_file(), path)
        for path in [".godot", "tools", "art/generated"]:
            self.assertFalse((stage / path).exists(), path)
        self.assertIn("import_etc2_astc=true", (stage / "override.cfg").read_text())
        self.assertIn("import_s3tc_bptc=false", (stage / "override.cfg").read_text())
        options = ios.config(stage / "export_presets.cfg")["preset.0.options"]
        self.assertEqual(options["application/app_store_team_id"], '"ABCDEFGHIJ"')
        self.assertEqual(options["application/version"], '"7"')
        self.assertEqual(options["application/export_project_only"], "true")
        manifest = json.loads((self.output / "source-inventory.json").read_text())
        self.assertEqual(manifest["source_bytes"], sum(f["bytes"] for f in manifest["files"]))
        self.assertTrue(all(len(f["sha256"]) == 64 for f in manifest["files"]))

    def test_simulator_stage_is_unsigned_universal_and_uses_compatibility_only_in_stage(self):
        original = (self.source / "project.godot").read_bytes()
        stage = self.prepare(team="", simulator=True)
        overrides = (stage / "override.cfg").read_text()
        self.assertIn('renderer/rendering_method.ios="gl_compatibility"', overrides)
        self.assertEqual((self.source / "project.godot").read_bytes(), original)
        options = ios.config(stage / "export_presets.cfg")["preset.0.options"]
        self.assertEqual(options["application/targeted_device_family"], "2")
        self.assertTrue(json.loads((self.output / "source-inventory.json").read_text())["simulator"])
        with patch.object(ios, "probe", return_value=""), patch.object(ios, "template_dir", return_value=self.root):
            self.assertFalse(any("TEAM_ID" in f for f in ios.preflight("no-godot", "", simulator=True)))

    def test_simulator_build_rejects_device_stage_before_xcode_runs(self):
        self.prepare()
        project = self.output / "xcode/CurseOfStrahd.xcodeproj"
        project.mkdir(parents=True)
        (project / "project.pbxproj").write_text("project")
        with patch.object(ios, "logged") as build:
            with self.assertRaisesRegex(ValueError, "device Metal"):
                ios.simulator_build(self.output)
            build.assert_not_called()

    def test_staging_does_not_mutate_source_even_when_clone_is_rewritten(self):
        original = (self.source / "export_presets.cfg").read_bytes()
        stage = self.prepare()
        (stage / "art/sprites/hero.png.import").write_text("mobile importer changed this\n")
        self.assertEqual((self.source / "art/sprites/hero.png.import").read_text(), "source content\n")
        self.assertEqual((self.source / "export_presets.cfg").read_bytes(), original)
        self.assertFalse((self.source / "override.cfg").exists())

    def test_prepare_without_signing_credentials_is_allowed(self):
        stage = self.prepare(team="")
        self.assertEqual(ios.config(stage / "export_presets.cfg")["preset.0.options"]["application/app_store_team_id"], '""')

    def test_existing_outputs_and_checkout_destinations_are_rejected_without_deletion(self):
        self.output.mkdir()
        keep = self.output / "keep.txt"
        keep.write_text("previous build")
        with self.assertRaisesRegex(ValueError, "already exists"):
            self.prepare()
        self.assertEqual(keep.read_text(), "previous build")
        for output in [self.source, self.source / "build", self.root]:
            with self.assertRaisesRegex(ValueError, "outside"):
                ios.prepare(self.source, output, "", "app.example.game", "1.0.0", "1")

    def test_lfs_pointers_cannot_be_mistaken_for_shipped_assets(self):
        (self.source / "art/sprites/hero.png").write_text("version https://git-lfs.github.com/spec/v1\noid sha256:abc\nsize 123\n")
        with self.assertRaisesRegex(ValueError, "Missing LFS content"):
            self.prepare()

    def test_invalid_signing_values_fail_before_staging(self):
        with self.assertRaisesRegex(ValueError, "ten-character"):
            self.prepare(team='bad"\n[another section]')
        self.assertFalse(self.output.exists())
        for args in [("", "not a bundle", "1.0.0", "1"), ("", "app.example", "next", "1"),
                     ("", "app.example", "1.0.0", "0")]:
            with self.assertRaises(ValueError):
                ios.validate_identity(*args)

    def test_missing_sdk_template_and_team_are_all_reported(self):
        with patch.object(ios, "probe", return_value=""), patch.object(ios, "template_dir", return_value=self.root):
            failures = ios.preflight("no-godot", "")
        self.assertTrue(any("Godot" in f for f in failures))
        self.assertTrue(any("ios.zip" in f for f in failures))
        self.assertTrue(any("SDK" in f for f in failures))
        self.assertTrue(any("TEAM_ID" in f for f in failures))

    def test_export_fails_preflight_before_allocating_stage(self):
        with patch.object(ios, "preflight", return_value=["missing SDK"]):
            with self.assertRaisesRegex(ValueError, "missing SDK"):
                ios.export(self.source, self.output, "no-godot", "", "app.example", "1.0.0", "1")
        self.assertFalse(self.output.exists())

    def test_zero_exit_with_godot_errors_still_fails(self):
        log = self.root / "import.log"
        with self.assertRaisesRegex(RuntimeError, "failed"):
            ios.logged([ios.sys.executable, "-c", "print('ERROR: missing resource')"], log, check_errors=True)
        self.assertIn("missing resource", log.read_text())

    def test_app_report_counts_actual_artifact_bytes_and_rejects_source(self):
        app = self.root / "Game.app"
        app.mkdir()
        (app / "game.pck").write_bytes(b"a" * 100)
        (app / "game").write_bytes(b"b" * 20)
        with patch.object(ios, "APP_LIMIT", 119):
            report = ios.report(app)
        self.assertEqual(report["uncompressed_bytes"], 120)
        self.assertFalse(report["within_limit"])
        self.assertEqual(report["files"][0]["path"], "game.pck")
        with self.assertRaisesRegex(ValueError, "built .app"):
            ios.report(self.source)

    def test_archive_requires_export_and_preserves_previous_archive(self):
        with self.assertRaisesRegex(ValueError, "ios-export"):
            ios.archive(self.output)
        project = self.output / "xcode/CurseOfStrahd.xcodeproj"
        project.mkdir(parents=True)
        (project / "project.pbxproj").write_text("project")
        (self.output / "CurseOfStrahd.xcarchive").mkdir()
        with self.assertRaisesRegex(ValueError, "already exists"):
            ios.archive(self.output)


if __name__ == "__main__":
    unittest.main()
