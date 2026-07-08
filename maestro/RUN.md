# Maestro Chat Demo Smoke

Run both Chat with Noum demo smoke flows against a booted iOS simulator:

```bash
bash maestro/run_chat_demo_smoke.sh
```

Optional device:

```bash
bash maestro/run_chat_demo_smoke.sh <simulator-udid>
```

The runner launches the app through `xcrun simctl launch` with the same UI-testing arguments the smoke flows expect, including `UI_TESTING_CLEAR_ASK_NOUM` so prior manual/smoke chat history cannot affect the assertions. It then executes:

- `maestro/chat_smoke.yaml` for the happy-path markdown reply demo.
- `maestro/chat_reject_smoke.yaml` for the deterministic rejection notice demo.

Set `NOUM_APP_ID` if the simulator build uses a non-default bundle identifier. The script fails fast when `maestro` is not installed or no booted simulator is available.

## Local prerequisites

Use the official mobile UI-testing Maestro CLI, not the unrelated Homebrew cask named `maestro`:

```bash
brew tap mobile-dev-inc/tap
brew install mobile-dev-inc/tap/maestro
```

Maestro also requires Java 17+. The runner automatically uses Homebrew's keg-only OpenJDK 17 when it exists at `/opt/homebrew/opt/openjdk@17`; otherwise install it:

```bash
brew install openjdk@17
```

Before running the smoke script, boot a simulator and install a Debug simulator build of Noum:

```bash
xcrun simctl boot <simulator-udid>
xcrun simctl install <simulator-udid> DerivedData/Noum/Build/Products/Debug-iphonesimulator/Noum.app
bash maestro/run_chat_demo_smoke.sh <simulator-udid>
```

Verified locally on 2026-07-08 with Maestro CLI `2.6.1`, OpenJDK `17.0.19`, and iPhone 17 / iOS 26.4 simulator:

- `maestro/chat_smoke.yaml`
- `maestro/chat_reject_smoke.yaml`
