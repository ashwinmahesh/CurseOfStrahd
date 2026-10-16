#!/usr/bin/env python3
"""Isolated iOS preparation, preflight, Xcode export and archive (stdlib only).

Never imports into the source checkout or edits its signing settings. See docs/releases/ios.md.
"""
from __future__ import annotations

import argparse
import configparser
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
ENGINE_VERSION = "4.7.2"
RUNTIME_DIRS = ("core", "rules", "combat", "story", "world", "ui", "scenes", "skirmish",
                "data", "narrative", "shaders", "audio", "art", "addons", "tests/saves")
RUNTIME_FILES = ("tests/support/party_autopilot.gd", "tests/support/party_autopilot.gd.uid")
OMIT = {"art/generated", "art/prompts", "art/sourced/game_icons"}
ERRORS = re.compile(r"SCRIPT ERROR|ERROR:|Parse Error|Failed loading")
APP_LIMIT = 4_000_000_000


def config(path: Path) -> configparser.ConfigParser:
    result = configparser.ConfigParser(interpolation=None, strict=True)
    result.optionxform = str
    result.read(path, encoding="utf-8")
    return result


def write_config(path: Path, data: configparser.ConfigParser) -> None:
    with path.open("w", encoding="utf-8") as stream:
        data.write(stream, space_around_delimiters=False)


def project_values(path: Path, section: str, values: dict[str, str]) -> None:
    """Change only scalar settings in the isolated project, preserving Godot's multiline dictionaries.

    The editor deliberately ignores override.cfg, so import/export settings must live in project.godot.
    """
    text = path.read_text()
    header = re.search(r'^\[' + re.escape(section) + r'\]\s*$', text, re.MULTILINE)
    if header:
        start = header.end()
        following = re.search(r'^\[[^\]\n]+\]\s*$', text[start:], re.MULTILINE)
        end = start + following.start() if following else len(text)
        body = text[start:end]
    else:
        text += '\n[' + section + ']\n'
        start = end = len(text)
        body = ''
    for key, value in values.items():
        pattern = r'^' + re.escape(key) + r'=.*$'
        entry = key + '=' + value
        if re.search(pattern, body, re.MULTILINE):
            body = re.sub(pattern, lambda _: entry, body, count=1, flags=re.MULTILINE)
        else:
            body = body.rstrip() + '\n' + entry + '\n'
    updated = text[:start] + body + text[end:]
    if updated != path.read_text():
        path.write_text(updated)


def validate_identity(team: str, bundle: str, version: str, build: str) -> None:
    if team and not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise ValueError("IOS_TEAM_ID must be the ten-character Apple team ID")
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle):
        raise ValueError("IOS_BUNDLE_ID must be a reverse-DNS identifier")
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("VERSION must be major.minor.patch")
    if not re.fullmatch(r"[1-9]\d*", build):
        raise ValueError("IOS_BUILD must be a positive integer")


def template_dir() -> Path:
    if sys.platform == "darwin":
        base = Path.home() / "Library/Application Support/Godot"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "godot"
    return base / "export_templates" / f"{ENGINE_VERSION}.stable"


def probe(command: list[str]) -> str:
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=30)
        return result.stdout.strip() if result.returncode == 0 else ""
    except (OSError, subprocess.TimeoutExpired):
        return ""


