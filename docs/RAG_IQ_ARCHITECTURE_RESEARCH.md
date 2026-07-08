# Research: app-owned IQ/RAG so a cheap model coaches at expert level

_Deep-research synthesis 2026-07-08 — Noum coaching-quality architecture._

## Bottom line

Yes — an architecture that puts durable coaching expertise in the app's retrieval + knowledge layer and uses a small/cheap model (e.g., Claude Haiku) as a thin phrasing layer is well-supported by peer-reviewed evidence, provided retrieval precision and output-verification are engineered aggressively. Multiple primary studies show retrieval-augmented small models matching or beating far larger models on grounded, knowledge-intensive tasks: Atlas-11B beat a 540B model on Natural Questions; an 8B model matched GPT-4o under ideal retrieval on QA; and sub-100B models plus RAG matched or exceeded large LLMs on clinical decision support. RAG structurally decouples knowledge from weights (updatable without retraining), and grounding demonstrably cuts hallucination (>60%) with the largest gains on out-of-distribution topics not stored in the model's weights. Reliability from a weak model is achievable through externally-enforced structured outputs (JSON-Schema conformance + revalidation), self-check/reflection mechanisms (Self-RAG), and small-model-as-verifier consistency checks (CaLM). The critical caveat: small models are a double-edged sword — they are more sensitive to retrieval quality than large models, so noisy or merely-present context can destroy 42–100% of answers the model would otherwise get right (a distraction effect), making high-precision retrieval and post-retrieval context reduction (e.g., MobileRAG's SCR) non-negotiable; on-device Swift RAG (VecturaKit, MobileRAG) is proven feasible on commodity phones.

## Findings

### 1. Strong retrieval lets a small model match or beat a much larger model on grounded, knowledge-intensive tasks — the core thesis that domain expertise can live in the retrieval layer rather than model weights.
*confidence: high*

Atlas (~11B) reached >42% on Natural Questions with only 64 training examples, outperforming a 540B PaLM by ~3% despite being 50x smaller (arXiv:2208.03299, JMLR 2023). KazLLM-8B under Ideal RAG reached answer correctness 0.867, closely matching GPT-4o's 0.869 on Kazakh QA (MDPI Information 16(11):943, 2025). Sub-100B models + RAG matched or exceeded larger LLMs on clinical decision support; Mixtral-8x7b (~47B) + RAG achieved the highest diagnostic (72%) and therapeutic (73%) F1, matching/edging out 70B Nemotron and GPT-4o (Frontiers in Medicine 2026). Convergent across three peer-reviewed primary sources, unanimous votes.

- https://arxiv.org/abs/2208.03299
- https://www.mdpi.com/2078-2489/16/11/943
- https://www.frontiersin.org/journals/medicine/articles/10.3389/fmed.2026.1817215/full

### 2. Nearly all of a small model's quality gain in a grounded task comes from the retrieved knowledge layer, not the model's parametric knowledge — validating that expertise should be externalized.
*confidence: high*

KazLLM-8B closed-book scored only 0.427 vs 0.867 under retrieval — the +0.44 gain is attributable to provided passages since parameters are unchanged (MDPI 2025). Retrieval's benefit is largest for out-of-distribution topics (85% knowledgeability gain OOD vs 70% in-distribution) precisely because retrieval supplies knowledge not in the weights (Shuster et al., EMNLP Findings 2021). This is the mechanistic justification for encoding durable coaching expertise (diagnosis rubrics, intervention playbooks) as retrievable knowledge rather than relying on the model.

- https://www.mdpi.com/2078-2489/16/11/943
- https://aclanthology.org/2021.findings-emnlp.320.pdf

### 3. RAG decouples knowledge from model weights, enabling continuous knowledge updates and domain-specific expertise integration without retraining — the architectural basis for an app-owned expertise layer over a swappable thin model.
*confidence: high*

Gao et al. RAG survey (arXiv:2312.10997): RAG 'allows for continuous knowledge updates and integration of domain-specific information,' whereas fine-tuning 'is more static, requiring retraining' for updates. Uniformly corroborated across independent sources. For Noum this supports encoding coaching expertise into the KnowledgeRetriever/BM25 layer so it can evolve independently of (and outlast) any specific model like Haiku.

- https://arxiv.org/pdf/2312.10997

### 4. Grounding LLM output in retrieved knowledge substantially reduces hallucination, even for the largest models — reliability is a retrieval property, not purely a scale property.
*confidence: high*

Retrieval-augmented conversational models reduced hallucinated responses by over 60% versus non-retrieval LLMs, confirmed by human evaluation (Shuster et al., EMNLP Findings 2021; baseline BART-Large hallucinated 68.2% vs FiD-RAG 7.9%, ~88% relative reduction). The paper explicitly notes 'even the largest models suffer from the well known hallucination problem,' motivating externalizing knowledge into a retrieval layer rather than relying on model scale. Caveat: baselines are 2021-era (BART-Large), not a frontier LLM, but the directional principle is durable and uncontested.

- https://aclanthology.org/2021.findings-emnlp.320.pdf

### 5. Weak-model output can be constrained and verified against retrieved knowledge via external structured-output enforcement, self-check/reflection, and small-model-as-verifier consistency checks — reliability engineered outside the model.
*confidence: high*

Guardrails forces output into a JSON-Schema-conforming structure via function calling (or prompt optimization) and validates externally with re-prompting on failure — a schema-conformance layer operating outside the model (guardrailsai.com docs). Self-RAG uses 'reflection tokens' (retrieve + critique/ISREL/ISSUP/ISUSE) letting the model introspect outputs and filter low-relevance retrieved documents before generating (arXiv:2312.10997 / Asai et al. 2310.11511). CaLM (ACL 2024, arXiv:2406.05365) uses a small LM to answer the same query using only the cited documents and validates grounding via ROUGE-2 consistency between responses. These map directly onto Noum's deterministic coaching gates + structured CoachContextBuilder output. Note: Guardrails 'forcing' is guaranteed only via constrained decoding / re-prompting loops, not purely via prompt optimization.

- https://www.guardrailsai.com/docs/how_to_guides/generate_structured_data
- https://arxiv.org/pdf/2312.10997
- https://arxiv.org/html/2406.05365v2

### 6. Small models are MORE sensitive to retrieval quality than large models: high-precision, distractor-free retrieval is mandatory because a weak model amplifies both good and bad context.
*confidence: high*

CaLM (arXiv:2406.05365): 'smaller LMs are more sensitive to the relevance of input evidence... Irrelevant documents can easily mislead small LMs,' while larger LMs over-rely on internal parametric memory. This cuts both ways — small models benefit more from good retrieval and are hurt more by noise. Direct implication for Noum: because Haiku will amplify retrieval errors, the BM25/hybrid retrieval must be tuned for precision and paired with a distractor-filtering / re-ranking step before context reaches the model.

- https://arxiv.org/html/2406.05365v2
- https://arxiv.org/html/2603.11513

### 7. A real risk of naive RAG at small scale: adding retrieved context can DESTROY answers the model would have gotten right from parametric knowledge (distraction effect), producing a net-negative accuracy trade-off unless retrieval is gated and filtered.
*confidence: medium*

arXiv:2603.11513 (Pandey, 2026): any retrieval — including oracle — destroyed 42–100% of previously correct parametric answers in sub-8B quantized models; standard RAG at 7B scale gave +8pp on unknown questions but -51pp on known questions, a -3pp net trade-off. Scope caveats: measured on 4-bit-quantized sub-8B open models on extractive short-form QA, NOT on Claude Haiku (a frontier hosted model) nor on open-ended generative coaching; the paper notes robust context utilization may require >7B params. The distraction-effect claim [14] passed only 2-1, and a related claim that oracle retrieval fails 85-100% of the time for <=7B models was REFUTED (0-3). Directional lesson holds — implement adaptive/gated retrieval (Self-RAG-style 'retrieve when needed') and quality gates so retrieval is not blindly injected. Magnitude should not be assumed to transfer to Haiku.

- https://arxiv.org/html/2603.11513

### 8. On-device / low-cost RAG in a Swift/iOS app is proven feasible: Swift-native on-device vector DBs with hybrid vector+BM25 search exist, and full on-device RAG pipelines match server-grade RAG accuracy on commodity phones while cutting latency and power.
*confidence: high*

VecturaKit is a Swift on-device vector database with hybrid search combining vector similarity and BM25 (adjustable hybridWeight, default 0.5), fully local storage/retrieval persisting across sessions with no server for the core retrieval layer (github.com/rryam/VecturaKit) — directly compatible with Noum's existing BM25 index. MobileRAG (arXiv:2507.01079) runs small models (Qwen-2.5 0.5B/1.5B, Deepseek-r1 1.5B) on a Galaxy S24, matching Advanced RAG accuracy (Qwen-2.5 1.5B: SQuAD 65.1, HotpotQA 33.2, TriviaQA 56.7 vs 65.1/33.4/56.9) while cutting TTFT (7.41s vs 11.78s on SQuAD) and per-query power. Its Selective Content Reduction (SCR) — re-chunking retrieved docs at sentence level, recomputing per-chunk query similarity, keeping only top chunks — cuts context tokens up to ~42% with near-zero accuracy loss, the primary lever for reducing weak-model latency/energy and for suppressing the distraction effect.

- https://github.com/rryam/VecturaKit
- https://arxiv.org/pdf/2507.01079
