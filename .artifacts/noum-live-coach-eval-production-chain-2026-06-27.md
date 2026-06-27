# Noum Live Coach Eval

reportPath: /Users/jordan/Library/Developer/CoreSimulator/Devices/3D077053-2981-4C5D-819D-FF6F9BA8AD06/data/Containers/Data/Application/90228737-D016-4049-B5F0-D4C343F9B160/Documents/noum-live-coach-eval.md
fixtures: cold-start-interview-baseline,filler-pressure-prescription,markdown-tts-trust-repair
providerChain: Google Cloud (gemini-3.5-flash) -> Claude (claude-sonnet-4-6) -> DeepSeek (deepseek-chat)

## cold-start-interview-baseline

turn: How do I get better before my interview?
brain: interview-answer-first, structure-frame-the-open, structure-signposting, interview-buy-thinking-time
diagnostics:
- Google Cloud gemini-3.5-flash success: Reply accepted status=nil latencyMs=nil

reply:

Since we do not have any rated sessions or a chosen profile yet, we need a baseline to see how you handle pressure before your interview.
Record one practice rep answering a common interview question so we can measure your natural pace and filler words.

rubric: score=10 misses=
qualityIssue: nil

## filler-pressure-prescription

turn: How do I stop saying um under pressure?
brain: filler-pause-beats-filler, composure-sudden-death-one-line, filler-slow-the-open, interview-star-under-pressure
diagnostics:
- Google Cloud gemini-3.5-flash success: Reply accepted status=nil latencyMs=nil

reply:

You said um six times in your last rep because your brain was searching for the next word under pressure. The quickest test is to slow down your first sentence to give yourself thinking room, then hold one second of silence whenever you feel the next um coming. Run one quick rep now to test how that silence feels.

rubric: score=10 misses=
qualityIssue: nil

## markdown-tts-trust-repair

turn: The ** don't format and TTS reads them out. The responses feel robotic and cold, nowhere near an expert coach.
brain: conflict-non-defensive-repair, interview-buy-thinking-time, voice-warm, structure-rule-of-three
diagnostics:
- Google Cloud gemini-3.5-flash fallback: Repair reply failed professional-coach gate: unanchoredCoaching draft="You are right to call that out; those formatting symbols make the voice read sound incredibly robotic. I do not have enough data to map your baseline yet, so run one sixty-second test now with all markdown stripped out to see if the pacing feels more natural." status=nil latencyMs=nil
- Google Cloud gemini-3.5-flash fallback: Reply failed professional-coach gate: roboticPhrase("let us") draft="You are right to call that out. The formatting was getting in the way of a natural read, so I have stripped out the markdown markers entirely. Because we only have one timed rep on record, let us run a clean sixty-second test now to establish your actual baseline. Speak for one minute on a recent decision you made, and focus on holding a silent beat whenever you feel a filler word coming." status=nil latencyMs=nil
- Claude claude-sonnet-4-6 success: Repair reply accepted status=nil latencyMs=nil

reply:

Fair push — the symbols and robotic voice are real problems, and I'll drop both now. Your last rep had 4 fillers, so say the recommendation first in your next rep, give one proof point, then stop.

rubric: score=10 misses=
qualityIssue: nil