# Coach Arena Synthetic 10-Conversation Sample

These are fixture-backed synthetic conversations for done-state review.

> Evidence status: STALE APP-PATH SOURCE.
> Do not treat these conversations as current-source proof until the Swift app-path dump is regenerated and rescored.
> Source freshness passes: `False`.
> Real-pipeline evidence passes: `False`.
> Report-internal source freshness passes: `False`.
> Sidecar source freshness passes: `False`.
> Current git commit: `5bef2d08`.
> Report trace git commit(s): `a556f772`.
> Current coach source fingerprint: `sha256:10bbf2c3aa86cece99f2cce118756078e594165d31e3b0d74b8e45d7ef809894`.
> Report trace coach source fingerprint(s): `sha256:d8662f3feef2bed08afc861b6d41edbfecc7c3b1471bacef2863a6a42aee5e0a`.
> Sidecar git commit: `5bef2d08`.
> Sidecar coach source fingerprint: `sha256:10bbf2c3aa86cece99f2cce118756078e594165d31e3b0d74b8e45d7ef809894`.
> Sidecar/report mismatch `sourceCoachFingerprint`: sidecar `sha256:10bbf2c3aa86cece99f2cce118756078e594165d31e3b0d74b8e45d7ef809894`, report `sha256:d8662f3feef2bed08afc861b6d41edbfecc7c3b1471bacef2863a6a42aee5e0a`.
> Sidecar/report mismatch `sourceGitCommit`: sidecar `5bef2d08`, report `a556f772`.
> Source freshness failures: `dirty coach source files after app-path dump: Noum/AICoachChatService.swift,Noum/AskNoumStore.swift,Noum/CoachContextBuilder.swift,Noum/CoachReliabilityGate.swift,Noum/CoachReplyPipeline.swift,NoumTests/CoachChatConversationEvaluationTests.swift,NoumTests/CoachChatEvaluationFixtures.swift,NoumTests/CoachJudgementLayerTests.swift,+3 more`, `source app-path git commit(s) do not match current HEAD: a556f772`.
> Production evidence failures: `2 app-path fixture(s) below local quality floor 70: filler-pressure-007,not-easy-empathy-004`, `50 real-pipeline trace(s) missing first-token source`, `source Swift app-path freshness: dirty coach source files after app-path dump: Noum/AICoachChatService.swift,Noum/AskNoumStore.swift,Noum/CoachContextBuilder.swift,Noum/CoachReliabilityGate.swift,Noum/CoachReplyPipeline.swift,NoumTests/CoachChatConversationEvaluationTests.swift,NoumTests/CoachChatEvaluationFixtures.swift,NoumTests/CoachJudgementLayerTests.swift,+3 more`, `source Swift app-path freshness: source app-path git commit(s) do not match current HEAD: a556f772`, `source Swift app-path readiness warnings: appPathFloorFailures,targetReplyMismatch`, `source Swift app-path report did not pass its app-path floor`.

## authoritative-distance-001

Evidence: `stale app-path source` - this reply is from a stale Swift app-path dump; use it as diagnostic evidence only, not current-source proof.

Goal: Sound authoritative in high-stakes updates.

Prior chat:
- none

User: How far off am I from sounding authoritative?

Noum: You are closer mechanically than you are to sounding authoritative overall. The transcript opens with a recommendation, and the latest timed rep was 7/10 with 1 filler, so the mechanics are partly landing, but goal readiness still needs repeated pressure evidence. Missing: more than one clean rep under stakes. Proof test: record a 75-second answer with the verdict in sentence one, one reason, and a clean stop.

Arena score: 87/100

## not-informative-trust-repair-002

Evidence: `stale app-path source` - this reply is from a stale Swift app-path dump; use it as diagnostic evidence only, not current-source proof.

Goal: Get useful coaching, not generic advice.

Prior chat:
- coach: Try to be clearer and communicate with confidence.

User: That's not informative at all.

Noum: Fair push: I missed the actual question and answered around the useful read. The specific read is order: warmth is arriving before the recommendation, so the point lands late. Next rep, put the recommendation first, add one reassurance, then stop.

