---
name: varde-agent-doc-authoring
description: >
  TRIGGER: Write or review any document an agent reads — a SKILL.md, an
  AGENTS.md/CLAUDE.md, or a reference file reached by a pointer — for quality,
  following the agentskills.io best-practices spec. Covers creating a skill,
  drafting/auditing a SKILL.md, improving a skill's description/triggering, and
  writing/editing AGENTS.md or CLAUDE.md.
  SKIP: Skip for normal code/docs work that isn't authoring or reviewing an
  agent-facing instruction document.
  Example phrases: "create a skill", "review this SKILL.md", "why isn't my skill
  triggering?", "write an AGENTS.md".
---

## Scope: one discipline, many document shapes

Everything below governs any document an agent consumes, not just `SKILL.md`. The packaging differs — YAML frontmatter and a triggering `description` for a skill, plain prose for `AGENTS.md`/`CLAUDE.md`, a bare file for a reference doc reached by a pointer — but the writing discipline is the same: ground it in real material, prune ruthlessly, put each piece of content at the right load tier, and make the agent take the same process every run. Where a rule below says "skill," read it as "the document being written" unless the rule is genuinely skill-mechanics-specific (frontmatter fields, invocation mode).

One difference matters: `AGENTS.md`/`CLAUDE.md` has no trigger check at all — it loads in full on every session, unconditionally. A skill's `description` is priced against a maybe; an `AGENTS.md` line is priced against a certainty. Prune it harder than a skill body, not more loosely.

## When to use this

- Creating a new skill from a task the user just did, or from existing docs/runbooks/code review comments.
- Reviewing/auditing an existing `SKILL.md` for bloat, vagueness, or poor triggering.
- Fixing a skill that isn't activating on the right prompts, or activates too often.
- Writing or editing `AGENTS.md`, `CLAUDE.md`, or any reference doc a skill or `AGENTS.md` line points to.

## Ground the skill in real expertise

Generate a skill from a real source, not an LLM's general knowledge — general knowledge produces vague procedures ("handle errors appropriately") instead of the specific facts that make a skill valuable. Pull from one of:

- **A real task just completed in conversation**: extract what steps worked, what corrections the user made ("use X not Y", "check edge case Z"), the actual input/output formats, and project-specific context the agent didn't already know.
- **Existing artifacts**: runbooks, style guides, API specs/schemas, code review comments, issue trackers, and version-control history (diffs/fixes reveal real patterns). Prefer these over generic reference articles — a skill synthesized from *this* project's incidents beats one synthesized from "data engineering best practices."

If you're asked to write a skill and have no real source material (no completed task, no docs to draw from), say so and ask for one before drafting — a skill with no grounding will just be a shorter version of what the model already knows.

When the source is the user's own head rather than existing docs, elicit it by interviewing them one question at a time about the ambiguities, prioritizing questions whose answer would change the skill's structure — this surfaces the project-specific corrections a generic pass would miss.

## Structure and size

- `SKILL.md` needs YAML frontmatter with required `name` (max 64 chars, lowercase+hyphens, must match the directory name) and `description` (max 1024 chars). Optional fields: `allowed-tools`, `compatibility`, `license`, `metadata`. Full field rules: [references/specification.md](references/specification.md) — read it when drafting frontmatter or when a skill fails validation. After drafting or editing frontmatter, run `uv run scripts/validate-frontmatter.py <skill-dir>` — it actually parses the YAML (catching e.g. an unquoted `: ` inside `description` producing a "nested mappings" parse error that no visual read will catch) plus every spec constraint above. It also accepts a directory of skill directories for batch-checking an installed skills root (`uv run scripts/validate-frontmatter.py ~/.pi/agent/skills`).
  - `compatibility` (max 500 chars) declares environment requirements — intended product (e.g. "Claude Code only"), required system packages, network access, Python/Node version minimums. Use it when the skill depends on a runtime that may not be present.
