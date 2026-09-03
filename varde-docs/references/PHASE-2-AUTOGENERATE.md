## Phase 2: Auto-generate spec-declared sections

For each doc identified in Phase 1 as having stale marker-declared sections,
spawn one agent to regenerate them. Start all agents together.

Each agent receives only:

- the document's current content;
- its docs marker (format: `references/MARKER-FORMAT.md`);
- the list of stale sources/sections to regenerate for that doc.

The agent rewrites only marker-declared blocks whose source and section are
listed. When `varde-code` was detected in the skill's setup step, it's passed
into the agent's prompt along with the stale section's source files — the
agent reads that content primarily via `symbols_in_file`/`get_symbol`
(`includeBody: true`), falling back to Read/Grep/Glob only for what the
CLI can't supply. Without `varde-code`, it reads the source files directly
(Read/Grep/Glob, or delegating to subagents to read subsystems). Either
way it authors the replacement markdown by hand, preserves other marker
blocks and all hand-authored content, then writes the complete resulting
document back to disk.

Map source content to Markdown as follows:

- Flow sections become prose steps followed by a Mermaid `flowchart` block.
- Architecture Layer Model and Dependency Constraints become one combined Mermaid
  `graph` block. Emit exactly one combined graph, not two separate diagrams.
- Key Operations, Invariants, and Acceptance Criteria remain prose only.

Use Mermaid fenced blocks that render on GitHub's native Markdown renderer.