def preflight(godot: str, team: str, simulator: bool = False) -> list[str]:
    failures = []
    if sys.platform != "darwin":
        failures.append("Export/archive requires macOS with full Xcode")
    version = probe([godot, "--headless", "--version"])
    if not version.startswith(f"{ENGINE_VERSION}.stable."):
        failures.append(f"Install Godot {ENGINE_VERSION} stable or set GODOT to its executable")
    if not (template_dir() / "ios.zip").is_file():
        failures.append(f"Install {template_dir() / 'ios.zip'} from the matching Godot export templates")
    if not probe(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"]):
        failures.append("Install/select full Xcode and its iOS SDK (CommandLineTools alone is insufficient)")
    if not probe(["xcodebuild", "-version"]):
        failures.append("Complete Xcode first launch and license setup; verify xcodebuild -version")
    if not team and not simulator:
        failures.append("Set IOS_TEAM_ID to your Apple team ID before exporting")
    return failures


def copy_resource(source: str, destination: str) -> str:
    # clonefile preserves APFS copy-on-write sharing without a subprocess per asset; elsewhere copy normally.
    if Path(source).is_symlink():
        raise ValueError(f"Resource symlinks are unsupported in a reproducible iOS stage: {source}")
    if sys.platform == "darwin":
        clone = ctypes.CDLL(None, use_errno=True).clonefile
        clone.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
        clone.restype = ctypes.c_int
        if clone(os.fsencode(source), os.fsencode(destination), 0) == 0:
            return destination
    return shutil.copy2(source, destination)


def mobile_texture_imports(stage: Path, simulator: bool = False) -> list[dict]:
    """Keep atlas coordinates intact while reducing package size in the isolated iOS stage.

    Basis Universal stores sprite sheets compactly and transcodes to GPU compression at load. Full-screen
    cinematics are streamed one at a time as lossy textures; they do not need a GPU-compressed mip chain.
    Raw creator pieces (alpha palette keys) and UI artwork retain their original import settings.
    """
    changed = []
    for family in ["sprites", "cutscenes"]:
        for path in sorted((stage / "art" / family).rglob("*.import")):
            original = path.read_text()
            if not re.search(r'^importer="texture"$', original, re.MULTILINE):
                continue
            mode = re.search(r'^compress/mode=(\d+)$', original, re.MULTILINE)
            if not mode or int(mode[1]) not in [2, 4] and family != "cutscenes":
                continue
            values = {"detect_3d/compress_to": "0"}
            if family == "sprites":
                values.update({"compress/mode": "4", "compress/uastc_level": "0", "compress/rdo_quality_loss": "1.0"})
                if simulator and simulator_sprite_size(path):
                    values["process/size_limit"] = "4096"
            else:
                values.update({"compress/mode": "1", "compress/lossy_quality": "0.85", "mipmaps/generate": "false", "process/size_limit": "2048"})
            project_values(path, "params", values)
            changed.append({"path": path.relative_to(stage).as_posix(), "parameters": values})
    if simulator:
        # Apple's software GLES driver supports ETC2, not ASTC. Godot 4.7.2's CPU ASTC decompressor also
        # rejects some mip offsets, so avoid that fallback without changing physical-device texture quality.
        for path in sorted((stage / "art").rglob("*.import")):
            original = path.read_text()
            if re.search(r'^importer="texture"$', original, re.MULTILINE) and re.search(r'^compress/mode=2$', original, re.MULTILINE):
                values = {"compress/high_quality": "false", "detect_3d/compress_to": "0"}
                project_values(path, "params", values)
                changed.append({"path": path.relative_to(stage).as_posix(), "parameters": values})
    return changed


def simulator_sprite_size(import_path: Path) -> tuple[int, int] | None:
    """The software GLES simulator reports GL_MAX_TEXTURE_SIZE=4096; device Metal is unaffected."""
    source = import_path.with_suffix("")
    if source.suffix != ".png" or not source.is_file():
        return None
    with source.open("rb") as stream:
        header = stream.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    size = struct.unpack(">II", header[16:24])
    return size if max(size) > 4096 else None


def simulator_atlas_dimensions(stage: Path) -> list[dict]:
    """Restore logical source sizes after import, keeping atlas regions on the original coordinate grid.

    Godot's size_limit resizes before writing GST2's logical dimensions. Its pinned v1 format supports
    logical dimensions independent of the compressed image payload (CompressedTexture2D::load).
    Only the isolated simulator cache is patched; fail closed if the engine changes that format.
    """
    changed = []
    for path in sorted((stage / "art/sprites").rglob("*.png.import")):
        size = simulator_sprite_size(path)
        if not size or not re.search(r'^process/size_limit=4096$', path.read_text(), re.MULTILINE):
            continue
        destinations = re.findall(r'^path(?:\.\w+)?="res://([^"]+\.ctex)"$', path.read_text(), re.MULTILINE)
        if not destinations:
            raise ValueError(f"Missing imported simulator sprite: {path}")
        for relative in destinations:
            texture = stage / relative
            with texture.open("r+b") as stream:
                header = stream.read(16)
                if header[:8] != b"GST2\x01\x00\x00\x00":
                    raise ValueError(f"Unsupported Godot texture header: {texture}")
                stream.seek(8)
                stream.write(struct.pack("<II", *size))
            changed.append({"path": relative, "logical_size": list(size), "pixel_limit": 4096})
    return changed


def prepare(source: Path, output: Path, team: str, bundle: str, version: str, build: str, simulator: bool = False) -> Path:
    validate_identity(team, bundle, version, build)
    source, output = source.resolve(), output.resolve()
    if output == source or source in output.parents or output in source.parents:
        raise ValueError("IOS_OUT must be outside the source checkout and must not contain it")
    if output.exists():
        raise ValueError(f"Output already exists: {output}. Choose a fresh IOS_OUT; existing builds are preserved")
    output.mkdir(parents=True)
    stage = output / "project"
    stage.mkdir()

    def ignore(directory: str, names: list[str]) -> list[str]:
        for name in names:
            if (Path(directory) / name).is_symlink():
                raise ValueError(f"Resource symlinks are unsupported: {Path(directory) / name}")
        return [name for name in names if name in {".DS_Store", "__pycache__", ".godot", ".git"}
                or (Path(directory) / name).relative_to(source).as_posix() in OMIT]

    for directory in RUNTIME_DIRS:
        path = source / directory
        if path.exists():
            shutil.copytree(path, stage / directory, copy_function=copy_resource, ignore=ignore)
    # CombatView's development-only autoplay is statically typed, so its script is needed even in release builds.
    for name in RUNTIME_FILES:
        path = source / name
        if path.exists():
            (stage / name).parent.mkdir(parents=True, exist_ok=True)
            copy_resource(str(path), str(stage / name))
    texture_policy = mobile_texture_imports(stage, simulator)
    shutil.copy2(source / "project.godot", stage / "project.godot")
    project_values(stage / "project.godot", "application", {"config/version": json.dumps(version)})
    settings = {"textures/vram_compression/import_etc2_astc": "true",
                "textures/vram_compression/import_s3tc_bptc": "false",
                "textures/basis_universal/zstd_supercompression": "true"}
    if simulator:
        # Apple's simulator Compatibility driver renders in software. Draw at logical points while keeping
        # native layout, UIKit coordinates and touch semantics; device Metal exports retain Retina rendering.
        project_values(stage / "project.godot", "display", {"window/stretch/mode": '"viewport"'})
        for key in ["renderer/rendering_method", "renderer/rendering_method.mobile", "renderer/rendering_method.ios"]:
            settings[key] = '"gl_compatibility"'
    project_values(stage / "project.godot", "rendering", settings)
    presets = config(source / "export_presets.cfg")
    section = next((s for s in presets.sections() if presets.get(s, "name", fallback="") == '"iOS"'), None)
    if section is None:
        raise ValueError("Source project has no iOS export preset")
    selected = configparser.ConfigParser(interpolation=None)
    selected.optionxform = str
    selected["preset.0"] = dict(presets[section])
    selected["preset.0"]["export_path"] = json.dumps("../xcode/CurseOfStrahd.xcodeproj")
    selected["preset.0.options"] = dict(presets[section + ".options"])
    options = selected["preset.0.options"]
    for key, value in {"app_store_team_id": team, "bundle_identifier": bundle,
                       "short_version": version, "version": build}.items():
        options["application/" + key] = json.dumps(value)
    options["application/targeted_device_family"] = "2"  # Universal iPhone + iPad.
    if simulator:
        # Exporter's required syntax placeholder; never used for signing or device distribution.
        options["application/app_store_team_id"] = '"SIMULATOR0"'
    write_config(stage / "export_presets.cfg", selected)
    files = []
    for path in sorted(stage.rglob("*")):
        if not path.is_file():
            continue
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            first = stream.read(1024 * 1024)
            if first.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
                raise ValueError(f"Missing LFS content: {path.relative_to(stage)}; fetch LFS files before export")
            digest.update(first)
            while chunk := stream.read(1024 * 1024):
                digest.update(chunk)
        files.append({"path": path.relative_to(stage).as_posix(), "bytes": path.stat().st_size,
                      "sha256": digest.hexdigest()})
    metadata = {"source_revision": probe(["git", "-C", str(source), "rev-parse", "HEAD"]),
                "source_dirty": bool(probe(["git", "-C", str(source), "status", "--porcelain"])),
                "engine": ENGINE_VERSION, "simulator": simulator, "bundle_identifier": bundle, "version": version, "build": build,
                "inventory_kind": "source resources, not exported bundle or device memory",
                "mobile_texture_imports": texture_policy,
                "source_bytes": sum(f["bytes"] for f in files), "files": files}
    (output / "source-inventory.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared isolated project: {stage}")
    return stage


def logged(command: list[str], log: Path, check_errors: bool = False) -> None:
    print(f"Running {Path(command[0]).name}; log: {log}", flush=True)
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT)
    content = log.read_text(encoding="utf-8", errors="replace")
    if result.returncode or (check_errors and ERRORS.search(content)):
        print("\n".join(content.splitlines()[-40:]), file=sys.stderr)
        raise RuntimeError(f"{Path(command[0]).name} failed; full log: {log}")


