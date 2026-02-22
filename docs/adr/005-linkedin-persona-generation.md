# ADR 005: LinkedIn Persona Generation Phase & Enhanced Custom Personas

## Status

Accepted

## Context

Spark supports 9 preset personas with rich definitions (worldview, vocabulary, blind spots) and a basic `custom:description` syntax. Two problems emerged:

1. **Custom personas are bare** — they pass the raw description string without the richness that makes preset personas effective, leading to noticeably worse ideation quality ("persona collapse")
2. **No way to brainstorm as real people** — users can't say "think like Satya Nadella" without manually writing a full persona definition

## Decision

### Enhanced Custom Personas

When a persona name starts with `custom:`, wrap the description in a rich template that instructs Claude to fully embody the character — building worldview, vocabulary, blind spots, and thinking patterns from the seed description. This applies in both `seed` and `cross` phases, replacing the previous bare `# Persona: custom:description` format.

### LinkedIn Persona Generation Phase

Add a new `persona_gen` phase to the state machine that runs before `seed`, only when `linkedin:` personas are present. During this phase, Claude researches the person (via WebSearch if available) and generates a full persona document in the same format as preset personas.

**State machine extension:**
```
[persona_gen(p0) → persona_gen(p1) → ...] →   (only if LinkedIn personas present)
seed(p0) → seed(p1) → seed(p2) →
cross(p0) → cross(p1) → cross(p2) →
synthesize → DONE
```

**New frontmatter fields:**
- `gen_indices` — pipe-separated indices of personas needing generation (empty if none)
- `gen_current` — current position within gen_indices

**Comma handling:** LinkedIn references like `linkedin:Jane Smith, VP Engineering at Google` contain commas, but commas are also the persona separator. The parser consumes subsequent comma-separated segments until it hits a recognized persona prefix (`custom:`, `linkedin:`, or a valid preset name).

## Alternatives Considered

1. **Require users to write custom persona files** — too much friction for casual use
2. **Generate all personas in a single prompt** — would hit token limits and reduce quality per persona
3. **Use a different separator** (semicolons) — would break backwards compatibility and confuse users familiar with the comma syntax
4. **Pre-built personas for famous people** — doesn't scale, stale data, legal concerns

## Consequences

- The state machine has a new optional pre-phase, increasing complexity slightly
- LinkedIn personas require an internet connection for best results (graceful fallback to model knowledge)
- Custom personas now produce richer output but use more tokens per phase
- The `display_name()` helper centralizes prefix stripping for consistent UX across banner, system messages, and HTML reports
