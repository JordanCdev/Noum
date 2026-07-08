# Maestro Chat Demo Smoke

Run both Chat with Noum demo smoke flows against a booted iOS simulator:

```bash
bash maestro/run_chat_demo_smoke.sh
```

Optional device:

```bash
bash maestro/run_chat_demo_smoke.sh <simulator-udid>
```

The runner launches the app through `xcrun simctl launch` with the same UI-testing arguments the smoke flows expect, then executes:

- `maestro/chat_smoke.yaml` for the happy-path markdown reply demo.
- `maestro/chat_reject_smoke.yaml` for the deterministic rejection notice demo.

Set `NOUM_APP_ID` if the simulator build uses a non-default bundle identifier. The script fails fast when `maestro` is not installed or no booted simulator is available.
