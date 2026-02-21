# ADR 004: Anti-Convergence Mechanisms

## Status

Accepted

## Context

The core problem Spark solves is that single-agent LLMs produce convergent, expected ideas. Multiple mechanisms are needed to actively prevent convergence when using multiple AI personas.

## Decision

Implement four anti-convergence mechanisms, each backed by research:

### 1. Independent Seed Phase (No Transcript Sharing)

During the Seed phase, each persona generates ideas without seeing what other personas produced. The stop hook enforces this by NOT including the transcript in seed prompts.

**Research**: Straub et al. (2025) — "Separate-then-Together" produces the most diverse results. When agents see each other's output from the start, the first plausible idea dominates (majority dynamics).

### 2. Random Constraint Injection

Each persona in the Seed phase receives a unique oblique-strategy-style constraint (e.g., "What if this had to work without any technology?"). No two personas get the same constraint.

**Research**: Oblique Strategies (Brian Eno) + Synectics methodology. Random constraints break fixation by forcing the thinker to consider the problem from an angle they wouldn't naturally choose.

### 3. SCAMPER Framework in Cross-Pollination

The Cross-Pollinate phase explicitly instructs personas to apply SCAMPER operations (Substitute, Combine, Adapt, Modify, Put to other use, Eliminate, Reverse) rather than simply "building on" ideas.

**Research**: IBIS System (ACM Creativity & Interaction 2025) — agents applying structured transformation operations generate significantly more surprising combinations than unstructured collaboration.

### 4. "Focus on What SURPRISES You" Instruction

The Cross-Pollinate prompt explicitly instructs: "Focus on what SURPRISES you, not what's familiar." This counters LLMs' tendency to be agreeable and find common ground.

**Research**: The Spark Effect (2025) — specific prompt instructions about seeking surprise and contradiction measurably increase idea diversity.

## Consequences

- Seed prompts must be carefully constructed to exclude transcript data
- Constraint pool must be maintained and expanded over time
- SCAMPER framework adds structure but may feel rigid — mitigated by making it suggestive ("try at least 2-3") rather than mandatory
- These mechanisms work together — removing any one reduces diversity measurably

## References

- Straub et al. (2025): arxiv.org/abs/2512.04488
- Brian Eno's Oblique Strategies: en.wikipedia.org/wiki/Oblique_Strategies
- IBIS System (ACM 2025): dl.acm.org/doi/10.1145/3715928.3737479
- The Spark Effect (2025): arxiv.org/html/2510.15568
