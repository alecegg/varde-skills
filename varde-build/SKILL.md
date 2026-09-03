---
name: varde-build
description: >
  TRIGGER: Execute a single plan, run an ad-hoc change described directly, or
  run a behavior-preserving refactor pass. Decompose the spec+acceptance-criteria
  into tasks, select a posture, implement the tasks one at a time with TDD, and
  verify the plan-level acceptance criteria. For running a whole feature spanning
  multiple plans, use /varde-orchestrate instead.
  SKIP: Skip only when the user needs planning of a large/uncertain feature,
  review, refinement, or a prototype, or wants to run a multi-plan feature end to
  end (that is /varde-orchestrate).
  Example phrases: "run this plan", "just do this change", or "refactor this
  codebase".
---

## Entry point dispatch

| Invocation | Action |
|---|---|
| *(no argument)* | Discover actionable plans per `references/PLAN-RUN.md`, present them, then run the selected plan. |
| *(ad-hoc description, e.g. "add a --json flag to the export command")* | No plan exists: synthesize a minimal `plan.md` (Problem/Solution + plan-level acceptance criteria), confirm it once, then decompose and run it like `plan=<id>`. See step 2. |
| `plan=<id>` | Decompose the plan's spec+AC into tasks, then run all tasks in dependency order, sequentially, unattended. |
| `mode=verify plan=<id>` | Skip steps 5–8 and run only the Verify sub-step (`references/EXECUTION.md`) for tasks whose `verified` field is not `passed`. |
| `plan=<id> finish=defer` | Run the plan through step 6, then skip review and completion (steps 7–8) — the defer branch stops before Section F's review (`references/PLAN-RUN.md`). |
| `posture=refactor [target=<target>]` | Resolve the target and run a refactor pass. |

When invoked by `/varde-orchestrate` with an already-isolated worktree, skip
step 3's isolation (the orchestrator owns the feature worktree).

## Workflow

This skill runs **one plan**, executing its tasks **sequentially in dependency
order** inside a single worktree. There is no task batching and no parallel
dispatch — one task at a time keeps context clean and usage predictable. Wall
clock is not optimized; large work is split into small plans at plan time and
run in order (by the user, or by `/varde-orchestrate`).

1. **Load the references.** Load `references/PLAN-RUN.md` (how plans and tasks
   are discovered and run — plain markdown files, no special lookup tool) and
   `references/INTERVIEW.md` (interview protocol: harness detection, prompting
   format, recommendation requirement). Check once per session whether the
   `varde-code` CLI (optional, on PATH) is available: run
   `command -v varde-code >/dev/null 2>&1`. If present, load `references/VARDE-CODE-CLI.md`
   for optional operations that can replace some Read/Grep steps here and in
   `references/EXECUTION.md`; otherwise ignore it and use plain Read/Grep.

