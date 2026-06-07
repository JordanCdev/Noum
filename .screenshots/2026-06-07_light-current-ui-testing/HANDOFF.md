# Run: 2026-06-07 · branch:ux-overhaul · current-light-screenshots + Figma setup

## Mode
`light`

Screenshot mode was turned on in both `.agents/skills/noum-screenshots/.mode` and `.claude/skills/noum-screenshots/.mode`.

## Changes Shipped (This Run)
- `.agents/skills/noum-screenshots/capture.sh` and `.claude/skills/noum-screenshots/capture.sh` now launch with `UI_TESTING -DeepLink ...` so fresh simulators bypass onboarding and land on actual tab surfaces.
- Created Figma design file: https://www.figma.com/design/3QVzLSmhDNcPcbj8hCLSll (`Noum UX Overhaul Review - Current vs Proposed`).

## Screenshots
- `01_train_top.png` — stale installed app capture before reinstall; useful only as evidence that a non-fresh install can show old picker copy.
- `02_train_after_install.png` — fresh build, real Train picker after the prescription-line pass.
- `.screenshots/2026-06-07_autostop-de8ee0d-2331/` — fixed light capture with Home / Train / Review / Profile / Settings tab tops.

## Figma Status
Figma file creation succeeded under Jordan's team. Uploading the current screenshots was blocked by the Figma Starter-plan MCP call limit immediately after file creation.

## VISION Gap
Train is closer to one prescribed rep, but still not final: large lower dead space remains, and the current prescription line needs better hierarchy. The broader Iteration 5 curriculum-spine work is still open.

## Next Steps
1. When Figma MCP allowance resets, upload the fixed light screenshots into the Figma file as the "Current" column.
2. Build proposed Train/Profile/Settings frames beside them before coding the next major UI pass.
3. Use `02_train_after_install.png` as the immediate Train baseline, not the stale `01_train_top.png`.