def export(source: Path, output: Path, godot: str, team: str, bundle: str, version: str, build: str, simulator: bool = False) -> None:
    failures = preflight(godot, team, simulator)
    if failures:
        raise ValueError("\n".join(failures))
    # Fail before allocating/importing a second asset cache on a nearly full volume.
    ancestor = output.resolve().parent
    while not ancestor.exists():
        ancestor = ancestor.parent
    if shutil.disk_usage(ancestor).free < 20 * 1024 ** 3:
        raise ValueError("A fresh iOS import requires at least 20 GiB free")
    stage = prepare(source, output, team, bundle, version, build, simulator)
    from ios_native import build as build_native
    build_native(stage, output / "native-build.log")
    command = [godot, "--headless", "--path", str(stage), "--editor", "--import"]
    try:
        logged(command, output / "import.log", check_errors=True)
    except RuntimeError:
        # As tools/import.sh does: one retry after the first pass has registered all script classes/resources.
        logged(command, output / "import-retry.log", check_errors=True)
    if simulator:
        adjusted = simulator_atlas_dimensions(stage)
        (output / "simulator-atlas-dimensions.json").write_text(json.dumps(adjusted, indent=2) + "\n")
    xcode = output / "xcode"
    xcode.mkdir()
    logged([godot, "--headless", "--path", str(stage), "--export-release", "iOS",
            str(xcode / "CurseOfStrahd.xcodeproj")], output / "export.log", check_errors=True)
    if not (xcode / "CurseOfStrahd.xcodeproj/project.pbxproj").is_file():
        raise RuntimeError("Exporter returned without an Xcode project")
    (output / "toolchain.json").write_text(json.dumps({
        "godot": probe([godot, "--headless", "--version"]), "xcode": probe(["xcodebuild", "-version"]),
        "sdk": probe(["xcrun", "--sdk", "iphoneos", "--show-sdk-version"])
    }, indent=2) + "\n", encoding="utf-8")
    print(f"Xcode project: {xcode / 'CurseOfStrahd.xcodeproj'}")


