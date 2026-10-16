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
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
ENGINE_VERSION = "4.7.2"
RUNTIME_DIRS = ("core", "rules", "combat", "story", "world", "ui", "scenes", "skirmish",
                "data", "narrative", "shaders", "audio", "art", "addons", "tests/saves")
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


def preflight(godot: str, team: str) -> list[str]:
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
    if not team:
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


def prepare(source: Path, output: Path, team: str, bundle: str, version: str, build: str) -> Path:
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
    shutil.copy2(source / "project.godot", stage / "project.godot")
    # ConfigFile's multiline dictionaries must stay in Godot syntax: use an override file for stage-only imports.
    (stage / "override.cfg").write_text(
        '[application]\nconfig/version=' + json.dumps(version) + '\n\n'
        '[rendering]\ntextures/vram_compression/import_etc2_astc=true\n'
        'textures/vram_compression/import_s3tc_bptc=false\n', encoding="utf-8")
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
                "engine": ENGINE_VERSION, "bundle_identifier": bundle, "version": version, "build": build,
                "inventory_kind": "source resources, not exported bundle or device memory",
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


def export(source: Path, output: Path, godot: str, team: str, bundle: str, version: str, build: str) -> None:
    failures = preflight(godot, team)
    if failures:
        raise ValueError("\n".join(failures))
    # Fail before allocating/importing a second asset cache on a nearly full volume.
    ancestor = output.resolve().parent
    while not ancestor.exists():
        ancestor = ancestor.parent
    if shutil.disk_usage(ancestor).free < 20 * 1024 ** 3:
        raise ValueError("A fresh iOS import requires at least 20 GiB free")
    stage = prepare(source, output, team, bundle, version, build)
    command = [godot, "--headless", "--path", str(stage), "--editor", "--import"]
    try:
        logged(command, output / "import.log", check_errors=True)
    except RuntimeError:
        # As tools/import.sh does: one retry after the first pass has registered all script classes/resources.
        logged(command, output / "import-retry.log", check_errors=True)
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
    parser.add_argument("action", choices=["check", "prepare", "export", "archive", "report"])
    parser.add_argument("--output", type=Path, default=ROOT.parent / "strahd-builds/ios")
    parser.add_argument("--godot", default=os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot"))
    parser.add_argument("--app", type=Path)
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    team = os.environ.get("IOS_TEAM_ID", "")
    bundle = os.environ.get("IOS_BUNDLE_ID", "app.curseofstrahd.game")
    version = os.environ.get("VERSION", "1.0.0")
    build = os.environ.get("IOS_BUILD", "1")
    try:
        validate_identity(team, bundle, version, build)
        if args.action == "check":
            failures = preflight(args.godot, team)
            for failure in failures:
                print(f"MISSING: {failure}")
            if not failures:
                print("iOS export prerequisites found. Device signing is validated by Xcode during build.")
            return int(bool(failures))
        if args.action == "prepare":
            prepare(ROOT, output, team, bundle, version, build)
        elif args.action == "export":
            export(ROOT, output, args.godot, team, bundle, version, build)
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
