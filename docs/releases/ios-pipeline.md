# iOS signing and TestFlight pipeline

Run **Actions → iOS builds → Run workflow** on the desired pipeline branch. Set `version` to the app's
marketing version, select `game` or `smoke`, and enable `upload` to send the signed IPA to App Store Connect.
Uploads are manual; pushes and pull requests only test the Python tooling. Nothing submits an App Store
review, invites testers, or publishes a public release.

`smoke` builds a small, clearly labelled Godot device application with the real app icon and Bundle ID.
It verifies the distribution path without downloading campaign assets. It contains no gameplay and must
not be submitted for public release. A successful run waits for Apple's processing state to become `VALID`,
and preserves that API response in `app-store-build.json`. Tester assignment and export-compliance answers
may still be required in App Store Connect.

`game` uses the iOS port's `make ios-export` target. The workflow and full port are integrated on
`codex/ios-support-foundation`; dispatch that branch with `source_ref` blank to use its workflow commit.
An optional exact `source_ref` selects another game commit from this repository.
The resolved source SHA is recorded in the job summary and artifact. The pipeline uses its own signing
and upload helpers regardless of the game source selected. The small native fixture in that branch is for
simulator utility tests, so this pipeline's deployment check uses the real device template instead.

## Repository configuration

Actions **secrets**:

- `IOS_DISTRIBUTION_P12_BASE64`: base64 of the Apple Distribution identity, including its private key.
- `IOS_DISTRIBUTION_P12_PASSWORD`: optional; absent means the P12 has an empty password.
- `IOS_PROVISIONING_PROFILE_BASE64`: base64 of an explicit App Store Connect distribution profile.
- `IOS_APPLE_API_KEY_P8` and `IOS_APPLE_API_KEY_ID`: the iOS App Manager API key.
- `APPLE_API_ISSUER_ID`: shared with the existing Mac pipeline.

Actions **variables**:

- `APPLE_TEAM_ID`: ten-character Apple Developer Team ID.
- `IOS_BUNDLE_ID`: `app.curseofstrahd.game`.
- `APP_STORE_APP_ID`: numeric App Store Connect app ID.

Signing checks reject expired, wildcard, development, ad-hoc, enterprise, wrong-team and wrong-Bundle-ID
profiles and require a matching certificate/private key. An ephemeral keychain holds the identity and a
checksum-pinned WWDR intermediate. Cleanup runs even after failure. API preflight checks app access and
Bundle ID before importing assets. Secrets are never saved in artifacts.

Godot 4.7.2 and its templates use pinned SHA-512 checksums. Xcode 26.3 is selected on the hosted `macos-15` image;
its version and SDK are printed on each run. Build numbers are `100 * run_number + run_attempt`, so reruns use a new
integer accepted by the port exporter (start a new run before 100 reruns). If another pipeline has already used that number for this version, start a new run or choose a new
marketing version. Full imports can take hours and need sufficient runner disk space; the IPA is capped at
4 GB uncompressed. Desktop import caches and signing workflows are not changed.

The artifact retains the IPA, zipped archive, logs, source commit and Apple processing response for 14 days.
To run local tooling tests: `make ios-pipeline-test`. A dry run still validates real signing and exports an
IPA; leave `upload` disabled to avoid contacting App Store Connect for an upload.

## Verified deployment

On 2026-10-16, [run 38982130266](https://github.com/ashwinmahesh/CurseOfStrahd/actions/runs/38982130266)
successfully signed, archived, exported and uploaded the deployment check as **1.0.0 (601)** for
`app.curseofstrahd.game`, App Store app `6823801189`. Apple's API reported **VALID**, build
`be8c399a-5652-4285-9c16-8f171cc04d5e`. The source was port commit
`456a2d4e57c9369890309b5d9dd8c1a6a7280163`; the uncompressed fixture was 68,854,620 bytes.
This validates signing and distribution, not full-game size, performance, or mobile gameplay.

## Full-game 1.0.1 deployment

On October 25, 2026, [run 40240102630](https://github.com/ashwinmahesh/CurseOfStrahd/actions/runs/40240102630)
signed, archived, exported and uploaded the complete game as **1.0.1 (4401)**. Apple reported **VALID** at
23:51:50 UTC, build `3cc6697a-7884-4308-b976-f565dccdd951`, for `app.curseofstrahd.game` / app `6823801189`.
The uncompressed device app is **3,231,159,332 bytes**. Qualified game source is `d623cd4bc7656849513bd8a860442e97198918b2`;
workflow source is `b32a6e65dce6944d3cb2086ee3d20a2b7a4fc3c9`. See [the qualification and receipt record](ios-qualification-2026-10-25.md).

This release passed 213 required checks, 23 focused terrain regressions and all eleven original native
phone/tablet journeys. The first software terrain error and delayed tablet-state failure remain preserved.
The Apple receipt, IPA/archive, inventories, toolchain, packaged policy checks, logs and file hashes are on the
external SSD under `strahd-builds/ios-release-1.0.1/qualification-20261025/workflow-40240102630/`.
Apple processing does not certify physical-device performance or App Review acceptance. No public review
submission, tester invitations or merge occurred. The next new version is 1.0.2 and needs current authorization.
