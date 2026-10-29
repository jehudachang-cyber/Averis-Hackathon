# AGENTS.md

This file is the **contract** for every human and every coding agent working in
this repository. Read it before writing any code. If you are a coding agent,
treat this as the authority the moment you start.

Last updated 2026-09-18.

## 0. Non-negotiables (read these first)

1. **The answer key is evaluation-only.** `sdoc-hackathon-docker/data_v2/ground_truth.json`
   is for checking results via `score_cli.py`. Never use it to *generate*
   predictions, never hardcode email ids or labels, and never tune a pattern
   against an email id. Patterns must generalize from the documents and
   `USE_CASE.md`.
2. **Touch only the files your issue lists.** Every issue has a `Files`
   section. Work on nothing else. If a change needs a file that is not listed,
   stop and ask in the issue before proceeding.
3. **One issue → one branch → one pull request.** Never push directly to
   `main`. Never commit work from two issues in one branch. Name branches
   `feature/<issue-number>-<short-slug>`.
4. **Pass the issue's tests and the local gate before opening a PR.** The
   Acceptance section of the issue is part of the issue. Run it inside a CI-
   free project; quality is your own responsibility (no GitHub Actions).
5. **Never commit secrets or generated artifacts.** This includes `.env`,
   API keys, `submission.json`, and `node_modules/`. `ground_truth.json` is
   tracked and shared with the team — you may read it for evaluation, never
   to fabricate answers.
6. **No new dependencies** unless the issue explicitly adds one (declared via
   `uv add <package>` in `pyproject.toml`, never ad-hoc `pip install`).
7. **When unsure, ask.** Put the question in the issue thread rather than
   guessing. Never invent requirements, email ids, or behavior not stated.

## 1. What this project is

A shipping-document verification pipeline for the SDOC hackathon. It reads a
shipping-operations inbox, classifies every email into one of five categories,
and for document-checking requests compares the **Shipping Instruction (SI)**
against the **draft Bill of Lading (BL)** over seven fields, reporting
discrepancies or escalating undecidable cases to a human.

- Working dataset: `sdoc-hackathon-bundle/` (520 inbox emails, 250 SI/BL
  attachments; no labels).
- Evaluation/demo kit: `sdoc-hackathon-docker/` (scoring via `server/score_cli.py`
  + `server/scoring.py`, the FastAPI demo server, and the generator sources in
  `data_v2/*.py` as a read-only spec).
- Requirements and planned dashboards: `USE_CASE.md` and `plans/`.

### Current focus (2026-09-20)

Backend is **complete**: classification → parsers → extract → compare →
review → submission scores FINAL 1.0000 on the working bundle.
**Milestone 6 — the React demo dashboard — is done** (issues #47–#50 merged:
trace provenance, `api/` bridge, Overview/Pipeline/Browse pages).
**Issues #51 (auto-resolve, PR #59) and #52 (Cloud Run hosting, PR #60) are
merged** (2026-09-21): sandboxed Gmail send + resolve log, and the `deploy/`
Cloud Run kit. The first real cloud deploy has not happened yet. Active work:

1. First `./deploy/deploy.sh` → public URL, then verify the sandbox send on
   the cloud deploy.
2. `api/` + `ui/` follow-ups as needed (keep the proven pipeline untouched).

The pipeline backend is **frozen**: no behavior changes to `classify.py`,
`parsers/`, `extract.py`, `compare.py`, `review.py`, or `pipeline.py` verdicts.
The **single agreed exception** was the additive trace-provenance work in
issue #47 (dashboard decision #15): optional `StepEvent.payload`,
`extract_fields_anchored()`, and `extract`/`compare` StepEvents — merged and
verified verdict-byte-identical (FINAL 1.0000). Anything else that needs a
backend edit → ask in the issue first.

## 2. Team and ownership map

Work is split into non-overlapping file silos. Shared types live in
`src/sdoc_hackathon/models.py`; silos communicate **only** through those types.

| Silo | Owner | Files you may touch |
| --- | --- | --- |
| Contracts/models | Team lead | `src/sdoc_hackathon/models.py`, `src/sdoc_hackathon/trace.py` |
| Classification | Anyone (self-serve) | `src/sdoc_hackathon/classify.py` |
| Parsers | Anyone (self-serve) | `src/sdoc_hackathon/parsers/` |
| Extract/compare/review | Anyone (self-serve) | `src/sdoc_hackathon/extract.py`, `compare.py`, `review.py` |
| Orchestration | Team lead | `src/sdoc_hackathon/pipeline.py`, `submission.py`, `scripts/` |
| Gemini OCR | Team lead | `src/sdoc_hackathon/llm.py` |
| Engine API | Team lead | `api/` |
| React UI | One dedicated person | `ui/` |

