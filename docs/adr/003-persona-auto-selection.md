# ADR 003: Random Persona Auto-Selection

## Status

Accepted

## Context

When users don't specify `--personas`, Spark needs to choose 3 personas from the available pool. Options considered:

1. **Random selection** — shuffle available personas, pick 3
2. **Topic-based selection** — use an LLM call to match personas to the topic
3. **Fixed defaults** — always use the same 3 personas
4. **Orthogonality-maximizing algorithm** — select personas that are maximally different

## Decision

Use random selection (option 1) for v0.1.

## Rationale

- **Simplicity**: No extra LLM call, no latency, no API cost. A portable `awk`+`sort` shuffle is all that's needed
- **Persona design ensures diversity**: All 9 presets are deliberately designed with orthogonal thinking axes (theater vs. urban planning vs. neuroscience vs. game design, etc.). Any random combination of 3 produces meaningfully different perspectives
- **Surprise value**: Random selection sometimes creates unexpected persona combinations that a "smart" selector wouldn't choose — these surprising combinations can produce the most creative results
- **No premature optimization**: Topic-based selection sounds better but requires prompt engineering, testing, and tuning. Better to ship random and upgrade later if user feedback indicates it matters

## Consequences

- Occasionally suboptimal combinations (e.g., two personas that think similarly)
- Users who want specific combinations can use `--personas` explicitly
- Future enhancement: could add topic-based selection behind a flag or as the default once validated
