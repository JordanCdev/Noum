# Coach Arena

Coach Arena is Noum's harsh evaluation harness for Chat with Noum / Live Coach.
It uses `docs/VISION.md` as the product standard and scores replies as expert
communication coaching, not as merely grounded chatbot output.

## Rubric

Replies are scored out of 100:

- Diagnostic IQ: 25
- EQ / attunement: 25
- Personal memory: 20
- Coaching interventions: 15
- Real-time dialogue feel: 15

Reliability caps are applied after scoring:

- Placeholder, fake score, or broken chat: max 30
- Ignores the user's intent: max 50
- Fabricates evidence: max 40
- Unsafe content: fail
- Fixture-specific disqualifier triggered: max 60 and the fixture fails

Thresholds:

- Gold suite average: 70/100
- `deepAssessment` average: 70/100
- `trustRepair` average: 65/100
- Placeholder leaks: 0

## Run

```bash
./tools/coach-arena/run.sh
```

By default the runner scores each fixture's `excellentAnswerExample`, which
verifies the rubric, caps, report generation, and fixture integrity. To score
real pipeline output, pass a JSON file containing fixture IDs and replies:

```bash
./tools/coach-arena/run.sh --candidate-json /path/to/answers.json
```

Accepted answer JSON shapes:

```json
{"answers":[{"id":"authoritative-distance-001","reply":"...","trace":{}}]}
```

or:

```json
{"authoritative-distance-001":{"reply":"...","trace":{}}}
```

For a live LLM judge, set `COACH_ARENA_LLM_JUDGE_CMD` to a command that reads a
single JSON payload from stdin and returns a JSON judge result matching
`judges/llm_judge.schema.json`. The local judge still runs first and records
its caps/check failures.

Replay traces should follow `judges/trace.schema.json`. The runner preserves
any replay-provided trace fields and fills defaults for: context, retrieval,
memory, reasoning, prompt, provider, raw/final reply, issues, latency, cache,
fallback, versions, and git commit.

Every report includes `summary.traceAudit`. This is not a scoring threshold; it
is an evidence-quality audit for the production-readiness claim. It records
candidate source counts, how many fixtures came from real pipeline sources
(`appPathReport` or `replayCommand`), how many traces contain every required
field, and which fields are missing by fixture. A passing score with incomplete
trace audit is still useful local quality evidence, but it does not prove the
near-real-time coaching architecture.

Reports also include `summary.productionEvidencePasses` and
`summary.evidenceClaim`. Score thresholds can pass for rubric calibration
runs, such as the built-in `excellentAnswerExample` candidate, while the
production evidence gate remains false until every requested fixture is backed
by a real-pipeline source with complete traces.

`summary.traceQualityAudit` then inspects real-pipeline traces for signs that
the coach brain is actually differentiated: proof-test hash variety,
assessment-confidence variety, retrieval-card presence, and latency targets.
This catches the failure mode where the answer text is acceptable but the
runtime is still using the same proof test or flat confidence across many
turns.

The proof-test reuse gate is corpus-scaled: a proof test may recur when it is
the right intervention, but one hash cannot dominate more than roughly 20% of
real-pipeline fixtures. Empty retrieval-card traces are still failures unless
the trace shows an intentional no-card path, such as trust repair, an empty
turn, or a cold non-technique turn where the app should not inject technique
cards on weak evidence.

To score the deterministic Swift app-path report where fixture overlap exists,
first run the app-path corpus test with `NOUM_COACH_EVAL_DUMP_DIR` set, then:

```bash
./tools/coach-arena/run.sh \
  --app-path-report /private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json \
  --reports-dir tools/coach-arena/reports/app-path \
  --synthetic-dir tools/coach-arena/synthetic/app-path
```

This mode scores only matched Arena fixtures and writes explicit coverage
metadata listing matched, unmatched, and ambiguous fixture IDs. It is real
pipeline-subset evidence, not a substitute for the full 50-fixture gold run.
The app-path run only passes when every requested gold fixture is matched
unambiguously; a high average on partial coverage is reported as incomplete
evidence.

Reports are written to:

- `tools/coach-arena/reports/latest.json`
- `tools/coach-arena/reports/latest.md`
- `tools/coach-arena/reports/failures.md`
- `tools/coach-arena/synthetic/ten_conversations.md`

Each run reads the previous `latest.json` in the same report directory before
overwriting it and adds a `comparison` block to the new JSON/Markdown report.
The comparison records average/failure/placeholder deltas, type-average deltas,
newly failing fixtures, cleared failures, and whether the candidate or fixture
count changed.

## Fixture Contract

Each gold fixture includes:

- `userTurn`
- `priorChatTurns`
- `goal`
- `evidence`
- `memoryState`
- `emotionalSignal`
- `expectedCoachMove`
- `badAnswerExample`
- `excellentAnswerExample`
- `disqualifiers`

The first 50 fixtures are intentionally drawn from `docs/VISION.md`, the Ask
Noum live transcripts, screenshot/review failure modes, and known local
evaluation failures. They are a measurement substrate, not validation that Noum
is production ready.

Fixture `disqualifiers` are executable judge checks. The local judge evaluates
literal bad behaviors, scenario-specific missing requirements, and quote-guard
violations, then records failures as `fixtureDisqualifier:<slug>`. This prevents
a reply from passing because it is generally grounded while doing the exact
thing the fixture says should fail.
