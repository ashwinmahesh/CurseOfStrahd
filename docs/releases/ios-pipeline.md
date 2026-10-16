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

`game` uses the iOS port's `make ios-export` target. Until the port is merged, set `source_ref` to an exact
commit from `codex/ios-support-foundation` in this repository. Blank means the pipeline's own commit.
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
