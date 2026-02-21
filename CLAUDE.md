# Spark — Collaborative Ideation Plugin

## What this is

A Claude Code plugin that enables collaborative ideation through multi-persona brainstorming. Uses stop hook orchestration to rotate 3 AI personas through Seed → Cross-Pollinate → Synthesize phases, producing diverse, non-obvious ideas that a single agent never would.

## Architecture

- **No TypeScript runtime** — the plugin is shell scripts + markdown prompts
- `bun` is used as package manager only (scripts, formatting)
- The prompts in `prompts/` ARE the product
- Stop hook (`hooks/stop-hook.sh`) is the orchestrator — it manages the state machine
- State lives in `.claude/spark-state.local.md` (YAML frontmatter + markdown transcript)
- Full design rationale with research sources in `docs/design.md`

## Key files

- `hooks/stop-hook.sh` — Core state machine and prompt routing
- `scripts/setup-spark.sh` — Argument parsing, validation, state file creation
- `prompts/phases/{seed,cross-pollinate,synthesize}.md` — Phase-specific instructions
- `prompts/personas/*.md` — Rich persona definitions (worldview, vocabulary, blind spots)
- `commands/spark.md` — Entry point command

## Core Design Decisions

### Personas, not roles

Abstract labels collapse into generic consultant tone ("persona collapse"). Every persona must have: a specific worldview, domain vocabulary, thinking style, and **explicit blind spots**. See `docs/design.md` for research backing.

### Separate → Together → Synthesize

1. **SEED**: Each persona generates ideas independently (prevents premature convergence)
2. **CROSS-POLLINATE**: Personas see each other's output, build/combine/transform using SCAMPER
3. **SYNTHESIZE**: Pattern recognition, clustering, ranking, idea map

### Anti-convergence mechanisms

- Independent generation before collaboration
- Temperature differentiation per persona (0.3–0.8)
- Random constraint injection in SEED phase
- SCAMPER transformations in CROSS-POLLINATE
- "Focus on what SURPRISES you" prompt instruction

### State machine

```
seed_p1 → seed_p2 → seed_p3 →
cross_p1 → cross_p2 → cross_p3 →
[round 2 if --rounds 2] →
[interactive checkpoint if --interactive] →
synthesize → DONE
```

## Conventions

- ADRs in `docs/adr/` for architectural decisions
- State file uses `.local.md` suffix (gitignored by Claude Code)
- All shell scripts use `set -euo pipefail`
- Frontmatter parsing with `sed`, transcript manipulation with `awk`
- Atomic file updates via temp file + `mv`

## Testing

Every change to `setup-spark.sh` or `stop-hook.sh` MUST include corresponding test updates. Run `bun run check` (shellcheck + all bats tests) before committing — it must pass.

### Running tests

- `bun run check` — shellcheck + full suite (use this before every commit)
- `bun run test` — all bats tests
- `bun run test:setup` — setup-spark.sh tests only
- `bun run test:hook` — stop-hook.sh tests only
- `bun run lint` — shellcheck only

### Test structure

Tests mirror the source scripts:

| Source                   | Test directory       | What it covers                                                                                         |
| ------------------------ | -------------------- | ------------------------------------------------------------------------------------------------------ |
| `scripts/setup-spark.sh` | `tests/setup-spark/` | Arg parsing, validation, state file creation, persona selection, context injection                     |
| `hooks/stop-hook.sh`     | `tests/stop-hook/`   | Entry conditions, state transitions, prompt construction, persona prompts, interactive mode, synthesis |
| Both combined            | `tests/integration/` | End-to-end ideation cycles, shellcheck                                                                 |