- Keep `SKILL.md` itself under ~500 lines / ~5,000 tokens — it loads in full whenever the skill activates, competing with everything else in context. Only `name`+`description` (~100 tokens) load for skills that haven't activated.
- Move anything larger (detailed references, long templates, exhaustive edge-case tables) into `references/`, `assets/`, or `scripts/` subdirectories, and tell the agent exactly when to load each one in `SKILL.md` — e.g. "Read `references/api-errors.md` if the API returns non-200" rather than a generic "see references/ for details." This is progressive disclosure: load on demand, not up front. Keep reference chains one level deep from `SKILL.md`. The same principle applies one level up: if a project's CLAUDE.md is accumulating several unique verification instructions, pull them into a dedicated skill and reference it from CLAUDE.md instead of inlining them there.
- If you notice the agent reinventing the same logic every run (parsing a format, validating output, building a chart), write it once as a bundled script in `scripts/` instead of prose instructions — see [references/using-scripts.md](references/using-scripts.md) for one-off command runners (uvx/npx/etc.), self-contained scripts with inline dependencies, and designing script CLIs for agentic use (no interactive prompts, `--help` output, structured stdout, meaningful exit codes).

The same split applies outside `SKILL.md`: a line in `AGENTS.md` naming a doc is the pointer, the file it names is the loaded body, and anything that file links onward to is deeper reference. When the document under review isn't a `SKILL.md`, use [references/vocabulary.md](references/vocabulary.md)'s context-pointer, information-hierarchy, and co-location entries in place of the frontmatter-specific rules below.

**Three-level loading model.** Everything in a skill loads at one of three levels:
- **Level 1 — metadata** (`name` + `description`): always in the agent's context, costs tokens on every turn regardless of whether the skill fires.
- **Level 2 — instructions** (the `SKILL.md` body): loaded once when the skill triggers; competes with everything else in the context window for that session.
- **Level 3 — scripts and references** (on-demand files): loaded only when the agent explicitly reads or runs them. Scripts are uniquely efficient here — only the output enters context, never the source code. A 200-line validator script costs ~3 lines of output per invocation; the equivalent prose would load every time at full length.

Canonical directory structure:
```
skill-name/
├── SKILL.md           # Required: metadata + instructions
├── scripts/           # Optional: executable code (Level 3, output-only)
├── references/        # Optional: documentation loaded on demand (Level 3)
├── assets/            # Optional: templates, resources (Level 3)
└── evals/             # Optional: eval test cases for quality iteration
    └── evals.json
```

## Writing the description field

The `description` is what the agent uses to decide whether to trigger the skill — only `name`+`description` load at startup for every skill, so it carries the entire triggering burden. Write it **for the model, not for humans**: it's not a summary of what the skill does, it's a signal the model matches against incoming tasks. Use imperative phrasing ("Use this skill when...", not "This skill does..."), describe user intent rather than implementation, and be pushy about listing contexts where it applies even if the user doesn't name the domain directly. Front-load the skill's leading word — the word the user actually says when they want this skill — since that's where the description does its invocation work. One trigger phrase per distinct branch; synonyms restating the same branch are duplication, not extra coverage. Keep it concise (1024-char hard limit).

One important nuance: agents typically only reach for a skill when the task needs capability beyond what they'd handle alone — a trivial one-step request ("read this PDF") may skip triggering even with a well-matched description. Write descriptions targeting complex, multi-step, or domain-specific tasks where the skill's knowledge genuinely differentiates the result.

For systematic testing — building should/should-not-trigger eval queries, computing trigger rates, train/validation splits to avoid overfitting — see [references/optimizing-descriptions.md](references/optimizing-descriptions.md); reach for it when a skill isn't triggering reliably or you want to rigorously tune wording rather than guess. To measure trigger rates for an existing skill, store its eval set at `<skill>/evals/evals.json` (array of `{query, should_trigger}`) and run `scripts/run-evals.sh <skill-name> <skill>/evals/evals.json` — it reports per-query PASS/FAIL and a pass/fail summary. The most valuable negative test cases are **near-misses**: queries that share keywords with your skill but need something different (e.g. "update formulas in my Excel budget" for a CSV-analysis skill) — obviously irrelevant queries like "write a fibonacci function" test nothing. The [`skill-creator`](https://github.com/anthropics/skills/tree/main/skills/skill-creator) skill automates this optimization loop end-to-end: splits the eval set, evaluates trigger rates in parallel, proposes description improvements using Claude, and generates a live HTML report.

