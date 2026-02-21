---
description: "Show current Spark ideation session status"
allowed-tools:
  [
    "Bash(test -f .claude/spark-state.local.md:*)",
    "Read(.claude/spark-state.local.md)",
  ]
hide-from-slash-command-tool: "true"
---

# Spark Status

Check the current ideation session status:

1. Check if `.claude/spark-state.local.md` exists using Bash: `test -f .claude/spark-state.local.md && echo "EXISTS" || echo "NOT_FOUND"`

2. **If NOT_FOUND**: Say "No active Spark session."

3. **If EXISTS**:
   - Read `.claude/spark-state.local.md`
   - Report the following from the YAML frontmatter:
     - **Topic**: the `question` field
     - **Phase**: the `phase` field (seed/cross/synthesize)
     - **Persona**: current persona based on `persona_index` and `personas` fields
     - **Round**: `round` of `max_rounds`
     - **Interactive**: the `interactive` field (true/false)
     - **Started**: the `started_at` field
