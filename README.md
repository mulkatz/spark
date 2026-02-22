<p align="center">
  <img src="assets/icon.png" alt="Spark" width="128" height="128">
</p>

<h1 align="center">Spark</h1>

<p align="center">Collaborative ideation plugin for <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a>. Generate surprising ideas through multi-persona brainstorming.</p>

<p align="center">
  <a href="https://github.com/mulkatz/spark/releases"><img src="https://img.shields.io/github/v/release/mulkatz/spark?style=flat-square" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/mulkatz/spark?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/Claude_Code-plugin-blueviolet?style=flat-square" alt="Claude Code Plugin">
  <img src="https://img.shields.io/badge/no_build-shell_%2B_markdown-green?style=flat-square" alt="No Build Step">
  <img src="https://img.shields.io/badge/status-in_active_development-brightgreen?style=flat-square" alt="In Active Development">
</p>

Spark is an **ideation tool** that generates diverse, non-obvious ideas by rotating 3 AI personas through Seed, Cross-Pollinate, and Synthesize phases. Each persona brings a distinct worldview — not generic role labels, but rich thinkers with specific philosophies, vocabularies, and blind spots.

The name: a spark is what ignites new thinking.

## Installation

In Claude Code, run:

```
/plugin marketplace add mulkatz/claude-plugins
/plugin install spark@mulkatz
```

That's it. No cloning needed. Auto-updates are supported via `/plugin marketplace update mulkatz`.

### Local development

For local development or testing, use `--plugin-dir`:

```bash
git clone https://github.com/mulkatz/spark.git
claude --plugin-dir ./spark
```

## How It Works

```
/spark "How can we make remote work more creative?"
  │
  ├─ SEED: Each persona generates ideas independently
  │   ├─ Theater Director: thinks in scenes, tension, audience experience
  │   ├─ Neuroscientist: thinks in dopamine, flow states, cognitive load
  │   └─ Urban Planner: thinks in spaces, flows, chance encounters
  │
  ├─ CROSS-POLLINATE: Personas see each other's ideas
  │   ├─ Build on what surprises them (not what's familiar)
  │   ├─ SCAMPER transformations: Substitute, Combine, Adapt, Modify, Reverse
  │   └─ Cross-domain connections emerge
  │
  └─ SYNTHESIZE: Pattern recognition, clustering, ranking
      └─ Output: Synthesis + Idea Map + Ranked Ideas + Next Steps
```

### Why Multi-Persona?

Single-agent brainstorming produces **convergent, expected ideas** — asking for more ideas from the same model doesn't increase diversity ([CHI 2025](https://dl.acm.org/doi/full/10.1145/3706598.3714198)). Spark's design is based on research showing that:

- **Rich personas** with worldviews and blind spots produce 2.5x more diverse output than abstract roles ([The Spark Effect, 2025](https://arxiv.org/html/2510.15568))
- **Independent generation before collaboration** prevents premature convergence ([Straub et al.](https://arxiv.org/abs/2512.04488))
- **SCAMPER transformations** generate more surprising combinations than "build on this" ([ACM CI 2025](https://dl.acm.org/doi/10.1145/3715928.3737479))
- **3 perspectives is optimal** — diminishing returns beyond that ([SIGDIAL 2025](https://arxiv.org/html/2507.08350v1))

## Usage

```
/spark "question or topic" [options]
```

| Option               | Default       | Description                                                            |
| -------------------- | ------------- | ---------------------------------------------------------------------- |
| `--personas`         | auto-selected | Comma-separated persona names or custom definitions                    |
| `--rounds`           | `1`           | Number of cross-pollination rounds (1-3)                               |
| `--interactive`      | off           | Pause before synthesis for user steering                               |
| `--interactive=full` | off           | Pause after every phase                                                |
| `--focus`            | —             | Lens to focus ideation (e.g., `"business model"`, `"user experience"`) |
| `--context`          | —             | File or directory for additional context                               |
| `--output`           | —             | Export result to file (.html or .md)                                   |

### Examples

```bash
# Basic ideation — system auto-selects 3 fitting personas
/spark "How can we reduce onboarding time for new developers?"

# With specific personas
/spark --personas "game-designer,anthropologist,architect" "How to increase user retention?"

# With custom persona
/spark --personas "custom:A kindergarten teacher who became a startup founder" "How to simplify our API?"

# Interactive — steer before synthesis
/spark --interactive "New revenue streams for an open-source project"

# With context and focus
/spark --context ./docs/architecture.md --focus "developer experience" "How to improve our CLI?"

# Multiple cross-pollination rounds
/spark --rounds 2 "What should our product look like in 5 years?"
```

## Personas

Spark ships with 9 curated personas, each designed for maximum thinking diversity:

| Persona                 | Thinking Axis          | Key Question                                |
| ----------------------- | ---------------------- | ------------------------------------------- |
| `biomimicry-scientist`  | Nature patterns        | "How did evolution solve this?"             |
| `theater-director`      | Narrative & tension    | "Where's the dramatic moment?"              |
| `urban-planner`         | Systems & flows        | "What if we change the infrastructure?"     |
| `game-designer`         | Mechanics & incentives | "What's the core loop?"                     |
| `anthropologist`        | Human behavior         | "What do people actually do vs. say?"       |
| `scifi-author`          | Extrapolation          | "What if this were 100x bigger?"            |
| `jazz-musician`         | Improvisation          | "What happens if we play this differently?" |
| `forensic-investigator` | Hidden connections     | "What is everyone overlooking?"             |
| `architect`             | Constraints & elegance | "What can we remove?"                       |

Or define your own: `--personas "custom:A retired general who now runs a bakery"`

## Output

Spark produces a structured report:

1. **Synthesis** — narrative of what emerged, what surprised, where personas converged/diverged
2. **Idea Map** — Mermaid mindmap showing themes and connections (renders in GitHub, Obsidian, VS Code)
3. **Ranked Ideas** — scored by Novelty, Feasibility, Impact with key assumptions and next steps
4. **Connections & Tensions** — complementary pairs, contradictions, build-on chains
5. **Next Steps** — concrete actions for top ideas

## Architecture

```
spark/
├── commands/
│   └── spark.md                  # /spark command
├── hooks/
│   └── stop-hook.sh              # Core orchestrator (state machine)
├── scripts/
│   └── setup-spark.sh            # Argument parsing + state initialization
├── prompts/
│   ├── phases/
│   │   ├── seed.md               # Independent ideation instructions
│   │   ├── cross-pollinate.md    # Build/combine/transform instructions
│   │   └── synthesize.md         # Pattern recognition + output instructions
│   ├── personas/                 # 9 curated thinking personas
│   └── modes/                    # Thinking-style variations
├── tests/
│   ├── helpers/                  # Shared test utilities
│   ├── setup-spark/              # Setup script tests
│   ├── stop-hook/                # Hook tests
│   ├── integration/              # End-to-end + shellcheck
│   └── lib/                      # bats-core/support/assert (submodules)
└── docs/
    ├── design.md                 # Full design document with research
    └── adr/                      # Architecture Decision Records
```

No TypeScript, no build step. Shell scripts orchestrate, markdown prompts instruct.

## Development

```bash
bun run check        # shellcheck + all tests
bun run test         # all bats tests
bun run test:setup   # setup-spark.sh tests only
bun run test:hook    # stop-hook.sh tests only
bun run lint         # shellcheck only
```

## Design Decisions

The design is grounded in academic research. See [docs/design.md](docs/design.md) for the full rationale including:

- Why rich personas outperform abstract roles (The Spark Effect, 2025)
- Why independent generation before collaboration prevents convergence
- Why SCAMPER transformations produce more surprising results
- Why interrupting divergent thinking hurts creativity
- Why 3 perspectives is the optimal number

## License

MIT
