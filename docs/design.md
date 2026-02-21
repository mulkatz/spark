# Spark — Design Document

> Collaborative ideation plugin for Claude Code. Multi-persona brainstorming through stop-hook orchestration.

## Problem Statement

When asking Claude for ideas, you get **convergent, expected results**. LLMs "lack idea diversity when scaling up" — more ideas from the same model doesn't mean more diverse ideas (CHI 2025). Multi-agent systems solve this measurably: MultiColleagues (2025) shows +63% topic-branching and +63% concept-production-rate vs. single-agent baseline.

Spark uses 3 AI personas with distinct worldviews that brainstorm independently, then cross-pollinate, then synthesize — producing ideas a single agent never would.

---

## Core Concepts

### Personas, Not Roles

Abstract role labels ("the creative thinker", "the practical thinker") **collapse into generic consultant tone** — this is a documented failure mode called "persona collapse" (The Spark Effect, 2025).

Rich creative worldview personas with encoded philosophies, specific vocabularies, and **explicit limitations** produce dramatically better diversity: 3.14 → 7.90 on a 10-point diversity scale, closing 82% of the gap to human expert diversity.

**What makes a good persona prompt:**

- A specific worldview and philosophy
- Domain-specific vocabulary and mental models
- Thinking style (how they approach problems)
- Explicit blind spots (what they would NOT say or consider)
- Constraints that force non-obvious connections

**Example** for "How can remote work be more creative?":

- **Theater Director** — thinks in scenes, tension, improvisation, audience reaction
- **Urban Planner** — thinks in spaces, flows, nodes, chance encounters
- **Neuroscientist** — thinks in dopamine, flow states, cognitive load, attention cycles

### Persona Sources

- **Presets**: 8-10 curated personas covering diverse thinking styles
- **Custom**: User-defined personas via `--personas "custom:description"`
- **Auto-selection**: System chooses 3 fitting personas based on the topic (default)

---

## Phase Structure: Separate → Together → Synthesize

Based on MultiColleagues (Double Diamond, validated in user study) + Straub et al. ("Separate-then-Together" produces most diverse results).

```
Phase 1: SEED (Divergent — each persona independently)
├── Persona A generates ideas alone
├── Persona B generates ideas alone
└── Persona C generates ideas alone
    ↓
Phase 2: CROSS-POLLINATE (Divergent→Convergent — personas see each other)
├── Persona A reacts to B+C: builds on, combines, transforms (SCAMPER)
├── Persona B reacts to A+C: builds on, combines, transforms
└── Persona C reacts to A+B: builds on, combines, transforms
    ↓
  [Optional: Round 2 Cross-Pollinate with --rounds 2]
    ↓
  [Interactive Checkpoint if --interactive]
    ↓
Phase 3: SYNTHESIZE (Convergent — meta-perspective)
└── Pattern recognition, clustering, ranking, idea map
```

### Why This Structure

1. **Independent SEED phase** prevents the #1 failure mode: premature convergence. When agents think together from the start, the first plausible idea wins (majority dynamics).
2. **CROSS-POLLINATE with SCAMPER** — the IBIS paper (ACM 2025) shows: an agent that explicitly _transforms_ existing ideas (Substitute, Combine, Adapt, Modify, Reverse) generates significantly more surprising combinations than pure "build on this".
3. **3 personas is optimal** — SIGDIAL 2025 confirms: diminishing returns beyond 3 parallel perspectives.

### Anti-Convergence Mechanisms

| Mechanism                                   | Source                         | Effect                                               |
| ------------------------------------------- | ------------------------------ | ---------------------------------------------------- |
| Independent generation before collaboration | Straub et al.                  | Preserves diverse starting points                    |
| Random constraint injection in SEED phase   | Oblique Strategies / Synectics | Breaks fixation, forces unexpected angles            |
| "Focus on what SURPRISES you" instruction   | The Spark Effect               | Counters agents being too agreeable                  |
| SCAMPER transformations in CROSS-POLLINATE  | IBIS System (ACM 2025)         | Systematic idea mutation vs. generation from scratch |

---

## State Machine

```
seed_p1 → seed_p2 → seed_p3 →
cross_p1 → cross_p2 → cross_p3 →
[round 2: cross_p1 → cross_p2 → cross_p3] →
[interactive-checkpoint if --interactive] →
synthesize → DONE
```

Same mechanical pattern as Anvil (stop hook intercepts response, appends transcript, injects next prompt) but different phase rotation.

### State File Format

