# Agent Instructions

## Build Policy

This project must not be built locally.

- Do not run local build or packaging commands such as `flutter build`, `gradle build`, `./gradlew assemble*`, `xcodebuild`, `dart compile`, or platform package/signing commands.
- Use GitHub Actions for all compile/build verification and release artifacts.
- Local non-build checks are allowed when useful, such as formatting, static analysis, tests that do not invoke a build, and file/content inspection.
- If a task requires a real build result, trigger or inspect the relevant GitHub Actions workflow instead of attempting a local build.

## GitHub Credentials

- This Windows machine may have multiple GitHub credentials configured.
- When pushing to the remote repository, explicitly use the `Eitan-S-23` GitHub identity/credential. Do not assume the default cached credential is correct.

## Cloudflare Update Release Automation

The update pipeline prepares Cloudflare release candidates automatically, but it must not auto-publish them to users.

- A normal `git push` to `main` can prepare a new Cloudflare candidate only when `pubspec.yaml` has a new version/build number, for example `1.0.13+39`.
- The workflow derives the GitHub release tag from `pubspec.yaml`, such as `v1.0.13`, builds artifacts in GitHub Actions, creates the GitHub Release, uploads APK/manifest/patch assets to Cloudflare R2, and registers a D1 release in `candidate` state.
- If the derived tag already exists, automatic candidate preparation is skipped. Do not force-replace or re-upload the same tag unless the user explicitly asks for a staging-only replacement; same-tag APK hash drift breaks incremental updates for installed clients.
- A registered candidate is not visible to clients until an operator publishes it to `stable` or `beta` through the Access-protected admin UI or the staging publish wrapper.
- Keep `TRACE_UPDATE_SERVICE_URL` as the Worker URL for CI `/api/ci/releases`; keep `TRACE_PUBLIC_UPDATE_SERVICE_URL` as the Pages URL compiled into APKs for public update checks.
- VCDIFF patches must only be generated for source clients with versionCode `41` or newer. Earlier clients contain the upstream `vcdiff_decoder` address-cache bug and must use one full APK transition before receiving VCDIFF again.
- Do not use local Flutter/Gradle builds to verify release artifacts. Inspect or trigger GitHub Actions instead.