## Choosing invocation mode

Every skill pays one of two costs, and the choice belongs in the frontmatter, not left to default:

- **Model-invoked** (default — keep `description`, omit `disable-model-invocation`): the agent can fire it autonomously, and other skills can invoke it too. Pays permanent **context load**: the description sits in the window on every turn regardless of whether the skill fires.
- **User-invoked** (`disable-model-invocation: true`): invisible to the agent, reachable only by a human typing the name; no other skill can reach it either. Zero context load, but shifts the cost to the human as **cognitive load** — they must remember the skill exists and when to reach for it.

Default to model-invoked only when the agent genuinely needs to reach the skill unprompted, or another skill needs to invoke it. A skill that only ever runs by explicit command (e.g. a one-off migration script wrapper) should be user-invoked so it doesn't tax every turn's context. If user-invoked skills pile up past what's memorable, add a **router skill** — one user-invoked skill that just lists the others and when to use each — rather than making everything model-invoked to compensate.

For the full vocabulary behind these tradeoffs — leading words, and the failure modes (premature completion, duplication, sediment, sprawl, no-op, negation) to diagnose a struggling skill against — see [references/vocabulary.md](references/vocabulary.md).

This skill (`agent-doc-authoring` itself) is deliberately model-invoked: the agent needs to reach for it unprompted whenever a user asks to create or review a skill, without the user having to know its name.

## Scope: one coherent unit of work

Scope a skill like a function: a coherent unit that composes with other skills.

- **Too narrow**: forces several skills to load for one task, risking overhead and conflicting instructions.
- **Too broad**: hard to trigger precisely (e.g. "database querying" + "database administration" bundled together).

## Types of skills

Before drafting, decide what kind of skill you're building — the type shapes what content belongs in it:

- **Library/API reference**: how to correctly use an internal library, CLI, or SDK — edge cases, gotchas, example invocations. Often includes a `references/` folder of code snippets.
- **Product verification**: how to test/verify that code works — playwright flows, assertion hooks, tmux CLI drivers. Among the highest-ROI skill types internally at Anthropic ("most measurable impact on output quality"); worth investing a week to make these excellent.
- **Runbooks**: symptom → investigation tools → structured report. Maps alert or error signature to the right queries and formats a finding.
- **Workflow**: a multi-step process with specific sequencing requirements — form filling, data processing pipelines, release steps. See "Workflow skill layout" below for the default structure.
- **Code review**: project-specific style/correctness patterns the model doesn't infer from the codebase alone.

The type also determines what to reach for: verification skills lean on bundled scripts and checklists; library skills lean on reference snippets and gotchas; runbooks lean on templates for structured output.

### Workflow skill layout

Default a Workflow skill's `SKILL.md` body to a procedural layout, not
narrative prose — a numbered `## Workflow` checklist that reads as a run
sheet, with everything conditional or step-internal pushed out via
progressive disclosure:

- **`## Entry point dispatch`** (when the skill has more than one invocation
  shape) — a table of `Invocation → Action`, so branch logic sits in one
  scannable place instead of being interleaved through the steps. This table
  is what an eager agent reads first and may act on before ever reaching the
  numbered steps below it — so if an action cell requires a specific
  discovery mechanism (a particular query, an operation, a reference file)
  rather than an obvious default, the cell must name that mechanism or point
  to the reference file that does, not just describe the outcome. "List
  active and backlog plans" invites the agent to `ls`/`grep`/`find` the
  plans directory instead of running the actual discovery query two
  paragraphs later; "Discover actionable plans via the query in
  `references/PLAN-FORMAT.md`" doesn't. When reviewing an existing table,
  check every action cell that names a search/list/discover/find verb for
  this gap specifically.