```yaml
---
active: true
question: "How can remote work be more creative?"
phase: seed
persona_index: 0
round: 1
max_rounds: 1
personas: "theater-director|urban-planner|neuroscientist"
constraints: "What if a child had to understand this?|What if it had to work in silence?|What if you could only remove something?"
interactive: false
interactive_level: ""
focus: ""
context_source: ""
output: "~/Desktop/spark-2026-02-21-topic.html"
started_at: "2026-02-21T10:00:00Z"
---

<!-- persona:theater-director -->
[Persona description from preset file]
<!-- /persona -->

<!-- persona:urban-planner -->
[Persona description from preset file]
<!-- /persona -->

## Seed: theater-director

[Seed output appended by stop hook]

## Cross-Pollination Round 1: theater-director

[Cross output appended by stop hook]
```

---

## Interactivity

Research is surprisingly clear: **interruptions during divergent phases hurt creativity** (HAIExplore, 2025: "users tend to converge too quickly on early 'good enough' results").

### Three Levels

| Mode           | Flag                 | Behavior                                                                |
| -------------- | -------------------- | ----------------------------------------------------------------------- |
| **Autonomous** | (default)            | Runs to completion, result at the end                                   |
| **Checkpoint** | `--interactive`      | Pauses only before synthesis — user can steer direction or inject ideas |
| **Full**       | `--interactive=full` | Pauses after every phase — power-user mode                              |

### Checkpoint Design: Inject, Don't Ask

The pause before synthesis must lead with content, not ask a process question:

```
3 personas generated 14 ideas in 3 theme clusters:
• Cluster A: Spatial Design (5 ideas) — strongest: "Virtual Serendipity Corridors"
• Cluster B: Cognitive Rhythm (4 ideas) — strongest: "Dopamine-Mapped Sprint Cycles"
• Cluster C: Social Improvisation (5 ideas) — strongest: "Async Improv Chains"

Type a direction/constraint for synthesis, or press Enter to continue:
>
```

Auto-continue after 30 seconds if no input.

**Why "inject, don't ask"**: Research shows the worst prompt is "How would you like to proceed?" — it forces meta-cognitive work. Better: give context, let user react. (Miro AI research, UXmatters 2025)

---

## Output Format

Based on Design Thinking research (IDEO), Miro AI findings, and Board of Innovation Concept Cards.

### Report Structure

````markdown
# Spark Report: [Topic]

> 3 Personas | 1 Round | 2026-02-21

## Synthesis

[2-4 paragraphs: What emerged? What surprised? Where did personas
converge vs. diverge? — Most-read section per research]

## Idea Map

​`mermaid
mindmap
  root((Topic))
    Theme A
      Idea 1
      Idea 2
    Theme B
      Idea 3
        Builds on Idea 1
      Idea 4
    Cross-cutting
      Idea 5
​`

## Top Ideas

### 1. [Idea Title]

**Score**: 4.3/5 (Novelty: 5 | Feasibility: 3 | Impact: 5)
[2-3 sentence description]
**Key Assumption**: [What must be true for this to work]
**First Step**: [Concrete actionable next move]

### 2. ...

## Also Explored

- **Idea N**: Brief description
- **Idea N+1**: Brief description

## Connections & Tensions

- **Complementary**: Idea 1 + Idea 3 — [reason]
- **Tension**: Idea 2 vs Idea 5 — [axis]
- **Chain**: Idea 6 → Idea 4 → Idea 1 (progressive refinement)

## Next Steps

1. [Action for top idea 1]
2. [Action for top idea 2]
3. [Action for top idea 3]
````

### Why This Structure

1. **Synthesis first** — narrative summary is the most-read section (Design Thinking research). Orients reader before details.
2. **Mermaid mindmap** — simultaneously readable as text AND renderable as visual in GitHub, Obsidian, VS Code. No external viewer needed.
3. **Scored idea cards** — per-idea fields (key assumption, first step) from Board of Innovation Concept Card template. Most actionable format in practice.
4. **"Also Explored" section** — brainstorming research warns against losing ideas. Low-overhead capture.
5. **Connections & Tensions** — the differentiator. Shows how ideas relate, which is what concept mapping research says drives deepest understanding.
6. **Next Steps** — without concrete actions, ideation output becomes shelfware (BDC, IDEO).

### Scoring Dimensions

| Dimension       | What it measures                                    |
| --------------- | --------------------------------------------------- |
| **Novelty**     | How unusual, unexpected, differentiated?            |
| **Feasibility** | Can it be built/executed with available resources?  |
| **Impact**      | How much value for users, business, or stated goal? |