def simulator_build(output: Path) -> Path:
    project = output / "xcode/CurseOfStrahd.xcodeproj"
    if not (project / "project.pbxproj").is_file():
        raise ValueError("Run ios-simulator-export before ios-simulator-build")
    inventory = json.loads((output / "source-inventory.json").read_text())
    if not inventory.get("simulator"):
        raise ValueError("Use a simulator stage; device Metal exports cannot run in the simulator")
    from ios_simulator import ensure_arm64
    ensure_arm64(output)
    logged(["xcodebuild", "-project", str(project), "-scheme", "CurseOfStrahd", "-configuration", "Release",
            "-sdk", "iphonesimulator", "-destination", "generic/platform=iOS Simulator",
            "-derivedDataPath", str(output / "derived"), "CODE_SIGNING_ALLOWED=NO",
            "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY=", "DEVELOPMENT_TEAM=", "build"],
           output / "simulator-build.log")
    app = output / "derived/Build/Products/Release-iphonesimulator/CurseOfStrahd.app"
    sizes = report(app)
    (output / "simulator-size.json").write_text(json.dumps(sizes, indent=2) + "\n")
    print(f"Unsigned simulator application: {app}")
    return app


def simulator_test(output: Path, device: str, result: Path) -> None:
    if not device:
        raise ValueError("Set IOS_DEVICE to an existing dedicated QA simulator UUID")
    if result.exists():
        raise ValueError("Test results already exist; choose a fresh IOS_RESULT to preserve the evidence")
    inventory = json.loads((output / "source-inventory.json").read_text())
    if not inventory.get("simulator") or inventory.get("bundle_identifier") != "app.curseofstrahd.game":
        raise ValueError("Full-game journeys require a simulator stage with bundle app.curseofstrahd.game")
    from ios_simulator import ensure_arm64
    from ios_ui_tests import attach
    ensure_arm64(output)
    project = output / "xcode/CurseOfStrahd.xcodeproj"
    attach(project, ROOT / "tests/ios/NativeGameTests.swift")
    boot = subprocess.run(["xcrun", "simctl", "boot", device], capture_output=True, text=True)
    if boot.returncode and "Booted" not in boot.stderr:
        raise RuntimeError(boot.stderr)
    subprocess.run(["xcrun", "simctl", "bootstatus", device, "-b"], check=True)
    logged(["xcodebuild", "-project", str(project), "-scheme", "NativeQA",
            "-destination", "platform=iOS Simulator,id=" + device,
            "-derivedDataPath", str(output / "derived"), "-resultBundlePath", str(result),
            "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY=", "DEVELOPMENT_TEAM=", "test"],
           result.with_suffix(".log"))
    print("Full-game simulator results: " + str(result))


