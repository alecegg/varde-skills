# Sequential Task Execution

Load this before running a plan's tasks. It covers how ready tasks are derived,
how each task runs in its own subagent inside the single build worktree, the
commit-per-task rule, bounded retry, blocker handling, and the resume gate.
There is no batching, no parallel dispatch, and no cross-task integration stage:
tasks run one at a time, in dependency order, committing into the shared build
worktree.

## The build worktree

`SKILL.md` step 3 creates one isolated worktree for the whole plan run
(`worktree/build-<plan-id>` via the `varde-worktree` skill) and records its
branch and path in the run-state file
(`memory-bank/working/plans/<plan-id>/run-state.md`) the moment it is created —
the crash-recovery anchor: an interrupted run reattaches this worktree instead
of creating a second one (see Resume gate). Every task's work is committed onto
this worktree's branch, never onto the original branch directly. The original
branch (real `HEAD`) is touched exactly once, by the single merge in
`SKILL.md` step 8's Merge/Stop choice (`PLAN-RUN.md` Section F).

## Deriving the next ready task

Readiness is always computed live from `depends_on`, never read from a stored
`ready` field. A task (`status: backlog`) is ready only when every task in its
`depends_on` list has `status: done`. After each task completes, re-derive the
next ready task. Walk ready tasks in dependency order (stable topological sort
by task id; treat a dependency cycle as a hard failure). Continue until every
remaining task is `done` or `blocked`.

## Dispatching one task

Dispatch every task to a single subagent — the subagent is the context-isolation
boundary; it works directly in the build worktree (the effective `repoRoot`) and
commits there. Give the subagent only its task briefing, its `#### Verification`
checks, change scope (`modifies`/`creates`), and a bounded context (acceptance
criteria are plan-level, verified once at the end — not a per-task input). The
subagent loads
`EXECUTION.md` in full before its first tool call, then runs
`execute -> /varde-simplify -> verify` scoped to that task's own uncommitted
changes. The orchestrator never edits source files itself; it dispatches, waits,
records the outcome in the run-state file, and derives the next task.

`/varde-simplify` is diff-scoped and edits inline — the lightweight, task-local
counterpart to the full `/varde-review` + `/varde-review-fix` pass, which runs
once at the plan level (`PLAN-RUN.md` Section F), not per task. The per-task
simplify writes nothing under the shared plan directory
(`memory-bank/working/plans/<plan-id>/`) beyond the task's own file.

## Commit-per-task

When a task's `#### Verification` checks pass, the task subagent commits its
source changes together with its own `tasks/<task-id>.md`
in one commit on the build worktree branch
(`git add <source-paths> memory-bank/working/plans/<plan-id>/tasks/<task-id>.md
&& git commit -m "task: <task-id> done"`). Per-task commits — not per-task
branches — provide the run's granularity: history shows one commit per task, and
a failed run can be resumed or reset at a commit boundary. The task file must
never sit uncommitted after the task is done. The task subagent never commits
`plan.md` (orchestrator-owned).

## Bounded retry and blocker handling

Per-task retries are bounded by `MAX_TASK_RETRIES = 2` targeted retries. If the
Verify step keeps failing after `/varde-simplify`'s own per-file revert, spawn a
fresh targeted retry subagent with the specific failure, current diff, the
task's `#### Verification` checks, and prior progress — do not blindly rerun the
same pass.
Count each attempt and log it in the run-state file. After the retry limit is
exhausted:

- Mark the task `blocked` (edit that task's own `status:` field directly — never
  `plan.md`), append the reason to its `#### Progress` section, and log it.
- **Halt the run fail-closed.** In a sequential unattended run there is no
  parallel work to continue; leave the build worktree as-is (partial, uncommitted
  changes for the failed task included) for the human, and report where and why
  the run stopped. Do not merge to the original branch.

A task-specific blocker (this task's `#### Verification` can't pass) is owned by
the task worker. A plan-wide blocker (the whole plan's assumptions no longer
hold, e.g.
found during the Plan Staleness Check before dispatch) is owned by the
orchestrator: edit `plan.md` frontmatter `status:` to `blocked` and stop.

## Resume gate

Before resuming an interrupted plan run, first recover the build worktree: read
the branch and path from the run-state file. If the branch still exists
(`git show-ref --verify --quiet refs/heads/<name>`), reattach that worktree —
never create a second one, so committed task work isn't orphaned. If the
run-state file has no worktree line (interrupted before `SKILL.md` step 3
finished), treat this as a fresh start of step 3. If the branch is missing
despite a recorded name, stop and surface it — do not silently recreate under
the same name.

Then, since progress lives in each task's frontmatter, derive state directly:
every `done` task is complete (its commit is on the worktree branch); the next
ready task is the first `backlog` task whose `depends_on` are all `done`. If a
task is `done` but has no matching commit on the branch, or has commits but no
completion entry in its `#### Progress` section, stop and surface it rather than
inferring the outcome — a human decides whether to retry, confirm done, or mark
it blocked.