Do not edit another silo's files. If two issues need the same file, one of them
must depend on the other (see each issue's *Depends on*).

## 3. How work is tracked

- **Source of truth:** GitHub Issues. Pick an open issue, or ask in the team
  chat which to take. Each issue has a `Goal / Files / Acceptance / Depends on`
  body.
- **Labels:** `milestone:0`–`milestone:6`, `good-first-issue`, `integration`,
  `blocked`.
- **Branch + PR:** feature branch → open PR with `Closes #<issue>` → merge to
  `main`. A PR is eligible for review only after its Acceptance runs pass.
- **Status mirrors (updated rarely, not per-PR):**
  - `plans/2026-09-18-sdoc-hackathon-pipeline.md` — milestone tracking.
  - `USE_CASE.md` — requirement checkboxes, ticked when the capability merges.
  - `README.md` — status table.

## 4. Per-issue workflow (definition of done)

For every issue, in order:

1. Read this file, the issue body, `USE_CASE.md`, and `src/sdoc_hackathon/models.py`.
2. Create the branch: `feature/<issue-number>-<slug>`.
3. Implement the smallest change that satisfies the issue's `Goal`.
4. Add/extend tests in `tests/unit/` covering the new behavior (including edge
   cases your change introduces).
5. Run the issue's `Acceptance` commands, plus at minimum `uv run pytest -q`,
   `uv run ruff check .`, and `uv run pyright`.
6. Open the PR with `Closes #<issue>`, listing the commands you ran and their
   results in the description.
7. Ask for review (light-touch: review is on request, but your own merge is
   fine once Acceptance passes unless the issue says the team lead checks it).

An issue is **done** only when its Acceptance passes and its tests are merged.
No work is "done" on a branch.

## 5. Coding standards

- Production code lives under `src/sdoc_hackathon/`; absolute imports
  (`from sdoc_hackathon.x import y`) in the package and tests.
- Four spaces, UTF-8, LF endings, final newline.
- Type annotations on all new/changed functions.
- Python 3.11–3.14 compatible, not just the `.python-version` (3.14) version.
- Google-style docstrings; examples must be valid doctests (the test recipes
  collect doctests from `*.py`).
- Let Ruff format the code; do not hand-format against it.
- UI (`ui/`): Vite + React + TypeScript + Tailwind. Node 20+. Never commit
  `node_modules/` or `ui/dist/`. UI code is its own silo (see §2).

## 6. Environment and commands

Setup (once):

```bash
uv sync --all-groups        # Python env (uv manages Python 3.14)
# UI only:  cd ui && npm install
```

Verify / iterate:

```bash
uv run pytest -q                              # tests
uv run ruff check .                           # lint
uv run ruff format --check .                  # formatting
uv run pyright                                # type checking
uv run --group docs mkdocs build --strict     # docs
```

Evaluate a submission against the answer key:

```bash
uv run python scripts/run_pipeline.py --data sdoc-hackathon-bundle --out submission.json
uv run python sdoc-hackathon-docker/server/score_cli.py submission.json
```

Demo (engine API + React UI + scoring server) — see `README.md`.

If `just` is installed, the recipes in `justfile` wrap the same commands. Do
not invoke tools from an unrelated global Python environment.

## 7. Agent ground rules

Rules aimed at AI coding agents (opencode and similar) assisting any teammate.

- Before touching code: read this file, the issue body, `models.py`, and the
  relevant `tests/unit/` files.
- Make the smallest coherent change that satisfies the issue. Do not refactor
  unrelated code, rename symbols not in scope, or "improve" neighboring files.
- Use the repository's tools (`uv run pytest|ruff|pyright`, `npm` in `ui/`).
  Never install into a global Python. Never import a library that is not
  declared in `pyproject.toml`.
- Write a test for every behavior you add or change, in the existing pattern
  (parametrize where sensible), and place it in `tests/unit/`.
- Prepare evidence: report the exact commands you ran and their output in the
  PR description. Do not claim a check passed unless you ran it.
- Do not commit, push, or merge unless the task explicitly authorizes it.
- When a requirement is ambiguous, list the ambiguity in the issue and propose
  the set of options; do not pick silently.
- Never inspect `ground_truth.json` to derive a rule, pattern, or value that
  the pipeline will then produce or match against. Enforced mechanically:
  `api/tests/test_bridge.py::test_no_ground_truth_import_anywhere_in_api`
  statically blocks any `api/` module from referencing the key or its
  location.

## 8. Onboarding (first 30 minutes)

1. Clone and `uv sync --all-groups`.
2. Read `USE_CASE.md`, `README.md`, and the top of this file's §0–§2.
3. Read `src/sdoc_hackathon/models.py` (the shared contracts).
4. Look at the inbox: `cat sdoc-hackathon-bundle/inbox/email_004.json` and its
   two attachments.
5. Open a couple of open issues labelled `good-first-issue` and take one.

## Ground truth and integrity (restated)

`data_v2/ground_truth.json` is the answer key, tracked and shared for
self-evaluation. It must never be used to generate predictions. Hardcoding
email ids or labels is disallowed. Patterns must generalize from the documents
and the use-case brief (`USE_CASE.md`).