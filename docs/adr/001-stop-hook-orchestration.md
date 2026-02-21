# ADR 001: Stop Hook Orchestration for Multi-Phase Ideation

## Status

Accepted

## Context

Spark needs to rotate Claude through multiple personas across three phases (Seed, Cross-Pollinate, Synthesize). The key challenge: Claude normally controls its own conversation flow, but we need to inject different persona instructions at specific transitions.

Options considered:

1. **Stop hook pattern** — intercept Claude's exit, inject next prompt, force continuation
2. **Single prompt with all instructions** — describe the full rotation in one system prompt
3. **Multiple commands** — user manually runs `/spark-seed-1`, `/spark-seed-2`, etc.

## Decision

Use the stop hook pattern (option 1), matching Anvil's architecture.

## Rationale

- **Single prompt fails at scale**: 3 personas × 3 phases = 9 distinct instruction sets. A single prompt would be enormous and Claude would struggle to track which persona/phase it's in
- **Manual commands break flow**: The whole point of Spark is autonomous ideation. Making users trigger each phase defeats the purpose
- **Stop hook is proven**: Anvil uses the same pattern for 3-round debates with persona rotation. The state machine (YAML frontmatter), transcript accumulation, and JSON output format are battle-tested
- **Independent seed enforcement**: The stop hook can withhold the transcript during Seed phases, which is critical for preventing premature convergence

## Consequences

- Plugin requires Claude Code's hook system (stop hook support)
- State file management adds complexity (create, update, cleanup)
- Debugging requires checking `.claude/spark-state.local.md`
- Consistent architecture with Anvil reduces cognitive overhead for users of both plugins