def report(app: Path) -> dict:
    if not app.is_dir() or app.suffix != ".app":
        raise ValueError("IOS_APP must name the built .app directory, not an IPA, PCK or source stage")
    files = [{"path": p.relative_to(app).as_posix(), "bytes": p.stat().st_size}
             for p in app.rglob("*") if p.is_file()]
    total = sum(f["bytes"] for f in files)
    return {"app": app.name, "uncompressed_bytes": total, "limit_bytes": APP_LIMIT,
            "within_limit": total <= APP_LIMIT, "files": sorted(files, key=lambda f: -f["bytes"])}


def archive(output: Path) -> None:
    project = output / "xcode/CurseOfStrahd.xcodeproj"
    destination = output / "CurseOfStrahd.xcarchive"
    if not (project / "project.pbxproj").is_file():
        raise ValueError("Run ios-export successfully before ios-archive")
    if destination.exists():
        raise ValueError("Archive already exists; use a fresh output to preserve the previous build")
    signing = []
    if os.environ.get("IOS_PROVISIONING_UUID"):
        required = ["IOS_TEAM_ID", "IOS_SIGNING_IDENTITY", "IOS_KEYCHAIN"]
        if any(not os.environ.get(key) for key in required):
            raise ValueError("Manual signing requires IOS_TEAM_ID, IOS_SIGNING_IDENTITY and IOS_KEYCHAIN")
        signing = ["CODE_SIGN_STYLE=Manual", "DEVELOPMENT_TEAM=" + os.environ["IOS_TEAM_ID"],
                   "PROVISIONING_PROFILE_SPECIFIER=" + os.environ["IOS_PROVISIONING_UUID"],
                   "CODE_SIGN_IDENTITY=" + os.environ["IOS_SIGNING_IDENTITY"],
                   'OTHER_CODE_SIGN_FLAGS=--keychain "' + os.environ["IOS_KEYCHAIN"] + '"']
    logged(["xcodebuild", "-project", str(project), "-scheme", "CurseOfStrahd", "-configuration", "Release",
            "-destination", "generic/platform=iOS", "-archivePath", str(destination), *signing, "archive"],
           output / "archive.log")
    apps = list((destination / "Products/Applications").glob("*.app"))
    if len(apps) != 1:
        raise RuntimeError("Expected one application in the archive")
    sizes = report(apps[0])
    (output / "app-size.json").write_text(json.dumps(sizes, indent=2) + "\n", encoding="utf-8")
    if not sizes["within_limit"]:
        raise RuntimeError("Archive exceeds the 4 GB app limit; see app-size.json before distribution")
    print(f"Archive: {destination}; uncompressed app: {sizes['uncompressed_bytes']:,} bytes")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["check", "prepare", "export", "archive", "report", "simulator-build", "simulator-test"])
    parser.add_argument("--output", type=Path, default=ROOT.parent / "strahd-builds/ios")
    parser.add_argument("--godot", default=os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot"))
    parser.add_argument("--app", type=Path)
    parser.add_argument("--device", default="")
    parser.add_argument("--result", type=Path)
    parser.add_argument("--simulator", action="store_true", help="unsigned Compatibility build for simulator only")
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    team = os.environ.get("IOS_TEAM_ID", "")
    bundle = os.environ.get("IOS_BUNDLE_ID", "app.curseofstrahd.game")
    version = os.environ.get("VERSION", "1.0.0")
    build = os.environ.get("IOS_BUILD", "1")
    try:
        validate_identity(team, bundle, version, build)
        if args.action == "check":
            failures = preflight(args.godot, team, args.simulator)
            for failure in failures:
                print(f"MISSING: {failure}")
            if not failures:
                print("iOS export prerequisites found. Device signing is validated by Xcode during build.")
            return int(bool(failures))
        if args.action == "prepare":
            prepare(ROOT, output, team, bundle, version, build, args.simulator)
        elif args.action == "export":
            export(ROOT, output, args.godot, team, bundle, version, build, args.simulator)
        elif args.action == "simulator-build":
            simulator_build(output)
        elif args.action == "simulator-test":
            simulator_test(output, args.device, args.result or output / "game-tests.xcresult")
        elif args.action == "archive":
            archive(output)
        elif args.action == "report":
            if args.app is None:
                raise ValueError("Set IOS_APP to a built .app directory")
            sizes = report(args.app)
            print(json.dumps(sizes, indent=2))
            return int(not sizes["within_limit"])
    except (ValueError, RuntimeError, OSError) as error:
        print(f"iOS: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
