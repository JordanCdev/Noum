# Noum Live Coach Eval

reportPath: /Users/jordan/Library/Developer/CoreSimulator/Devices/3D077053-2981-4C5D-819D-FF6F9BA8AD06/data/Containers/Data/Application/8A8AD9EB-FB67-44FF-AD8E-C6B7B494031D/Documents/noum-live-coach-eval.md
fixtures: cold-start-interview-baseline,filler-pressure-prescription,markdown-tts-trust-repair
providerChain: Google Cloud (gemini-3.5-flash)

## cold-start-interview-baseline

turn: How do I get better before my interview?
brain: interview-answer-first, structure-frame-the-open, structure-signposting, interview-buy-thinking-time
diagnostics:
- Google Cloud gemini-3.5-flash success: Reply accepted status=nil latencyMs=nil

reply:

We do not have any rated sessions or a chosen profile for you yet, so the first step is to run a baseline rep to see how you pace your answers under pressure.
Record a sixty-second practice answer about your background because that will show us your natural starting point with filler words and structure.

rubric: score=10 misses=
qualityIssue: nil

## filler-pressure-prescription

turn: How do I stop saying um under pressure?
brain: filler-pause-beats-filler, composure-sudden-death-one-line, filler-slow-the-open, interview-star-under-pressure
diagnostics:
- Google Cloud gemini-3.5-flash success: Repair reply accepted status=nil latencyMs=nil

reply:

Your last rep had six fillers because your brain was searching for the next word under pressure.
Test a silent beat instead of filling that gap, so you give yourself room to find the next sentence in silence. Run one rep now and hold one second of silence every time you feel an um coming.

rubric: score=10 misses=
qualityIssue: nil

## markdown-tts-trust-repair

turn: The ** don't format and TTS reads them out. The responses feel robotic and cold, nowhere near an expert coach.
brain: conflict-non-defensive-repair, interview-buy-thinking-time, voice-warm, structure-rule-of-three
diagnostics:
- Google Cloud gemini-3.5-flash success: Repair reply accepted status=nil latencyMs=nil

reply:

You are right to call that out, and I will strip away the markdown symbols and the robotic report style to keep this direct. Your last rep had four fillers in fifty-two seconds, so run a new rep where you say your recommendation in the very first sentence and then hold a silent beat.

rubric: score=10 misses=
qualityIssue: nil