- **`## Workflow`** — a single numbered list, one step per line, imperative
  mood, bold lead phrase (`1. **Select the plan.** ...`). `SKILL.md` is the
  orchestrator, not the implementation — every step states what happens in
  one line and points to the `references/*.md` file that owns the actual
  procedure, e.g. "Draft the plan file. Full procedure:
  `references/DRAFT-PLAN.md`." Default to extracting a step's detail into its
  own reference file even when it would still fit under the size budget
  inline — the split is about keeping `SKILL.md` scannable as a run sheet,
  not just about hitting a token ceiling. One reference file per step is the
  common shape; merge two steps into one file only when they're short and
  always read together (e.g. two paragraph-long steps that share one
  decision).
  - Sub-steps that are a short ordered checklist (3-5 items) can stay inline
    as `a./b./c.` under their parent step in `SKILL.md`; move them into the
    step's reference file once they grow past what a step can hold as a
    scannable list, or once they contain their own branching.
  - Keep a step's condition/gate genuinely inline (not a reference pointer)
    only when it's a couple of sentences the agent needs to evaluate *while
    reading the step itself* to know whether to take it — e.g. a short
    config-gated branch ("if `plan.spar` resolves to on, run X; otherwise
    skip"). If it grows past a few sentences or gains its own sub-steps, it
    has crossed into "full procedure" territory and belongs in
    `references/`.
  - Keep step detail in `references/`, not in named `##` sections left after
    the numbered list (the older pattern of "`## Review handoff`,
    `## Completion` sections that a step points to but that stay in
    `SKILL.md`"). The one exception
    is a literal template block a step must reproduce output against
    (see Templates above); keep those inline or in `assets/`, not
    `references/`, since the agent needs the exact text, not a summary.
- **`## Gotchas`** stays inline at the end regardless of layout, per the
  gotchas rule above.

This mirrors the checklist guidance already given: numbered steps prevent
skipped dependencies, and progressive disclosure keeps the checklist itself
scannable instead of ballooning past the size budget. `skills/skill-contracts/plan/SKILL.src.md`
is a canonical worked example — 69 lines total: an
entry-point table, an 8-step `## Workflow` where every step is a one-line
description plus a `references/<STEP-NAME>.md` pointer, and a `## Gotchas`
section. (`skills/skill-contracts/build/SKILL.src.md` is an earlier,
looser pass at the same skill that still mixes in a couple of named sections
after the numbered list — treat plan's stricter all-detail-in-references
shape as the current target, not build's.)

When reviewing an existing Workflow-type skill, apply the same conversion to
narrative prose (paragraphs describing what happens "then... after that...")
— unless the skill is small enough overall (under ~80 lines with no real
branching) that the split would add no scanning value.

### Reference fan-out — the "agent gets lost" failure mode

When someone says an agent "gets lost in the size" of a skill, the cause is
almost always *navigation load*, not token count. `SKILL.md` loading at ~1.5k
tokens is fine; the trouble is how many reference files it makes the agent route
among, and how many a single step pulls at once. Diagnose and fix by file
count, not word count:

- **Count the files, not just the words.** A bundle with a lean `SKILL.md` but
  15+ small (~400-word) references is over-split. Progressive disclosure helps
  only when each reference is loaded for a distinct step; it backfires when one
  workflow step points at 4-5 peer references that cross-reference each other —
  the agent then juggles all of them to execute one phase, which is exactly
  where it loses the thread.
- **Consolidate what's always read together.** Merge references read in the same
  phase into one self-contained file, so each step maps to one file (per the
  one-file-per-step rule above). Folding a loop's 3 interlinked files into one,
  or a task/AC phase's 4 files into one, removes the cross-file hopping without
  losing any content — and lets you delete the cross-references between them.
- **Consolidate ≠ condense.** Cutting prose (fewer words per file) and reducing
  fan-out (fewer files) are different fixes. When `SKILL.md` is already lean and
  the agent still gets lost, reach for consolidation, not more word-cutting.
- **Directive-density has a floor.** A file that's almost all load-bearing rules
  and literal tokens (output formats, section names, commands) won't compress
  much — expect ~10-15%, not 30-40%. Don't chase a target percentage; past the
  floor you start deleting behavior. Added structure (headers, tight bullets)
  and consolidation beat further word-cutting there.

## Content: what to include, what to cut

Two tests decide what earns a line in the skill — full definitions and the actionable check both live in the reviewing checklist below (**no-op test**, **cache test**) rather than repeated here.

Phrase instructions as the positive target, not a prohibition (**negation** — see [references/vocabulary.md](references/vocabulary.md) and the checklist below).

Favor **procedures over declarations** — teach *how to approach* a class of problem, not the answer to one instance of it. "Read the schema, join on the `_id` convention, apply filters from the request" generalizes; "join `orders` to `customers` on `customer_id`, filter `region='EMEA'`" does not.

### Calibrate specificity to fragility

- Give the agent freedom (with the *why*, not just the *what*) when multiple approaches are valid and the task tolerates variation.
- **Explain the *why*, not just the *what*** — pair instructions with their rationale ("run validation before executing because the plan step can silently mismatch field names"). Models follow reasoned instructions more reliably than bare imperatives, and the *why* makes the instruction generalize better across varied task shapes.
- Be prescriptive — exact commands, "do not add flags" — when operations are fragile or a specific sequence is required.
- When several tools/approaches could work, name one default and mention alternatives briefly rather than presenting a menu of equal options.
- **Lean context beats exhaustive coverage**: for advanced models, over-specified context hurts more than it helps (Anthropic cut over 80% of Claude Code's system prompt for Claude 5-generation models). Fewer, well-chosen instructions outperform exhaustive rules. If pass rates plateau despite adding more rules, the skill may be over-constrained — try removing instructions and see if results hold or improve. Use `claude doctor` (Claude Code) to audit your skills and CLAUDE.md for over-specification automatically.
- Default toward judgment-based guidance, not hard rules, for current-generation models — reserve rigid rules for genuinely fragile or destructive operations. A rule like "never write multi-line comments" is often standing in for a judgment the model can now make itself (e.g. "match the surrounding code's comment density"); if you're reviewing a skill written for an older model, check whether its hard rules are still load-bearing or have become over-constraint.

### High-value patterns to reach for

- **Gotchas section**: concrete, non-obvious corrections the agent will get wrong without being told (e.g. "the `users` table uses soft deletes — queries need `WHERE deleted_at IS NULL`"). The highest-value content in most skills — every time you correct the agent, add the correction here (see checklist below for placement).
- **Templates** for required *literal output formats* — agents pattern-match against concrete structures better than prose descriptions. Inline if short; put long/conditional templates in `assets/`. Keep this distinct from illustrative usage examples ("here's how you'd use this skill"): those can constrain a capable model to the shown exploration space rather than the actual task — prefer designing expressive parameters/structure over adding more examples.
- **Checklists** for multi-step workflows with dependencies, so steps aren't skipped.
- **Verification loops**: do the work → run a validator (script, checklist, self-check) → fix → repeat until it passes. Source the check from real repeated corrections, not general knowledge — write down what you find yourself fixing by hand every time (or ask the agent for a best-practices version and edit the deltas, which is exactly where the project-specific value lives). Then match the loop to where it should run:
  - **Embedded** — a one-line append to the producing skill's own body, firing automatically as part of that workflow. Only works on skills you control (yours, or project-level skills you can edit — not built-in or plugin-managed ones).
  - **Standalone** — invoked deliberately after the artifact exists, for cross-cutting checks that don't apply to every change (a pre-commit scan, a pre-PR audit). If you find yourself invoking it after every single change, that's the signal it has earned an embed instead.
  - **Chained** — triggered as a step by another skill or workflow rather than fired by the agent's own judgment.
  - **Tied-to-PR** — runs at PR time regardless of which workflow produced the change.
- **Plan-validate-execute** for batch/destructive operations: produce a structured plan, validate it against a source of truth (a script that names exactly what's wrong, e.g. "field 'x' not found — available: a, b, c"), only then execute.

## Gotchas

- After drafting or editing, run this skill's own reviewing checklist (below) against the output you just produced, not only against the target skill — it's easy to leave a negation-phrased line or a missing Gotchas section in your own draft while flagging the same issue elsewhere.
- When authoring a file with the Write tool, do **not** end the content with a literal `</content>` (or any wrapper tag). The tool writes raw bytes, so a trailing tag lands in the file as real text — a recurring, easy-to-miss defect. End at the last real line, and `grep -n "</content>"` after writing.
- When you consolidate or rename reference files, rewire *every* inbound pointer in the same pass — `SKILL.md`, sibling references, shared/appended fragments, and templates — then grep the old names repo-wide to prove none remain. Blunt filename replaces can collapse two distinct pointers on one line into a duplicate (`X.md / X.md`); re-read touched lines.

## Refine against real execution

A first draft usually needs revision. Run the skill on real tasks and read the *execution traces*, not just final outputs — that's where you catch the agent wasting steps on vague instructions, following instructions that didn't apply to the current task, or stalling on too many undifferentiated options. Feed all results back in, not just failures: ask what triggered false positives, what got missed, what could be cut. Even one pass of execute-then-revise meaningfully improves a skill.

For a structured version of this — test cases with expected outputs, assertions graded PASS/FAIL with evidence, with-skill-vs-without-skill benchmarking — see [references/evaluating-skills.md](references/evaluating-skills.md); reach for it when a skill needs rigorous, repeatable quality iteration rather than one-off spot checks. To run such an eval set, store it at `<skill>/evals/evals.json` (`{skill_name, evals:[{id, prompt, expected_output, assertions}]}`) and run `scripts/run-output-evals.sh <skill-dir>` — it executes each case with-skill and without-skill, LLM-grades every assertion PASS/FAIL with evidence, and writes `benchmark.json` with the delta (the counterpart to `run-evals.sh`, which measures triggering not output). This applies to any skill type, not just Workflow ones — set up `evals/evals.json` once a skill has stabilized through a couple of real runs, not on a first draft. If the skill has an explicit sequence to check (a numbered `## Workflow`, a runbook's symptom→report mapping, a review skill's category list), draw assertions from those existing units first before inventing new ones — a unit that resists being turned into a checkable assertion is usually a sign the unit itself is too vague.

## Reviewing an existing skill or doc — checklist

When asked to review/audit a `SKILL.md`, `AGENTS.md`/`CLAUDE.md`, or a reference file, check each of these and report findings first — treat edits as a separate, later step the user signs off on. Items naming `description` or invocation mode are skill-specific; for `AGENTS.md`/`CLAUDE.md`, read them as "does this line's pointer earn its always-loaded, never-checked cost."

- [ ] Does `description` (or, for `AGENTS.md`, the pointer line) say concretely when to use it, in the user's words, front-loaded with the leading word that actually gets said?
- [ ] Is invocation mode deliberate — model-invoked (pays context load every turn) only where the agent must reach it unprompted or another skill invokes it, `disable-model-invocation: true` otherwise?
- [ ] Is `SKILL.md` under ~500 lines / 5k tokens? If not, what belongs in `references/`/`assets/`/`scripts/` instead, and does the skill say *when* to load each? For a non-skill doc: is content sitting at the right rung of the information hierarchy (in-file step / in-file reference / disclosed reference), and does branching justify what's kept inline?
- [ ] Is the reference **fan-out** manageable — not 15+ tiny files, and no single workflow step pointing at 4-5 peer references that cross-reference each other ("Reference fan-out" above)? If a lean `SKILL.md` still feels like the agent would get lost, the fix is consolidating files read together in one phase, not more word-cutting.
- [ ] Does a restated fact fail the **cache test** — the environment (`package.json` scripts, config files, `--help` output, directory layout) is a source of truth too, so a line that just copies a one-command lookup is a stale-prone cache; keep it only when the lookup is genuinely expensive or easy to get subtly wrong, and prefer capturing the unwritten convention or gotcha the environment doesn't confess?
- [ ] Is any content explaining things the agent already knows (generic tech background, obvious steps)? Run the **no-op test** line by line — "would the agent get this wrong without this instruction?" If the model would already do it by default, cut it; if unsure, treat that as a signal to test the skill rather than leave it in.
- [ ] Are there vague, generic instructions ("handle errors appropriately," "follow best practices") that should be replaced with the project's actual specific procedure or cut? A weak leading word repeated without payoff is a no-op — sharpen it or cut it.
- [ ] Any steering phrased as a prohibition ("don't do X")? "Don't add verbose comments" pulls verbosity into the model's attention and half-reads as permission; state the positive target instead ("write one-line comments"). Keep negation only as a hard guardrail with no positive phrasing, and even then pair it with what to do instead.
- [ ] Is the same meaning stated in more than one place (duplication) — including *across files* (the same rule in the `SKILL.md` body, a Gotcha, *and* a reference)? For current-generation models, cross-file repetition is a cost, not a safety net: it forces the model to reconcile overlapping copies. Consolidate to one authoritative location and point at it.
- [ ] Is the scope one coherent unit, not several unrelated tasks bundled together, and not a single step split needlessly across skills?
- [ ] If this is a Workflow-type skill (multi-step, ordered), does it use the numbered `## Workflow` checklist layout — entry-point table if multi-invocation, one imperative step per line, detail pushed to `references/*.md` — rather than narrative prose ("Workflow skill layout" above)?
- [ ] Does every entry-point table cell that names a search/list/discover/find action point to the specific mechanism (a query, an operation, a `references/*.md` file) rather than just describing the outcome — so an eager agent reading only the table can't reach for an ad hoc `ls`/`grep`/`find` instead?
- [ ] Do all `references/*.md` pointers resolve *within this skill*? A relative pointer to a file that lives in another skill (e.g. `references/PLAN-RUN.md` referenced from a skill that has no such file) is a dangling link — name the owning skill instead. After consolidating/renaming files, grep for the old names repo-wide to catch stragglers.
- [ ] Where multiple tools/approaches are viable, is there a clear default rather than a menu?
- [ ] Is there a gotchas section capturing known corrections, and is it inline rather than in a reference file?
- [ ] For structured/repeatable output, is there a template or validator rather than prose-only instructions?
- [ ] If the skill encodes a verification loop, is it matched to the right invocation shape (embedded/standalone/chained/tied-to-PR) rather than defaulting to standalone out of habit?
- [ ] Do any hard rules exist that are really standing in for judgment the current model can be trusted with — over-constraint left over from an older model generation?
- [ ] Does `allowed-tools` match what the body actually uses?
- [ ] Does frontmatter pass `uv run scripts/validate-frontmatter.py <skill-dir>` — valid YAML (no unquoted `: ` in a plain scalar), `name` matches the directory, lowercase+hyphens only, no leading/trailing/double hyphens, `description` under 1024 chars ([references/specification.md](references/specification.md) for the full field rules)?
- [ ] No stray wrapper/closing tag at end of file — e.g. a literal `</content>` line accidentally written into the markdown when authoring with the Write tool. `grep -n "</content>"` the files you just wrote; the Write tool takes raw bytes, so any wrapper tag becomes real file text.
- [ ] If the skill bundles scripts, do they avoid interactive prompts, document `--help`, use structured stdout + stderr for diagnostics, and give meaningful exit codes ([references/using-scripts.md](references/using-scripts.md))?
- [ ] Is there an `evals/` directory with structured test cases for repeatable quality iteration ([references/evaluating-skills.md](references/evaluating-skills.md))? For skills that need rigorous quality work, a few `evals/evals.json` cases + with/without-skill comparison is worth the investment.
- [ ] Is the skill lean for current-generation models — or does it have exhaustive rules that plateau performance rather than improve it? Could instructions be removed with quality holding?
