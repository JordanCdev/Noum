# UX hardening handoff

Captured on an iPhone 17 Pro simulator running iOS 26.5. These screenshots are
from the deterministic `ScreenshotTour` UI-test seed and were visually reviewed
after export from the passing result bundle.

## Product changes represented

- **Path:** one open visual corridor, opaque separated trees, a calm waypoint
  instead of footsteps, shorter copy, and distinct Reason / Landmark sections.
- **Train:** the coach-built rep is the default decision; the full exercise
  library is behind the optional **Choose for myself** disclosure.
- **Coaching evidence:** current focus and next move come first; supporting
  rationale and progress records are disclosure sections.
- **Weekly check-in:** a pushed screen with a normal back button and a single
  disabled-until-valid save action. The screen states where the answer is saved
  and where it can be reviewed, edited, or deleted.
- **Milestones:** one neutral card system describes consistent work rather than
  mixing badges, shields, score celebrations, and game-like unlock screens.
- **Post-rep:** Results opens directly. Progress is a compact inline receipt
  inside the coaching read instead of a chain of full-screen animations.

## Files

- `path-top.png`, `path-bottom.png`
- `train-plan.png`, `train-free-select.png`
- `evidence-overview.png`, `evidence-expanded.png`
- `weekly-check-in.png`
- `milestones.png`
- `summary-top.png`, `summary-progress.png`, `summary-bottom.png`
- `summary-*-ax.txt` accessibility-tree captures

## Review notes

- The short gray line at the physical bottom edge is the iOS home indicator,
  not an app-owned divider or overlay. It remains visible by platform design.
- PDF export was deliberately deferred. The evidence screen is now readable
  and progressively disclosed; export should only be added with a defined
  privacy, redaction, and sharing contract.
- The application currently forces light appearance, so this pass does not
  claim dark-mode support.

## Verification

- Screenshot UI tests: 4 passed, 0 failed.
- Accessibility XXXL native audits for Train, Profile, and the expanded Profile
  library: 3 passed, 0 failed.
- Full serialized unit suite: 4,550 passed, 0 failed.
- Coach Arena fixture validation: 52 fixtures, 0 errors, 0 warnings; 11
  multi-turn conversations generated and gradeable.
- Offline replay covers all 63 cases and remains **NO-GO** because the 69.6
  mean is below the 70 target and older replay responses still miss the
  current fixture floor and placeholder-leak requirements.
