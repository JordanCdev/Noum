# Run: 2026-06-28 - branch:ux-overhaul - HEAD b3afd457 - coach judgement layer

## Mode
light

## Changes shipped (this run)
- `Noum/CoachReplyPipeline.swift` - builds turn depth, trajectory snapshot, rubric, typed assessment, provisional read, and depth-aware model call.
- `Noum/AICoachChatService.swift` - adds depth-aware routing/budgets plus semantic judgement quality repairs.
- `Noum/AskNoumView.swift` and `Noum/LiveCoachCallView.swift` - render immediate provisional reads without persisting pending copy.
- `NoumTests/CoachJudgementLayerTests.swift` and `NoumUITests/NoumChatFlowUITests.swift` - cover classifier, reasoning pass, semantic gate, provider routing, provisional state, and chat screenshot regression.

## Screenshots
- `01_home_top.png` - seeded Home surface.
- `01_train_top.png` - seeded Train / next rep surface.
- `01_review_top.png` - seeded Review surface.
- `01_profile_top.png` - seeded Profile surface.
- `01_settings_top.png` - seeded Settings surface.
- `ask_noum_deep_judgement_reply.png` - focused Ask Noum "How far off am I from sounding authoritative?" regression.

## VISION Gap
This work supports coach memory, personalized coaching, conversational intelligence, and believable progress. The key gap was not UI polish; it was the missing judgement layer between evidence and wording. Without that layer, deep user asks could receive generic advice, overclaim from one score, or fail to distinguish mechanics from goal readiness.

## Next Steps To Reach Desired State
1. Add true provider streaming for Ask Noum when provider SDK support is available; the current implementation ships the safe streaming-like local read.
2. Expand rubrics beyond authoritative voice once each voice has explicit goal-readiness dimensions.
3. Add an expert-eval fixture set for deep assessment and trust repair language beyond lexical semantic gates.

## Regressions Checked
- Ask Noum judgement turn - `ask_noum_deep_judgement_reply.png` - calibrated verdict rendered, no unsupported "close overall" claim.
- Home / Train / Review / Profile / Settings seeded light sweep - screenshots rendered nonblank and reachable with seeded deep links.
- Provider chain - existing default Gemini request shape preserved after restoring grounded text cap to 180.

## Surfaces Needing Visual Verification
- Live Coach provisional caption during an actual spoken deep-assessment turn was not screenshot-tested.
- True provider streaming was not implemented; visual verification covers the streaming-like provisional read path.

## For Next Run
- If cloud: continue semantic-gate fixture expansion and rubric refinement without simulator work.
- If local: capture a live-call deep-assessment caption and a detailed tour after any broader UI polish.
