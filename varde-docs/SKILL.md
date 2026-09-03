---
name: varde-docs
description: >
  TRIGGER: Refresh user-facing README.md and docs/*.md files. Scan all docs,
  regenerate spec-declared sections, and propose edits for hand-authored sections.
  SKIP: Skip only when the request concerns code, plans, or generated specs alone.
  Example phrases: "refresh the README" or "check docs for drift".
---

## Purpose

Keep all user-facing documentation aligned with the current state of the codebase
(and any generated specifications, if the project has them).

The varde-docs skill has two output tracks:

- **Auto-generate**: sections explicitly declared inside a freshness marker are
  rewritten by reading the source they describe and authoring the replacement text
  directly.
- **Propose**: all other content — hand-authored sections in marked docs, and the
  entirety of unmarked docs — is compared against the current code/specs and
  surfaced as a proposed diff for user review. Changes are applied only on approval.

## Inputs

- `repoRoot`: absolute repository path.
- `docPath`: README.md or a direct docs/*.md path being regenerated.

## Workflow

1. **Isolate the run.** This skill scans and rewrites many documents over a
   multi-phase run — a concurrent edit landing mid-run (by another agent or
   the user) could get silently overwritten by a phase that read the stale
   version. Invoke the `varde-worktree` skill: `create id=docs-<short-id>`, run
   every step below with the printed `path=` as the effective `repoRoot`.
   Skip this step only when already running inside a caller's own isolated
   worktree.
2. **Check for the `varde-code` CLI.** Check once per session whether the
   `varde-code` CLI (an optional tool, installed on PATH) is available: run
   `command -v varde-code >/dev/null 2>&1`. If present, load
   `references/VARDE-CODE-CLI.md`: it's the
   primary way to scope Phase 1's diff and to read source content in
   Phases 0 and 2, instead of Read/Grep. If it isn't, ignore that file and
   use the plain Read/Grep workflow in every phase below. Likewise, if
   `command -v varde-docs >/dev/null 2>&1` succeeds, load `references/VARDE-DOCS-CLI.md`; when present,
   use it to read generated specs and for ranked `search`/whole-doc `show` and
   OCC-safe whole-file writes over README/`docs/*.md` — section-marker
   rewrites stay Edit. Absent, use plain Read/Grep/Write/Edit.
3. **Refresh specifications first, if any exist.** Check whether the repo has
   generated specification documents (e.g. under `memory-bank/knowledge/specs/`
   or similar). If so, update any that are stale before touching docs. Full
   procedure: `references/PHASE-0-SPEC-REFRESH.md`.
4. **Discover all documents.** Enumerate README.md and docs/*.md, classify
   each as marked or unmarked. For marked docs, use `detect_changes` against
   each marker's `source_hash` to find which declared sections actually
   changed, instead of reading every doc/source pair. Full procedure:
   `references/PHASE-1-DISCOVERY.md`.
5. **Auto-generate spec-declared sections.** Spawn one agent per doc with
   stale marker-declared blocks to rewrite only those blocks, reading the
   current source primarily via CLI symbol queries when available. Full
   procedure: `references/PHASE-2-AUTOGENERATE.md`.
6. **Propose edits for all docs.** Spawn one agent per document to compare
   hand-authored content against the code/specs and surface changes for approval.
   Full procedure: `references/PHASE-3-PROPOSE.md`.
7. **Verify generated documents.** Re-read each edited document next to the
   source it describes and check for accuracy and drift; report findings without
   auto-repairing them. Full procedure: `references/PHASE-4-VERIFY.md`.
8. **Merge the isolated run back.** Unless step 1 skipped isolating because
   this run was already inside a caller's worktree, invoke `merge
   id=docs-<short-id>` then `cleanup id=docs-<short-id>` from the `varde-worktree`
   skill. On a merge conflict, follow that skill's `references/RESOLVE.md`
   with intent "regenerate docs from current source/specs" before cleaning
   up.
9. **Reflect and consolidate.** Invoke `varde-reflect source=varde-docs` — it
   captures friction scoped to this skill's own execution and harvests any durable
   knowledge the work produced (no handoff mid-session). If `varde-reflect` isn't
   installed, fall back to `varde-friction` with the same scope.

## Constraints

- Write only prose grounded in the source it describes — do not invent details.
- Do not create CHANGELOG, release-note, or external doc-site output.
- Use Mermaid only for diagrams.

## Gotchas

- The freshness marker format (`references/MARKER-FORMAT.md`) is the single
  source of truth for the source-to-document mapping — both Phase 2 (rewriting
  marker-declared blocks) and Phase 3 (proposing a marker for unmarked docs)
  depend on it, so a malformed marker breaks both tracks silently.
- Phase 2 only rewrites marker-declared blocks; it never touches
  hand-authored content, even in a marked doc — that content only ever moves
  through Phase 3's propose-and-approve path.
- Phase 4 verification only reports malformed markers, missing source
  references, and unbalanced Mermaid fences — it does not repair them; fixes
  go back through Phase 2/3, not through an automated Phase 4 fix.
