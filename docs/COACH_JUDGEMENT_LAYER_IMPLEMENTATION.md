# Coach Judgement Layer Implementation

This change adds a low-latency judgement pass between evidence retrieval and model wording for Ask Noum and Live Coach.

## What Changed

- `TurnDepthClassifier` deterministically classifies turns as quick move, grounded read, deep assessment, or trust repair.
- `UserTrajectoryCache` builds compact transient snapshots from existing profile, baseline, rating, session, and coach-memory owners.
- `GoalRubricStore` provides the active coaching rubric, starting with the authoritative voice rubric.
- `CoachReasoningPass` produces a typed `CoachAssessment` with a direct verdict, evidence, missing evidence, rubric scores, and one proof test.
- `CoachPromptBundle` injects the typed judgement pass into the existing coach context and routes model tier/budget by depth.
- Ask Noum and Live Coach can show an immediate provisional coach read while the full model reply is prepared.
- `AICoachChatService` adds a semantic quality gate for deep assessment and trust repair replies.

## Guardrails

- Thin evidence must produce softer claims and explicit missing-evidence language.
- A single strong score cannot become "close overall" without repeated and pressure-tested evidence.
- Mechanics, score, and goal readiness must remain distinct in deep assessment replies.
- Trust repair routes to the reasoning tier and must acknowledge the miss before repairing the answer.

## Verification

- Added focused unit coverage in `CoachJudgementLayerTests`.
- Added a UI screenshot regression for "How far off am I from sounding authoritative?"
- Re-ran the existing `CoachProviderChainTests` to preserve default provider request shape and token caps.
