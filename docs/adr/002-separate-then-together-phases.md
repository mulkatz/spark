# ADR 002: Separate-Then-Together Phase Structure

## Status

Accepted

## Context

How should multiple AI personas collaborate during ideation? The phase structure determines idea diversity, quality, and whether the system actually outperforms single-agent brainstorming.

Options considered:

1. **Simultaneous collaboration** — All personas brainstorm together from the start
2. **Sequential building** — Each persona sees and builds on the previous persona's output
3. **Separate-then-together** — Independent generation first, then cross-pollination, then synthesis

## Decision

Use separate-then-together (option 3) with three phases: Seed → Cross-Pollinate → Synthesize.

## Rationale

### Independent Seed phase prevents the #1 failure mode

When agents think together from the start, the first plausible idea wins — this is documented as "majority dynamics" in multi-agent systems. Straub et al. (2025) show that "Separate-then-Together" produces the most diverse results compared to simultaneous or sequential approaches.

### SCAMPER in Cross-Pollination produces better combinations

The IBIS paper (ACM Creativity & Interaction 2025) demonstrates that agents explicitly applying SCAMPER operations (Substitute, Combine, Adapt, Modify, Put to other use, Eliminate, Reverse) generate significantly more surprising combinations than unstructured "build on this" instructions.

### Three phases match the Double Diamond

MultiColleagues (2025) validates the Double Diamond pattern for AI ideation: diverge (Seed), diverge+converge (Cross-Pollinate), converge (Synthesize). Their user study shows +63% topic-branching and +63% concept-production-rate vs. single-agent baseline.

### Three personas is optimal

SIGDIAL 2025 research confirms diminishing returns beyond 3 parallel perspectives. Adding more agents increases token cost linearly but diversity gains plateau.

## Consequences

- Seed phase must NOT include the transcript — this is the critical anti-convergence mechanism
- Cross-pollinate phase must include the full transcript so personas can reference each other
- Total LLM turns = (3 × Seed) + (3 × Rounds × Cross) + 1 Synthesis = minimum 7 turns
- More token-intensive than single-prompt ideation, but measurably more diverse output

## References

- Straub et al. (2025): "Persona-based Multi-Agent Collaboration" — arxiv.org/abs/2512.04488
- MultiColleagues (2025): "Towards AI as Colleagues" — arxiv.org/abs/2510.23904
- IBIS System (ACM 2025): "Can LLM-Powered Multi-Agent Systems Augment Creativity?" — dl.acm.org/doi/10.1145/3715928.3737479
- SIGDIAL (2025): "Multi-Agent LLM Dialogues for Research Ideation" — arxiv.org/html/2507.08350v1