Each scored 1-5, composite = weighted average. Weights configurable (moonshot session → novelty higher; quick wins → feasibility higher).

### Export

- Default: Markdown to stdout
- `--output report.html` — HTML with rendered Mermaid diagrams
- `--output report.md` — Markdown file

---

## CLI Interface

```bash
# Basic usage
/spark "How can we make remote work more creative?"

# With custom personas
/spark --personas "theater-director,urban-planner,neuroscientist" "topic"

# With fully custom persona
/spark --personas "custom:A Buddhist monk who spent 20 years in tech" "topic"

# Interactive mode (pause before synthesis)
/spark --interactive "topic"

# Multiple rounds of cross-pollination
/spark --rounds 2 "topic"

# With context file
/spark --context ./research-notes.md "topic"

# With focus
/spark --focus "business model" "topic"

# Full output
/spark --output report.html "topic"
```

### Parameters

| Flag                 | Default       | Description                                         |
| -------------------- | ------------- | --------------------------------------------------- |
| `--personas`         | auto-selected | Comma-separated persona names or custom definitions |
| `--rounds`           | `1`           | Number of cross-pollination rounds                  |
| `--interactive`      | off           | Pause before synthesis for user direction           |
| `--interactive=full` | off           | Pause after every phase                             |
| `--focus`            | none          | Lens to focus ideation through                      |
| `--context`          | none          | File path for additional context                    |
| `--output`           | none          | Export result to file (html/md)                     |

---

## Research Sources

### Multi-Agent Ideation Systems

- [MultiColleagues: Towards AI as Colleagues](https://arxiv.org/abs/2510.23904) — Most complete multi-agent ideation system with quantitative results. Double Diamond validated.
- [The Spark Effect: Engineering Creative Diversity](https://arxiv.org/html/2510.15568) — Best results on persona design (3.14→7.90 diversity). Rich personas with explicit constraints.
- [Persona-based Multi-Agent Collaboration](https://arxiv.org/abs/2512.04488) — Separate/together comparison. Domain personas produce targeted distributions.
- [Multi-Agent LLM Dialogues for Research Ideation](https://arxiv.org/html/2507.08350v1) — Optimal config: 3 parallel critics + 2-3 iterations.
- [Can LLM-Powered Multi-Agent Systems Augment Creativity?](https://dl.acm.org/doi/10.1145/3715928.3737479) — IBIS + SCAMPER multi-agent system.
- [Creativity in LLM-based Multi-Agent Systems Survey](https://arxiv.org/abs/2505.21116) — EMNLP 2025 comprehensive survey.
- [Human Creativity in the Age of LLMs](https://dl.acm.org/doi/full/10.1145/3706598.3714198) — CHI 2025. Documents convergence problem.

### Interactive UX

- [HAIExplore: Scaffolding Divergent and Convergent Thinking](https://arxiv.org/abs/2512.18388) — Premature convergence with human intervention.
- [YES AND: Multi-Agent Framework for Ideation](https://dl.acm.org/doi/10.1145/3706599.3720142) — CHI 2025. On-demand interjection.
- [Designing For Agentic AI: Practical UX Patterns](https://www.smashingmagazine.com/2026/02/designing-agentic-ai-practical-ux-patterns/) — Smashing Magazine, Feb 2026.
- [Designing for Autonomy: UX Principles for Agentic AI](https://www.uxmatters.com/mt/archives/2025/12/designing-for-autonomy-ux-principles-for-agentic-ai.php) — UXmatters, Dec 2025.

### Output & Evaluation

- [Board of Innovation Concept Card](https://www.boardofinnovation.com/tools/concept-card/) — Per-idea card template.
- [Miro Idea Prioritization Card](https://miro.com/miroverse/idea-prioritization-card/) — Scoring template.
- [Mermaid.js Mindmap Syntax](https://mermaid.js.org/syntax/mindmap.html) — CLI-friendly idea maps.

### Creative Frameworks

- [AutoTRIZ: Artificial Ideation with TRIZ and LLMs](https://arxiv.org/abs/2403.13002) — TRIZ methodology automated.
- [Oblique Strategies and AI Creativity](https://venturebeat.com/ai/how-brian-eno-anticipated-the-creative-dynamics-of-ai-by-decades) — Random constraint injection.
- [Divergent and Convergent LLM Personas](https://arxiv.org/html/2510.26490) — Temperature-differentiated cognitive roles.