Arena score: 71/100

## polite-however-pushback-003

Evidence: `stale app-path source` - this reply is from a stale Swift app-path dump; use it as diagnostic evidence only, not current-source proof.

Goal: Feel understood before being prescribed another drill.

Prior chat:
- coach: Run another pressure rep and reduce fillers.

User: Okay that's cool, however I still don't feel like that answers what I meant.

Noum: Fair push: that was generic advice instead of evidence, and there is friction underneath the polite pushback. The specific read is order: warmth is arriving before the recommendation, so the listener waits for the point. Next rep, put the recommendation first, add one reassurance, then stop.

Arena score: 77/100

## not-easy-empathy-004

Evidence: `stale app-path source` - this reply is from a stale Swift app-path dump; use it as diagnostic evidence only, not current-source proof.

Goal: Practice disagreement without sounding defensive.

Prior chat:
- coach: Just say the recommendation first and stop overexplaining.

User: It's not easy.

Noum: Fair push. I made the move sound easier than it feels under pressure. Your last rep gives one safe signal, I made the move sound easier than it feels under pressure, so say only the disagreement and one calm reason, then stop before defending it.

Arena score: 60/100

## repeating-yourself-005

Evidence: `stale app-path source` - this reply is from a stale Swift app-path dump; use it as diagnostic evidence only, not current-source proof.

Goal: Avoid repetitive coaching loops.

Prior chat:
- coach: Run a 60-second answer with verdict first.
- coach: Try another 60-second answer with verdict first.

User: You're repeating yourself.

Noum: Fair push: I repeated the same coaching move instead of advancing the read. Keep the close as the target, but change the proof test: compare whether the filler appears before or after the final sentence.

Arena score: 80/100

## interview-prep-006

Evidence: `stale app-path source` - this reply is from a stale Swift app-path dump; use it as diagnostic evidence only, not current-source proof.

Goal: Prepare for an interview.

Prior chat:
- none

User: How do I get better before my interview?

Noum: No baseline yet, so the honest move is one interview rep. Record 60 seconds on a likely question, then review whether the first sentence gives the point before polishing anything.

Arena score: 72/100

## filler-pressure-007

Evidence: `stale app-path source` - this reply is from a stale Swift app-path dump; use it as diagnostic evidence only, not current-source proof.

Goal: Reduce fillers when pressure rises.

Prior chat:
- none

User: How do I stop saying um under pressure?

Noum: Your last rep gives one usable signal so far, so run one answer and separate semantic words from filler words before cutting anything.

Arena score: 30/100

## leadership-update-008

Evidence: `stale app-path source` - this reply is from a stale Swift app-path dump; use it as diagnostic evidence only, not current-source proof.

Goal: Sound executive in leadership updates.

Prior chat:
- none

User: I have a leadership update tomorrow. What should I practice?

Noum: Your recent timed rep was solid on fillers but light on the close. Record a 75-second leadership update and make the final sentence the ask, not a summary.

Arena score: 74/100

## confidence-ending-009

Evidence: `stale app-path source` - this reply is from a stale Swift app-path dump; use it as diagnostic evidence only, not current-source proof.

Goal: End answers with confidence.

Prior chat:
- none

User: Why does my ending sound less confident?

Noum: The confidence leak is the extra softener after the recommendation. Your closing-strength lever is the ask: it starts sounding optional, so keep the recommendation, cut the final qualifier, and end on the ask.

Arena score: 73/100

## examples-from-sessions-010

Evidence: `stale app-path source` - this reply is from a stale Swift app-path dump; use it as diagnostic evidence only, not current-source proof.

Goal: Understand own pattern with proof.

Prior chat:
- coach: You tend to give reasons before the picture.

User: Can you give me an example of me doing this in sessions?

Noum: One example is the rep where you said 'we focused on three priorities.' The reasons were clear, but the listener had no scene to picture, so add one concrete example after the first reason next time.

Arena score: 83/100
