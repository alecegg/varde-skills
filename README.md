# varde-skills

A collection of `varde-*` Claude/opencode skills covering the full feature lifecycle: plan, build, review, document, and clean up.

## Install

Run the installer and point it at the skills directory for your agent runtime:

```bash
./install.sh                                  # installs all skills to ~/.claude/skills
./install.sh -d ~/.config/opencode/skills      # install to a different location
./install.sh -s varde-plan,varde-review        # install specific skills only
./install.sh -f                                # overwrite existing skills without prompting
```

Run `./install.sh -h` for full usage.

## Skills

| Skill | Purpose |
|---|---|
| `varde-plan` | Start planning a new feature or change: confirm terminology, draft spec/tasks/AC, resolve open questions. |
| `varde-build` | Execute a single plan (tasks sequential, in dependency order) or run a behavior-preserving refactor pass with TDD. |
| `varde-orchestrate` | Build a whole feature that spans multiple plans (a group plan and its children) end to end and unattended, then merge once. |
| `varde-review` | Review code changes by section and category, writing report-only findings. |
| `varde-review-fix` | Apply findings from a `/varde-review` run, verifying each change. |
| `varde-simplify` | Lightweight, diff-scoped clarity pass on recently changed code. |
| `varde-prototype` | Build a throwaway prototype to answer a visual or logic design question. |
| `varde-explain` | Create a self-contained HTML explanation of a code change or code area. |
| `varde-spec` | Regenerate domain-first specification documents from current source. |
| `varde-docs` | Refresh user-facing README.md and docs/*.md files. |
| `varde-knowledge` | Read or write knowledge notes (concepts) in the project or user knowledge folder. |
| `varde-dashboard` | Quick read-only status snapshot of in-flight plans and open handoffs. |
| `varde-handoff` | Compact the current conversation into a handoff document that carries context to a later session. |
| `varde-reflect` | Consolidate what a chunk of work produced — route friction, durable knowledge, and (at a session boundary) a handoff to the right store. Thin triage over the three leaves. |
| `varde-friction` | Capture concrete agent friction (obstacles, workarounds, missing guidance) for later improvement. |
| `varde-friction-distillation` | Distill similar open friction items into a human-approved improvement proposal. |
| `varde-worktree` | Isolate a file-producing/editing operation in its own git worktree; merge back and resolve conflicts. |
| `varde-agent-doc-authoring` | Write or review any document an agent reads (SKILL.md, AGENTS.md/CLAUDE.md, reference docs). |

Each skill's `SKILL.md` frontmatter has the full trigger/skip criteria for when it applies.