2. **Select or synthesize the plan.** If the user provided a `plan=<id>`, build
   it. If the user gave a free-text change description with no plan (**ad-hoc
   entry**), synthesize one now: derive a plan-id, create a fresh plan directory,
   and write a minimal `plan.md` — a best-guess Problem/Solution plus a short set
   of plan-level acceptance criteria in Given/When/Then form — then confirm it
   with the user in one turn ("here's what I'll build and what 'done' means — go,
   or adjust?"). This is a lightweight pass, not the full `/varde-plan` growth
   loop or AC-scoring machinery; for a large or uncertain change, recommend
   `/varde-plan` instead. Otherwise (no argument) discover actionable plans per
   `references/PLAN-RUN.md` (read the plan directories and `plan.md` frontmatter —
   do not `ls`/`grep`/`find` blindly) and present them for the user to choose;
   `references/PLAN-RUN.md` covers the `depends_on`-gating rule. `<plan-id>` must
   be resolved before step 3, which needs it to name the worktree.

3. **Create the plan's worktree.** The whole plan run — orchestrator writes
   (`plan.md`, task status/verified fields, the run-state file) and every
   task's committed work — lands in one isolated worktree, never directly on the
   original branch (base-branch invariant, full statement in
   `references/PLAN-RUN.md`'s Git scope). Invoke the `varde-worktree` skill:
   `create id=build-<plan-id>`, and run every step below with the printed
   `path=`/`branch=` as the effective `repoRoot`/branch. Immediately record the
   worktree branch and path in the run-state file
   (`memory-bank/working/plans/<plan-id>/run-state.md`, creating it if absent) —
   this is the crash-recovery anchor a resumed run reads first
   (`references/PLAN-RUN.md`'s Resume gate). Always isolate; skip this step only
   when already running inside a caller's own worktree (e.g. `/varde-orchestrate`).

4. **Load the plan, decompose it, and state a posture** before starting
   implementation. See `references/PLAN-FORMAT.md` for plan/task file layout.
   **Decompose the spec+AC into tasks:** load `references/DECOMPOSITION.md` and
   break the plan's spec and plan-level acceptance criteria into
   `tasks/<task-id>.md` files (fit gate, sizing, edge-case slicing, and the
   doc-task decision live there). Acceptance criteria stay plan-level and are
   never re-authored per task; each task carries its own `#### Verification`
   block. Present the breakdown once and proceed when interactive; run straight
   through under `/varde-orchestrate` or an unattended `plan=<id>`
   (`DECOMPOSITION.md`'s present-and-record rule). Skip decomposition only when
   the plan already carries authored task files (a resumed run).

5. **Execute tasks one at a time, in dependency order, until none remain.**
   Derive the next dependency-ready task (`status: backlog` with every
   `depends_on` entry `done` — always computed live, never a stored `ready`
   field), dispatch it to a single isolated subagent, wait for it to report,
   then re-derive the next ready task. Repeat until every remaining task is
   `done` or `blocked`. Record each dispatch, retry, blocker, and completion as
   one line in the run-state file step 3 created — task workers never write to
   it. Full loop, resume gate, and bounded-retry rules: `references/PLAN-RUN.md`
   and `references/EXECUTION.md`.

6. **Each task's subagent executes the task**, not the main orchestrator. The
   subagent loads `references/EXECUTION.md` in full before its first tool call —
   it defines the TDD cycle, the Given/Unknowns/Plan/Verification frame, and
   blocker handling. After implementation, the subagent runs `/varde-simplify`
   scoped to the task's uncommitted changes, then, before marking the task done:
   a. Run the task's Verify sub-step (`references/EXECUTION.md`) — its own
      `#### Verification` `assert:`/`retrieve:` checks — with bounded retry (up to
      `MAX_TASK_RETRIES = 2`); on exhaustion, mark the task `blocked` and stop
      (fail-closed) per `references/EXECUTION.md`.
   b. Mark the task `status = "done"` once its `#### Verification` checks pass.
      Task files carry no acceptance criteria — the plan-level `## Acceptance
      criteria` are verified once at step 8, not per task.
   c. Verify affected packages with `npx tsc --noEmit` and `npm test`.
   d. Run any project-configured static analysis or lint after source edits;
      treat findings as warnings, per `references/EXECUTION.md`.
   e. Commit the task's source changes together with its task file, in the
      worktree (`references/EXECUTION.md`'s commit rule).
   The orchestrator waits for the subagent to report, then derives the next
   ready task (step 5). There is no integration stage — each task commits into
   the shared worktree in order.

7. **Write knowledge gotchas, if any.** Create or edit a markdown note in the
   repo's existing knowledge location (e.g. `memory-bank/knowledge/`) directly.
   Record path-level gotchas only when specific and useful, capped at four
   bullets. If it needs more, propose an architecture-level update instead.

8. **Hand off to review, verify plan-level AC, then complete.** Run one
   report-only review pass; if it produced findings, run one fix round then defer
   anything still open (no re-review loop). Then walk each `## Acceptance
   criteria` item in `plan.md`, verify it holds against the aggregate change, and
   toggle `- [ ]` to `- [x]` — an unconfirmable criterion is a blocker, not a
   silent pass (`references/PLAN-RUN.md` Section F). Complete the plan
   automatically once every task is `done`, every plan-level criterion is
   confirmed, review findings are resolved, and no companion action-item plan is
   pending — and offer Merge/Stop: the single merge of the worktree branch
   (step 3) into the original branch, or Stop to leave it staged. Unless step 3
   skipped isolation because this run was already inside a caller's worktree,
   this is where that isolation resolves. Full procedure: `references/PLAN-RUN.md`
   (Section F).

9. **Reflect and consolidate.** Invoke `varde-reflect`, if available in this repo.
   If this run was **top-level** (not nested inside `varde-orchestrate` — the same
   detection as step 3's isolation and step 8's Merge/Stop), invoke
   `varde-reflect boundary`: the completed plan is a session boundary, so it
   harvests friction and durable knowledge and writes a carry-forward handoff. If
   this run was **nested**, invoke `varde-reflect source=varde-build` (friction +
   knowledge only — `varde-orchestrate` writes the boundary handoff when the whole
   feature completes). If `varde-reflect` isn't installed, fall back to
   `varde-friction` scoped to this skill's own execution.

## Gotchas

- Tasks are `tasks/<task-id>.md` files in the plan directory, authored by this skill during decomposition (`references/DECOMPOSITION.md`, template `assets/TASK-TEMPLATE.md`). Frontmatter `{type: task, parent: <plan-id>, status, verified: pending | passed | failed, depends_on, modifies: [], creates: []}`, plus optional `kind: research`; body `#### Out of scope`/`#### Verification`/`#### Progress`. Tasks carry **no** `#### Acceptance criteria` — acceptance criteria are plan-level (`plan.md`'s `## Acceptance criteria`); a task's own gate is its `#### Verification`. Missing `verified` fields are treated as `pending`. `change_files` is a legacy read-only alias some older plans may still carry — treat it as data only, never write it, and derive freshness from `modifies`/`creates`.
- Read a plan by reading its `plan.md` directly (spec + `## Acceptance criteria`, no `## Tasks` section); enumerate a plan's tasks by globbing its `tasks/*.md` files, not by reading a `## Tasks` index. There is no generated `index.md`.
- Update task status/verification by editing the `status:`/`verified:` field of `tasks/<task-id>.md` directly. Only the task worker owns that file, including its own `blocked` status.
- A task-specific blocker marks that task `blocked` (owned by the task worker, in its own file). A plan-wide blocker marks `plan.md` `blocked` (owned by the orchestrator only). Task workers never edit `plan.md`.
- Always use a subagent for task implementation; use a read-only subagent first for unfamiliar code or isolated analysis.
- Base-branch invariant (full statement: `references/PLAN-RUN.md`'s Git scope): the original branch (real `HEAD`) is touched exactly once per plan run, at step 8's Merge/Stop choice.
