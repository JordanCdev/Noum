# Noum Live Coach Eval

reportPath: /Users/jordan/Library/Developer/CoreSimulator/Devices/3D077053-2981-4C5D-819D-FF6F9BA8AD06/data/Containers/Data/Application/0D46EA15-4B44-4B6C-95FB-C96302020160/Documents/noum-live-coach-eval.md
fixtures: cold-start-interview-baseline,filler-pressure-prescription,markdown-tts-trust-repair
providerChain: Google Cloud (gemini-3.5-flash) -> Claude (claude-sonnet-4-6) -> DeepSeek (deepseek-chat)

## cold-start-interview-baseline

turn: How do I get better before my interview?
brain: interview-answer-first, structure-frame-the-open, structure-signposting, interview-buy-thinking-time
diagnostics:
- Google Cloud gemini-3.5-flash success: Reply accepted status=nil latencyMs=nil

reply:

Since we do not have any rated sessions yet, we need a baseline of your natural style so we can target the exact habits that might hold you back in the interview.
Record a sixty-second practice rep answering the question "Why do you want this role?" so we can look at your pacing and how you structure your opening.

rubric: score=10 misses=
qualityIssue: nil

## filler-pressure-prescription

turn: How do I stop saying um under pressure?
brain: filler-pause-beats-filler, composure-sudden-death-one-line, interview-star-under-pressure, filler-anchor-word
diagnostics:
- Google Cloud gemini-3.5-flash success: Repair reply accepted status=nil latencyMs=nil

reply:

Your last rep had 6 fillers, so the move is to replace the next um with one second of silence because that brief pause gives your mind a moment to lock in the next word.
On your next rep, hold a silent beat whenever you feel an um coming, then speak.

rubric: score=10 misses=
qualityIssue: nil

## markdown-tts-trust-repair

turn: The ** don't format and TTS reads them out. The responses feel robotic and cold, nowhere near an expert coach.
brain: conflict-non-defensive-repair, interview-buy-thinking-time, voice-warm, structure-rule-of-three
diagnostics:
- Google Cloud gemini-3.5-flash success: Repair reply accepted status=nil latencyMs=nil

reply:

You are right to call that out, as those markdown symbols make the text-to-speech sound incredibly robotic and cold. Your last rep had four fillers, so run a new sixty-second test with no symbols in my response and hold a silent beat whenever you need to think.

rubric: score=10 misses=
qualityIssue: nil