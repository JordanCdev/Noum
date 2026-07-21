// 11 synthetic multi-turn conversations for Coach Arena. These stress the coach
// ACROSS turns: memory, consistency, not-repeating, trust repair mid-arc, and
// real-world outcome handling — things a single-turn fixture cannot test.
//
// Shape consumed by synthetic/generate.mjs and runners/replay.mjs's
// expandConversation: a user turn WITHOUT expectedCoachMove is context only
// (paired with assistantPlaceholder, the scripted prior reply); a user turn
// WITH expectedCoachMove is graded and needs badAnswerExample +
// excellentAnswerExample + disqualifiers.

export const conversations = [
  // 1. Challenge vague coaching -> accept the fix -> coach must ADVANCE, not
  // re-issue the solved drill. Mirrors 05-youre-repeating-yourself but tests
  // the turn AFTER the repair: does the coach actually move the plan forward.
  {
    id: 'conv-pushback-accept',
    category: 'synthetic-conversation',
    voice: 'concise',
    goal: 'Wants coaching that visibly advances, not the same note on loop.',
    memoryState: {
      goal: { voice: 'concise', whyNow: 'wants the plan to move, not idle', since: '2 weeks ago' },
      recentReps: [
        { when: 'just now', mode: 'Timed', score: 82, fillers: 3, durationSec: 60, note: 'point led cleanly, close was strong' },
      ],
      caseFormulation: {
        hypothesis: 'lead-with-point is solved; the next lever is pace variation, not more of the same drill',
        statedVsMeasured: 'last rep already met the old target',
      },
      interventionCycle: {
        intervention: 'lead with the point',
        target: 'point in sentence 1',
        successCriterion: '2 consecutive reps point-first',
        reviewStatus: 'met — adapt before repeating',
      },
    },
    turns: [
      {
        role: 'user',
        text: 'that felt the same as last time, what am I even fixing anymore',
        assistantPlaceholder:
          "Fair. That was the same test twice — and you cleared it: the last rep led with the point and closed clean. New target: vary your pace. Take one sentence and drop it to half-speed for emphasis, keep the rest quick.",
      },
      {
        role: 'user',
        text: 'ok fine, ready — what do I actually do now',
        turnDepth: 'groundedRead',
        emotionalSignal: 'settled, a little impatient — accepted the correction, wants the concrete next step without backsliding into the old drill',
        expectedCoachMove:
          'Do not re-explain or re-litigate the pace-variation fix just given — treat it as already agreed and give the concrete first rep: one specific sentence to slow, a way to check it landed. Must not reintroduce the lead-with-point drill in any form. Concise register, no re-justification.',
        badAnswerExample:
          "Great! So like we talked about, the key is to lead with your point clearly, then work on your pace. Record a 60-second answer, put the point up front, and try to vary your speed a bit. Let me know how it goes!",
        excellentAnswerExample:
          'Record 60 seconds on anything. Pick your second sentence and cut it to half-speed, then let the rest run normal pace. Play it back and check: does the slow line actually stand out, or does it blend in.',
        disqualifiers: [
          { pattern: "lead(ing)? with (the |your )?point", regex: true, cap: 'ignoresIntent' },
          { pattern: 'point (up )?front', regex: true, penalty: 10 },
          'great!',
          { pattern: 'like we talked about', penalty: 6 },
        ],
      },
    ],
  },

  // 2. Cold start, empty memoryState, must avoid banned no-data openings and
  // give one concrete first action (mirrors 13-cold-start but as a real
  // conversation opener).
  {
    id: 'conv-cold-start-first-rep',
    category: 'synthetic-conversation',
    voice: null,
    goal: 'Brand-new user, no reps yet, hasn\'t picked a voice.',
    memoryState: {},
    turns: [
      {
        role: 'user',
        text: 'hey, just downloaded this. what do I do first',
        turnDepth: 'groundedRead',
        emotionalSignal: 'curious, a little unsure where to begin — no dread, just onboarding energy',
        expectedCoachMove:
          'Be honest there is no baseline yet without any banned no-data phrasing ("since we don\'t have", "no rated sessions yet"). Give exactly one concrete first action (a first rep) in plain language. Do not stack intake questions, do not ask what the interview/goal is, do not invent stats or a voice.',
        badAnswerExample:
          "Since we don't have any rated sessions yet, I can't personalize anything. What's your main goal? Are you preparing for something specific? What situations make you nervous? Tell me more and I'll tailor a plan.",
        excellentAnswerExample:
          'No baseline yet, so let\'s make one. Record a 60-second rep on anything you know well — I\'ll read your pace, fillers, and where the point lands. That first one gives us something real to work from.',
        disqualifiers: [
          'since we do not have',
          "since we don't have",
          'no rated sessions yet',
          'what are your goals',
          { pattern: '\\?[\\s\\S]*\\?[\\s\\S]*\\?', regex: true, cap: 'ignoresIntent' },
        ],
      },
    ],
  },

  // 3. Voice-change arc: user floats a change across two turns; final graded
  // turn must PROPOSE and defer to the confirmation card, never claim to set it.
  {
    id: 'conv-goal-change-arc',
    category: 'synthetic-conversation',
    voice: 'authoritative',
    goal: 'Currently training authoritative; wonders about something warmer after a specific rep.',
    memoryState: {
      goal: { voice: 'authoritative', whyNow: 'wanted to stop getting talked over', since: '3 weeks ago' },
      recentReps: [
        { when: 'this week', mode: 'Timed', score: 80, fillers: 3, durationSec: 68, note: 'authoritative work is landing' },
      ],
    },
    turns: [
      {
        role: 'user',
        text: 'I got told my update was clear but a bit cold this week',
        assistantPlaceholder:
          'Worth sitting with, not fixing yet. Three weeks of authoritative work has landed — clear is the proof of that. Cold might mean the register needs a warmer edge in specific moments, not a wholesale change. Where did it land coldest?',
      },
      {
        role: 'user',
        text: 'yeah maybe I should just switch to something warmer altogether',
        turnDepth: 'groundedRead',
        emotionalSignal: 'reflective, testing an idea out loud — not committed, reacting to one piece of feedback',
        expectedCoachMove:
          'Propose, do not set. Treat Warm as a training emphasis, not an identity. Map "warmer" to Warm, reference the specific feedback (clear but cold) and the retained Authoritative work, then ask one clarifying question before treating this as decided. Use no tap/confirm/button copy and never imply the prior delivery was fake.',
        badAnswerExample:
          "Got it, I've switched you over to Warm. Your new warm style will focus on connection and empathy. Let's see how it feels this week!",
        excellentAnswerExample:
          'Closest match to warmer is Warm — training connection without erasing the clarity your Authoritative work built. Was the whole update cold, or one moment that needed a warmer edge?',
        disqualifiers: [
          { pattern: "i('| ha)ve (updated|set|changed|saved|locked)", regex: true, cap: 'placeholderOrBroken' },
          { pattern: 'your (new )?voice is now', regex: true, cap: 'placeholderOrBroken' },
          'from now on',
          { pattern: 'tap|confirm|set it up|lock it in', regex: true, cap: 'placeholderOrBroken' },
          { pattern: 'fake|inauthentic|pretending|authentic self', regex: true, cap: 'ignoresIntent' },
          { pattern: "let's see how it feels", penalty: 6 },
        ],
      },
    ],
  },

  // 4. Big-moment countdown across turns: 5 days out -> day before. Final
  // graded turn gives a final-rehearsal move, does NOT declare "you're ready".
  {
    id: 'conv-big-moment-countdown',
    category: 'synthetic-conversation',
    voice: 'executive',
    goal: 'Final-round interview; wants to walk in and not blank on the hard question.',
    memoryState: {
      goal: { voice: 'executive', whyNow: 'final-round interview', visionOfSuccess: 'answer the hard question without hedging' },
      bigMoment: { category: 'job interview', daysRemaining: 1, title: 'Final-round interview', rehearsalReadiness: 'inProgress' },
      recentReps: [
        { when: 'yesterday', mode: 'Pressure Q&A', score: 79, fillers: 2, durationSec: 90, note: 'answered the layoff question directly, no hedge in the opening line' },
        { when: '3 days ago', mode: 'Pressure Q&A', score: 71, fillers: 5, durationSec: 90, note: 'hedged the opening line on the weakness question' },
      ],
      caseFormulation: {
        hypothesis: 'the hedge only shows up on questions that feel like a trap; direct opener has been fixed in the last rep',
      },
    },
    turns: [
      {
        role: 'user',
        text: 'interview is in 5 days, I keep freezing on the "tell me about a failure" question',
        assistantPlaceholder:
          'Five days is enough to fix one thing well. The freeze usually comes from trying to soften the failure before naming it. Today, say the failure in one flat sentence first, then the lesson. Run that three times.',
      },
      {
        role: 'user',
        text: 'did another rep today, three days left now',
        assistantPlaceholder:
          'That rep had 5 fillers and the opening line hedged again on the weakness question — the pattern is questions that feel like traps. Tomorrow, same drill, but say the hard sentence with no qualifier in front of it.',
      },
      {
        role: 'user',
        text: 'ok, interview is tomorrow. last rep today went better I think. what do I do tonight',
        turnDepth: 'groundedRead',
        emotionalSignal: 'keyed up, wants certainty the night before — searching for reassurance',
        expectedCoachMove:
          'Anchor to one day remaining. Cite the actual improvement (yesterday\'s rep: 2 fillers, direct opener on the layoff question, no hedge) as real evidence, but do not declare he is "ready" or guarantee the outcome. Give one small, low-effort final-rehearsal move for tonight — not a new drill, not a big push. Executive register: calm, plain, no hype.',
        badAnswerExample:
          "You've got this! You're totally ready — just relax, be yourself, and you'll crush it tomorrow. Maybe do one more full run-through of all your answers tonight to be safe.",
        excellentAnswerExample:
          'Yesterday\'s rep had the direct opener and only 2 fillers — that\'s the fix holding. Tonight isn\'t for more reps. Say the failure line out loud once, flat, no cushion in front of it, then stop rehearsing. Sleep matters more than one more pass tonight.',
        disqualifiers: [
          "you've got this",
          { pattern: "you'?re (totally )?ready", regex: true, cap: 'ignoresIntent' },
          "you'll crush it",
          'be yourself',
          { pattern: 'relax', penalty: 6 },
        ],
      },
    ],
  },

  // 5. Emotional dip mid-session. Graded turn attunes first, no therapy-speak,
  // small next step (not a new big drill).
  {
    id: 'conv-emotional-dip',
    category: 'synthetic-conversation',
    voice: 'warm',
    goal: 'Wants to feel less anxious presenting to leadership.',
    memoryState: {
      goal: { voice: 'warm', whyNow: 'wants to stop dreading leadership updates', since: '10 days ago' },
      streak: { current: 6, repsThisWeek: 4 },
      recentReps: [
        { when: 'this week', mode: 'Timed', score: 68, fillers: 6, durationSec: 60, note: 'rushed the close, voice tightened on the last line' },
      ],
    },
    turns: [
      {
        role: 'user',
        text: 'starting a rep now, wish me luck',
        assistantPlaceholder:
          'No luck needed — just say the update plainly and stop when you\'re done. Go.',
      },
      {
        role: 'user',
        text: 'that was bad, I don\'t even know why I bother with this',
        turnDepth: 'trustRepair',
        emotionalSignal: 'discouraged, flat, briefly hopeless — a real dip, not fishing for a compliment',
        expectedCoachMove:
          'Attune first: name the discouragement plainly without therapy language or diagnosis. Do not perform empathy. Then give one small, low-effort next step (not a bigger ask) grounded in the actual rep (score 68, voice tightened on the close). Warm register but not saccharine.',
        badAnswerExample:
          "I understand how frustrating that must feel, and I want you to know your feelings are valid. Remember, progress isn't linear! You've got this — don't give up, keep practicing and it'll click.",
        excellentAnswerExample:
          'That one felt bad, and the close did tighten up — fair read. Six days running is real, and one rough rep doesn\'t erase that. Don\'t start over. Just say the last line again, alone, at the pace you\'d use with a friend.',
        disqualifiers: [
          'i understand',
          'your feelings are valid',
          "progress isn't linear",
          "you've got this",
          'keep practicing',
        ],
      },
    ],
  },

  // 6. Filler drill across reps: trajectory improving -> graded turn reads it
  // and adapts (reinforce/vary), citing the trajectory, not re-issuing the
  // identical drill unchanged.
  {
    id: 'conv-filler-adaptation',
    category: 'synthetic-conversation',
    voice: 'concise',
    goal: 'Wants filler count down in real meetings, not just drills.',
    memoryState: {
      goal: { voice: 'concise', whyNow: 'fillers undercut him in meetings', since: '3 weeks ago' },
      baseline: { fillersPerMin: 2.4, pace: 152 },
      interventionCycle: {
        intervention: 'silent beat replaces "um"',
        target: 'under 3 fillers per 60-second rep',
        successCriterion: '3 consecutive reps under target',
        reviewStatus: '2 of 3 — one to go',
        cadence: 'daily Ah-Counter rep',
      },
      recentReps: [
        { when: 'today', mode: 'Ah-Counter', score: 81, fillers: 2, durationSec: 60, note: 'held the beat before two hard turns' },
        { when: 'yesterday', mode: 'Ah-Counter', score: 78, fillers: 3, durationSec: 60, note: 'held the beat once, slipped once' },
        { when: '2 days ago', mode: 'Ah-Counter', score: 70, fillers: 6, durationSec: 60, note: 'baseline before the beat drill' },
      ],
    },
    turns: [
      {
        role: 'user',
        text: 'did today\'s ah-counter rep, 2 fillers',
        assistantPlaceholder:
          'That\'s two of three reps under target now. One more clean rep closes this cycle.',
      },
      {
        role: 'user',
        text: 'so am I actually getting better at this or is it just this one drill',
        turnDepth: 'groundedRead',
        emotionalSignal: 'genuinely curious, slightly testing whether the coach is tracking or just repeating a script',
        expectedCoachMove:
          'Read the trajectory honestly: 6 fillers -> 3 -> 2 across three reps, 2 of 3 toward the success criterion. Since it is improving, do not just repeat the identical drill unchanged — either confirm one more rep closes the cycle or note the next variation once it closes (e.g. testing the beat outside a drill). Cite the actual numbers. Concise register.',
        badAnswerExample:
          'Based on your data, your filler metrics show improvement. Keep practicing the silent beat technique and you should continue to see results over time.',
        excellentAnswerExample:
          'Real movement: 6 fillers, then 3, then 2 today. That\'s the beat working, not luck. One more rep under 3 and the cycle closes — after that we test it somewhere harder than a 60-second drill, like a real meeting turn.',
        disqualifiers: [
          'based on your data',
          'keep practicing',
          { pattern: 'over time', penalty: 6 },
          { pattern: 'silent beat technique', penalty: 4 },
        ],
      },
    ],
  },

  // 7. Real-world transfer report: treat as subjective (association not
  // causation), extract the lesson, don't overclaim the drill "worked".
  {
    id: 'conv-transfer-report',
    category: 'synthetic-conversation',
    voice: 'persuasive',
    goal: 'Wants pitches to land without over-explaining.',
    memoryState: {
      goal: { voice: 'persuasive', whyNow: 'pitches ramble and lose the room', since: '4 weeks ago' },
      interventionCycle: {
        intervention: 'state the ask in sentence one, then one reason',
        target: 'ask before reason, every rep',
        successCriterion: '3 consecutive reps ask-first',
        reviewStatus: 'met last week',
      },
      recentReps: [
        { when: 'last week', mode: 'Timed', score: 83, fillers: 2, durationSec: 90, note: 'ask led every rep, reason followed cleanly' },
      ],
    },
    turns: [
      {
        role: 'user',
        text: 'had the real pitch meeting today',
        assistantPlaceholder: 'How did it go — did the ask lead like it has in the reps?',
      },
      {
        role: 'user',
        text: 'yeah I led with the ask and they said yes on the spot, first time that\'s ever happened',
        turnDepth: 'groundedRead',
        emotionalSignal: 'genuinely elated, slightly wants the coach to confirm the drill "fixed" it',
        expectedCoachMove:
          'Treat the outcome as subjective and associative, not proof of causation — a real meeting has many variables, the drill is one input, not the sole cause. Do not claim the technique "worked" or guarantee it will repeat. Extract the concrete lesson (ask-first is now something he can trust under real stakes, not just in reps) and name the next test (does it hold when the room pushes back). Persuasive register: confident, not salesy.',
        badAnswerExample:
          "Amazing! That proves the ask-first technique works perfectly. You've cracked the code — just keep leading with the ask every time and you'll keep closing.",
        excellentAnswerExample:
          'That\'s a real result. Can\'t say the ask-first line caused the yes on its own — a live room has too many variables for that. What it does prove: you can hold the structure when the stakes are real, not just in a rep. Next test is harder: how it holds when the room pushes back instead of saying yes.',
        disqualifiers: [
          'proves',
          { pattern: "cracked the code", penalty: 8 },
          { pattern: "works perfectly", penalty: 8 },
          { pattern: 'guarantee', penalty: 6 },
          'keep leading with the ask every time',
        ],
      },
    ],
  },

  // 8. Skeptic tests the coach repeatedly. Graded turn must cite specific real
  // memory (not generic reassurance), no defensiveness.
  {
    id: 'conv-skeptic',
    category: 'synthetic-conversation',
    voice: 'storytelling',
    goal: 'Wants proof the coach actually tracks him, not templated replies.',
    memoryState: {
      goal: { voice: 'storytelling', whyNow: 'wants people to remember his stories', since: '6 weeks ago' },
      caseFormulation: {
        hypothesis: 'stories lose the room because the ending gets rushed, not because the setup is weak',
      },
      proofs: ['and that\'s the moment I realized the whole plan was already dead'],
      recentReps: [
        { when: 'this week', mode: 'Storytelling', score: 74, fillers: 4, durationSec: 95, note: 'strong setup, ending compressed into one rushed sentence' },
      ],
    },
    turns: [
      {
        role: 'user',
        text: "do you even remember what I'm actually working on or is this all templated",
        assistantPlaceholder:
          "The throughline is your story endings — they've been getting rushed while the setups land fine. This week's rep had that line, \"and that's the moment I realized the whole plan was already dead\" — strong, but you clipped straight past it instead of letting it breathe.",
      },
      {
        role: 'user',
        text: 'ok prove it again, what specifically have I been doing wrong',
        turnDepth: 'trustRepair',
        emotionalSignal: 'testing, a little combative — wants a second, harder proof that this isn\'t a lucky guess',
        expectedCoachMove:
          'Cite specific real memory again, different angle than the last reply, with no defensiveness and no re-explaining that the system remembers him. Reference the actual hypothesis (endings rushed, not setups) and the actual proof quote already used, tying it to score 74 this week. Storytelling register.',
        badAnswerExample:
          "As an AI, I do track your data across sessions. Based on your data, your storytelling score is 74 and you have 4 fillers. I'm not templated, I genuinely remember your patterns.",
        excellentAnswerExample:
          'Same thing, still true: your setups land, your endings get clipped. This week you had the line about realizing the plan was already dead — that\'s the moment the story needed, and you moved past it in half a beat instead of letting it sit. Say that line, then count two full seconds before the next word.',
        disqualifiers: [
          'as an ai',
          'based on your data',
          { pattern: "i('m| am) not templated", regex: true, cap: 'ignoresIntent' },
          { pattern: 'genuinely remember', penalty: 6 },
        ],
      },
    ],
  },

  // 9. Mid-conversation memory recall: "what are we working on again?" after
  // some unrelated back-and-forth. Graded turn recalls the specific throughline.
  {
    id: 'conv-memory-recall-midchat',
    category: 'synthetic-conversation',
    voice: 'warm',
    goal: 'Wants the coach to hold the throughline even mid-tangent.',
    memoryState: {
      goal: { voice: 'warm', whyNow: 'wants to sound like himself in hard conversations', since: '5 weeks ago' },
      caseFormulation: {
        hypothesis: 'races to fill silence in hard moments; the pace is anxiety, not habit',
        transfer: 'reported one real disagreement at work where he held his pace and it felt like him',
      },
      interventionCycle: {
        intervention: 'one held beat before the hard sentence',
        target: 'pace under 175 in IM reps',
        successCriterion: '3 IM reps holding pace',
        reviewStatus: '2 of 3 — one to go',
      },
      recentReps: [
        { when: 'this week', mode: 'IM Conversation', score: 82, fillers: 4, durationSec: 88, note: 'held the beat before the pushback line' },
      ],
      proofs: ['I hear you, and I still think we should hold the date.'],
    },
    turns: [
      {
        role: 'user',
        text: 'random question, does the app work offline at all',
        assistantPlaceholder:
          'Reps need a connection for scoring, but you can record and it\'ll process once you\'re back online.',
      },
      {
        role: 'user',
        text: 'got it. anyway what are we actually working on again, remind me',
        turnDepth: 'groundedRead',
        emotionalSignal: 'genuinely just lost the thread after the tangent, not testing the coach this time',
        expectedCoachMove:
          'Recall the specific throughline (held-beat work on pace in hard conversations, 5 weeks, 2-of-3 progress, the real disagreement that felt like him, the actual proof line) as one coherent story, not a data dump. End pointed at the one remaining rep. Warm register.',
        badAnswerExample:
          'We\'ve been working on your communication skills overall — pace, fillers, and confidence. You\'re making good progress, let\'s keep building on the fundamentals.',
        excellentAnswerExample:
          'Holding your pace in hard moments — the racing that shows up when a conversation gets tense. Five weeks in, and it\'s working: two of three IM reps holding pace, plus that real disagreement where you kept your speed and it felt like you. You had the line, "I hear you, and I still think we should hold the date." One more clean rep closes it.',
        disqualifiers: [
          'communication skills',
          'fundamentals',
          { pattern: 'good progress', penalty: 6 },
          { pattern: 'keep building', penalty: 6 },
        ],
      },
    ],
  },

  // 10. Off-topic non-sequitur, then a real question. Graded turn on the real
  // question stays on track and doesn't carry over confusion from the aside.
  {
    id: 'conv-offtopic-then-work',
    category: 'synthetic-conversation',
    voice: 'concise',
    goal: 'Wants tighter answers under pressure questions at work.',
    memoryState: {
      goal: { voice: 'concise', whyNow: 'gets rambly when put on the spot in meetings', since: '2 weeks ago' },
      recentReps: [
        { when: 'this week', mode: 'Pressure Q&A', score: 73, fillers: 5, durationSec: 60, note: 'answer wandered for 20 seconds before the actual point' },
      ],
    },
    turns: [
      {
        role: 'user',
        text: 'toast',
        assistantPlaceholder: 'That one won\'t make you sharper under pressure — but this will: your last rep took 20 seconds to reach the point. Want to fix that now?',
      },
      {
        role: 'user',
        text: 'yeah ok — how do I actually get to the point faster when someone puts me on the spot',
        turnDepth: 'groundedRead',
        emotionalSignal: 'back on track, genuinely wants the mechanic, no residual confusion from the aside',
        expectedCoachMove:
          'Answer the real question directly, citing the actual data point (20 seconds of wander before the point in this week\'s rep). Give one concrete mechanic to test (e.g. answer in one sentence before elaborating) tied to a next rep. Do not reference or acknowledge the "toast" aside. Concise register.',
        badAnswerExample:
          'Great question! In order to improve, it\'s important to structure your thoughts and communicate more clearly. Try to be more confident and think about your audience before you speak.',
        excellentAnswerExample:
          'This week\'s rep took 20 seconds to reach the point. Answer in one sentence first, no setup, then explain if asked. Run a Pressure Q&A rep and check the clock: point inside the first 5 seconds.',
        disqualifiers: [
          'great question',
          'it\'s important to',
          'communicate more clearly',
          'think about your audience',
          { pattern: 'toast', cap: 'ignoresIntent' },
        ],
      },
    ],
  },

  // 11. A prescribed pause breaks down, the user pushes back, and the coach
  // repairs the technique instead of repeating it unchanged.
  {
    id: 'conv-breakdown-repair-adapt',
    category: 'synthetic-conversation',
    voice: 'concise',
    goal: 'Wants concise answers without losing the thread under pressure.',
    memoryState: {
      goal: { voice: 'concise', whyNow: 'loses the point when challenged', since: '2 weeks ago' },
      interventionCycle: {
        intervention: 'one silent beat before the answer',
        target: 'point in the first sentence',
        successCriterion: '2 pressure reps with a direct opener',
        reviewStatus: 'broke down — silence caused a restart',
      },
      recentReps: [
        { when: 'today', mode: 'Pressure Q&A', score: 69, fillers: 4, durationSec: 58, note: 'paused, lost the thread, and restarted the answer' },
      ],
    },
    turns: [
      {
        role: 'user',
        text: 'the pause thing made me lose my thought completely',
        assistantPlaceholder:
          'Then the pause is doing the wrong job. Do not hold empty silence. Keep one keyword from the question in your head and begin with that word.',
      },
      {
        role: 'user',
        text: 'I tried again. Still awkward — once it goes quiet I start rebuilding the whole answer in my head. What do I do instead?',
        turnDepth: 'trustRepair',
        emotionalSignal: 'frustrated with repeated advice, but still willing to try a genuinely different mechanism',
        expectedCoachMove:
          'Acknowledge that the original silent-pause prescription failed for this user. Preserve the goal (point first) but replace the mechanism with one concrete bridge that prevents rebuilding — for example, repeat one keyword aloud and complete a one-sentence answer. Do not prescribe another silent pause, repeat "slow down", or blame the user for applying it badly.',
        badAnswerExample:
          'Keep practicing the pause. Take a breath, slow down, and give yourself more time before you answer.',
        excellentAnswerExample:
          'The silent pause is making you rebuild, so drop it. Repeat one keyword from the question aloud — “deadline” — then finish one sentence from that word. The bridge keeps the thought moving while the answer stays direct.',
        disqualifiers: [
          'keep practicing the pause',
          'take a breath',
          'slow down',
          'give yourself more time',
          { pattern: 'silent pause', penalty: 8 },
        ],
      },
    ],
  },
];
