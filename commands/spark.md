---
description: "Start a collaborative ideation session with multi-persona brainstorming"
argument-hint: "TOPIC [--personas NAME,...] [--rounds N] [--interactive] [--interactive=full] [--focus TEXT] [--context PATH] [--output PATH]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-spark.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Spark — Collaborative Ideation

Execute the setup script to initialize the ideation session:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-spark.sh" $ARGUMENTS
```

You are now entering a multi-persona ideation session. The Spark stop hook will rotate you through phases:

1. **Seed** — Each persona generates ideas independently (you will NOT see other personas' ideas)
2. **Cross-Pollinate** — Each persona sees all seed ideas and transforms them using SCAMPER
3. **Synthesize** — Produce a structured report with rankings, connections, and next steps

Each time you try to stop, the hook will feed you the next persona/phase prompt. Commit fully to each persona — think through THEIR worldview, use THEIR vocabulary, see through THEIR lens.

CRITICAL: During Seed phases, you must generate ideas INDEPENDENTLY. Do NOT reference ideas from other personas. The value of this tool comes from diverse starting points that are only combined in Cross-Pollination.
