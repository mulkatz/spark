---
description: "Cancel an active Spark ideation session"
allowed-tools:
  [
    "Bash(test -f .claude/spark-state.local.md:*)",
    "Bash(rm .claude/spark-state.local.md)",
    "Read(.claude/spark-state.local.md)",
  ]
hide-from-slash-command-tool: "true"
---

# Cancel Spark

To cancel the active ideation session:

1. Check if `.claude/spark-state.local.md` exists using Bash: `test -f .claude/spark-state.local.md && echo "EXISTS" || echo "NOT_FOUND"`

2. **If NOT_FOUND**: Say "No active Spark session to cancel."

3. **If EXISTS**:
   - Read `.claude/spark-state.local.md` to get the current phase, persona, and topic
   - Remove the file using Bash: `rm .claude/spark-state.local.md`
   - Report: "Cancelled Spark session: '[topic]' (was at phase: [phase], persona: [persona])"
